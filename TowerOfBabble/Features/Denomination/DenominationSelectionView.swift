//
//  DenominationSelectionView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 2/11/26.
//  Reusable denomination picker with search functionality
//  Supports "Other" option with custom text input
//

import SwiftUI

struct DenominationPickerView: View {
    let denominations: [String]
    @Binding var selectedDenomination: String
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var showingCustomInput = false
    @State private var customDenomination = ""
    
    var filteredDenominations: [String] {
        if searchText.isEmpty {
            return denominations
        }
        return denominations.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredDenominations, id: \.self) { denomination in
                    Button(action: {
                        if denomination == "Other" {
                            showingCustomInput = true
                        } else {
                            selectedDenomination = denomination
                            presentationMode.wrappedValue.dismiss()
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
            .searchable(text: $searchText, prompt: "Search Religion")
            .navigationTitle("Select Religion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Enter Your Religion", isPresented: $showingCustomInput) {
                TextField("e.g., Community Church", text: $customDenomination)
                    .autocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    customDenomination = ""
                }
                Button("OK") {
                    if !customDenomination.trimmingCharacters(in: .whitespaces).isEmpty {
                        selectedDenomination = customDenomination.trimmingCharacters(in: .whitespaces)
                        presentationMode.wrappedValue.dismiss()
                    }
                    customDenomination = ""
                }
            } message: {
                Text("Please enter your religious denomination or spiritual tradition.")
            }
        }
    }
}

// MARK: - Preview

struct DenominationPickerView_Previews: PreviewProvider {
    static var previews: some View {
        DenominationPickerView(
            denominations: [
                "Roman Catholic",
                "Baptist",
                "Orthodox Judaism",
                "Sunni Islam",
                "Buddhism",
                "Hinduism",
                "Other"
            ],
            selectedDenomination: .constant("Roman Catholic")
        )
    }
}
