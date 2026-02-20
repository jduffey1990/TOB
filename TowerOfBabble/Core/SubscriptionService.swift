//
//  SubscriptionService.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 2/19/26.
//
//  Handles all StoreKit 2 subscription logic:
//    - Loading products from App Store Connect
//    - Initiating purchases
//    - Verifying completed transactions with our backend
//    - Listening for transaction updates (renewals, revocations)
//

import Foundation
import StoreKit
import Combine

// MARK: - Product IDs

enum TOBProductID: String, CaseIterable {
    case proMonthly    = "foxdogdevelopment.TowerOfBabble.pro.monthly"
    case proAnnual     = "foxdogdevelopment.TowerOfBabble.pro.annual"
    case warriorMonthly = "foxdogdevelopment.TowerOfBabble.warrior.monthly"
    case warriorAnnual  = "foxdogdevelopment.TowerOfBabble.warrior.annual"

    var tier: String {
        switch self {
        case .proMonthly, .proAnnual:         return "pro"
        case .warriorMonthly, .warriorAnnual: return "prayer_warrior"
        }
    }
}

// MARK: - Purchase Result

enum PurchaseResult {
    case success(tier: String)
    case cancelled
    case failed(Error)
}

// MARK: - SubscriptionService

@MainActor
class SubscriptionService: ObservableObject {

    // MARK: - Singleton

    static let shared = SubscriptionService()

    // MARK: - Published State

    @Published var availableProducts: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String?

    // MARK: - Private

    private var transactionListenerTask: Task<Void, Error>?
    private let apiClient = APIClient.shared

    // MARK: - Init

    private init() {
        // Start listening for transaction updates immediately.
        // This catches renewals and revocations that happen while the app is running.
        transactionListenerTask = listenForTransactions()

        Task {
            await loadProducts()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let productIDs = TOBProductID.allCases.map { $0.rawValue }
            let products = try await Product.products(for: productIDs)

            // Sort: Warrior Annual, Warrior Monthly, Pro Annual, Pro Monthly
            availableProducts = products.sorted { a, b in
                let order: [String] = [
                    TOBProductID.warriorAnnual.rawValue,
                    TOBProductID.warriorMonthly.rawValue,
                    TOBProductID.proAnnual.rawValue,
                    TOBProductID.proMonthly.rawValue
                ]
                let aIdx = order.firstIndex(of: a.id) ?? 99
                let bIdx = order.firstIndex(of: b.id) ?? 99
                return aIdx < bIdx
            }

            print("✅ [SubscriptionService] Loaded \(availableProducts.count) products")
        } catch {
            print("❌ [SubscriptionService] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    /**
     Initiate a purchase for a given product.
     - Sets appAccountToken to the current user's UUID so Apple includes it
       in all server notifications, allowing our webhook to identify the user.
     */
    func purchase(_ product: Product) async -> PurchaseResult {
        guard let userIdString = AuthManager.shared.currentUser?.id,
              let userUUID = UUID(uuidString: userIdString) else {
            return .failed(NSError(
                domain: "SubscriptionService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            ))
        }

        isPurchasing = true
        purchaseError = nil

        defer { isPurchasing = false }

        do {
            let result = try await product.purchase(options: [
                // This ties the Apple transaction to our user ID.
                // It shows up as appAccountToken in App Store Server Notifications.
                .appAccountToken(userUUID)
            ])

            switch result {
            case .success(let verification):
                let jwsRepresentation = verification.jwsRepresentation
                let transaction = try checkVerified(verification)
                await handleVerifiedTransaction(jwsRepresentation)
                await transaction.finish()
                let tier = TOBProductID(rawValue: product.id)?.tier ?? "pro"
                return .success(tier: tier)

            case .userCancelled:
                return .cancelled

            case .pending:
                // Transaction is awaiting approval (e.g. Ask to Buy)
                print("ℹ️ [SubscriptionService] Purchase pending approval")
                return .cancelled

            @unknown default:
                return .cancelled
            }

        } catch {
            purchaseError = error.localizedDescription
            return .failed(error)
        }
    }

    // MARK: - Transaction Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let transaction):
            return transaction
        }
    }

    /**
     After a successful purchase, send the signed JWS transaction to our backend.
     The backend decodes it, maps the productId to a tier, and updates the user's DB record.
     */
    private func handleVerifiedTransaction(_ jwsRepresentation: String) async {
        print("✅ [SubscriptionService] Verified transaction")

        // Send signed transaction to backend for verification and tier update
        do {
            try await verifyPurchaseWithBackend(signedTransaction: jwsRepresentation)
            print("✅ [SubscriptionService] Backend purchase verification succeeded")

            // Refresh stats so UI reflects new tier immediately
            PrayerManager.shared.loadStats()
            PrayOnItManager.shared.fetchStats()

        } catch {
            print("❌ [SubscriptionService] Backend verification failed: \(error)")
            // Transaction is still valid with Apple — the App Store Server Notification
            // will update our backend as a fallback. Log but don't block the user.
        }
    }

    // MARK: - Transaction Listener

    /**
     Listen for transactions that arrive outside of a direct purchase call.
     This handles renewals, revocations, and purchases made on other devices.
     */
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let jwsRepresentation = result.jwsRepresentation
                    let transaction = try await self.checkVerified(result)
                    await self.handleVerifiedTransaction(jwsRepresentation)
                    await transaction.finish()
                } catch {
                    print("⚠️ [SubscriptionService] Transaction update failed verification: \(error)")
                }
            }
        }
    }

    // MARK: - Backend API Call

    private func verifyPurchaseWithBackend(signedTransaction: String) async throws {
        guard let token = AuthManager.shared.getToken() else {
            throw NSError(domain: "SubscriptionService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No auth token"])
        }

        guard let url = URL(string: "\(Config.baseURL)/subscription/verify-purchase") else {
            throw NSError(domain: "SubscriptionService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = ["signedTransaction": signedTransaction]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SubscriptionService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }

        print("✅ [SubscriptionService] /subscription/verify-purchase → 200 OK")
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            PrayerManager.shared.loadStats()
            PrayOnItManager.shared.fetchStats()
            print("✅ [SubscriptionService] Purchases restored")
        } catch {
            print("❌ [SubscriptionService] Restore failed: \(error)")
        }
    }

    // MARK: - Helpers for UI

    func product(for id: TOBProductID) -> Product? {
        availableProducts.first { $0.id == id.rawValue }
    }

    func formattedPrice(for id: TOBProductID) -> String {
        guard let product = product(for: id) else { return "—" }
        return product.displayPrice
    }
}
