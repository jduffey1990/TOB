//
//  TierEnforcementView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 2/19/26.
//  Shown as a fullScreenCover when a user's stored data exceeds their
//  current subscription tier limits (e.g. after a downgrade or cancellation).
//
//  The user cannot dismiss this view until they have deleted enough
//  prayers and/or Pray On It items to come within their allotment.
//

import SwiftUI

struct TierEnforcementView: View {

    @ObservedObject private var prayerManager   = PrayerManager.shared
    @ObservedObject private var prayOnItManager = PrayOnItManager.shared

    // MARK: - Computed Limit State

    private var prayerLimit: Int? { prayerManager.prayerStats?.prayers.limit }
    private var prayerCount: Int  { prayerManager.prayerStats?.prayers.current ?? prayerManager.prayers.count }

    private var prayOnItLimit: Int? { prayOnItManager.limit }
    private var prayOnItCount: Int  { prayOnItManager.currentCount }

    private var prayersOverBy: Int {
        guard let limit = prayerLimit else { return 0 }
        return max(0, prayerCount - limit)
    }

    private var prayOnItsOverBy: Int {
        guard let limit = prayOnItLimit else { return 0 }
        return max(0, prayOnItCount - limit)
    }

    /// Whether the user is now within all limits and can proceed
    private var isWithinLimits: Bool {
        prayersOverBy == 0 && prayOnItsOverBy == 0
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    explanationSection

                    if prayersOverBy > 0 {
                        prayerSection
                    }

                    if prayOnItsOverBy > 0 {
                        prayOnItSection
                    }

                    doneButton
                }
                .padding()
            }
            .navigationTitle("Subscription Updated")
            .navigationBarTitleDisplayMode(.inline)
            // No toolbar dismiss button — this view is intentionally un-escapable
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Action Required")
                .font(.title)
                .fontWeight(.bold)

            Text("Your subscription has changed")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 16)
    }

    // MARK: - Explanation

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your current plan allows:")
                .font(.headline)

            if let pLimit = prayerLimit {
                Label("\(pLimit) saved prayers (you have \(prayerCount))", systemImage: "text.alignleft")
                    .foregroundColor(prayersOverBy > 0 ? .red : .primary)
            }

            if let poiLimit = prayOnItLimit {
                Label("\(poiLimit) Pray On It items (you have \(prayOnItCount))", systemImage: "list.bullet.clipboard")
                    .foregroundColor(prayOnItsOverBy > 0 ? .red : .primary)
            }

            Text("Please delete the excess items below to continue.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Prayer Deletion Section

    private var prayerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.red)
                Text("Delete \(prayersOverBy) Prayer\(prayersOverBy == 1 ? "" : "s")")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            Text("Swipe left on a prayer to delete it. Keep the ones that matter most.")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(prayerManager.prayers) { prayer in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prayer.title)
                            .font(.body)
                            .lineLimit(1)
                        Text(prayer.text)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        deletePrayer(prayer)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Pray On It Deletion Section

    private var prayOnItSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(.red)
                Text("Delete \(prayOnItsOverBy) Pray On It Item\(prayOnItsOverBy == 1 ? "" : "s")")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            Text("Remove items you no longer need to hold in prayer.")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(prayOnItManager.items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.body)
                            .lineLimit(1)
                        Text(item.category.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        deletePrayOnItItem(item)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Done Button

    private var doneButton: some View {
        VStack(spacing: 8) {
            if isWithinLimits {
                Text("You're all set! ✓")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                Text("Delete \(totalToDelete) more item\(totalToDelete == 1 ? "" : "s") to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // The Done button is always visible but disabled until within limits.
            // This makes it clear to the user what they're working toward.
            Button(action: {
                // Posting this notification tells MainTabView to re-evaluate
                // enforcement state and dismiss the cover if we're within limits.
                NotificationCenter.default.post(
                    name: .tierEnforcementComplete,
                    object: nil
                )
            }) {
                Text("I'm Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isWithinLimits ? Color.blue : Color.gray.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!isWithinLimits)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Helpers

    private var totalToDelete: Int {
        prayersOverBy + prayOnItsOverBy
    }

    private func deletePrayer(_ prayer: Prayer) {
        prayerManager.deletePrayer(prayer) { _ in
            // loadStats() is called inside deletePrayer already
        }
    }

    private func deletePrayOnItItem(_ item: PrayOnItItem) {
        prayOnItManager.deleteItem(item)
    }
}

// MARK: - Notification Name

extension NSNotification.Name {
    static let tierEnforcementComplete = NSNotification.Name("TierEnforcementComplete")
}
