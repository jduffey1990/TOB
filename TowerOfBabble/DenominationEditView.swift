//
//  DenominationEditView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 2/11/26.
//  View for editing user's religious denomination from settings
//  Fetches denominations list and updates via backend API
//

import SwiftUI

struct DenominationEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedDenomination: String
    @State private var denominations: [String] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingCustomInput = false
    @State private var customDenomination = ""
    
    init() {
        // Initialize with current user's denomination
        _selectedDenomination = State(initialValue: AuthService.shared.getCurrentUser()?.denomination ?? "Christian")
    }
    
    var filteredDenominations: [String] {
        if searchText.isEmpty {
            return denominations
        }
        return denominations.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack {
            List {
                ForEach(filteredDenominations, id: \.self) { denomination in
                    Button(action: {
                        if denomination == "Other" {
                            showingCustomInput = true
                        } else {
                            selectedDenomination = denomination
                            updateDenomination(denomination)
                        }
                    }) {
                        HStack {
                            Text(denomination)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedDenomination == denomination {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search denominations")
            .navigationTitle("Denomination")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Update Status", isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if alertMessage.contains("successfully") {
                        // Navigate back on success
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .alert("Enter Your Denomination", isPresented: $showingCustomInput) {
                TextField("e.g., Community Church", text: $customDenomination)
                    .autocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    customDenomination = ""
                }
                Button("OK") {
                    if !customDenomination.trimmingCharacters(in: .whitespaces).isEmpty {
                        let trimmed = customDenomination.trimmingCharacters(in: .whitespaces)
                        selectedDenomination = trimmed
                        updateDenomination(trimmed)
                    }
                    customDenomination = ""
                }
            } message: {
                Text("Please enter your religious denomination or spiritual tradition.")
            }
            .onAppear {
                fetchDenominations()
            }
            
            // Loading overlay
            if isLoading || isSaving {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text(isSaving ? "Updating..." : "Loading...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func fetchDenominations() {
        isLoading = true
        
        AuthService.shared.fetchDenominations { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let fetchedDenominations):
                    self.denominations = fetchedDenominations
                    print("✅ Loaded \(fetchedDenominations.count) denominations")
                    
                case .failure(let error):
                    print("❌ Failed to load denominations: \(error)")
                    // Use default list if fetch fails
                    self.denominations = [
                        "Christian",
                        "Roman Catholic",
                        "Eastern Orthodox",
                        "Protestant - Baptist",
                        "Protestant - Methodist",
                        "Protestant - Lutheran",
                        "Protestant - Presbyterian",
                        "Orthodox Judaism",
                        "Reform Judaism",
                        "Sunni Islam",
                        "Shia Islam",
                        "Buddhism - Theravada",
                        "Buddhism - Mahayana",
                        "Hinduism",
                        "Sikhism",
                        "Spiritual but not religious",
                        "Atheist",
                        "None",
                        "Other"
                    ]
                }
            }
        }
    }
    
    private func updateDenomination(_ newDenomination: String) {
        isSaving = true
        
        AuthService.shared.updateDenomination(denomination: newDenomination) { result in
            DispatchQueue.main.async {
                isSaving = false
                
                switch result {
                case .success(let updatedUser):
                    // Update AuthManager's current user
                    AuthManager.shared.currentUser = updatedUser
                    
                    alertMessage = "Denomination updated successfully"
                    showAlert = true
                    
                    print("✅ Denomination updated to: \(newDenomination)")
                    
                case .failure(let error):
                    print("❌ Failed to update denomination: \(error)")
                    
                    switch error {
                    case .networkError(let message):
                        alertMessage = "Network error: \(message)"
                    case .serverError(let message):
                        alertMessage = message
                    case .unauthorized:
                        alertMessage = "You must be logged in to update your denomination"
                    default:
                        alertMessage = "Failed to update denomination. Please try again."
                    }
                    
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Preview

struct DenominationEditView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DenominationEditView()
        }
    }
}
