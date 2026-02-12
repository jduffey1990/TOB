//
//  SignUpView.swift
//  TowerOfBabble
//
//  WORKING VERSION with denomination picker
//

import SwiftUI

struct SignupView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var selectedDenomination = ""
    @State private var denominations: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showAlert = false
    @State private var showingCustomInput = false
    @State private var customDenomination = ""
    
    var onNavigateToLogin: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header
                        VStack(spacing: 10) {
                            Text("Create Account")
                                .font(.system(size: 36, weight: .bold, design: .serif))
                                .foregroundColor(.blue)
                            
                            Text("Join us in your prayer journey")
                                .font(.system(size: 16, design: .serif))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 60)
                        
                        // Form fields
                        VStack(spacing: 20) {
                            // Name field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Full Name")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                TextField("Enter your full name", text: $name)
                                    .textContentType(.name)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Email field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                TextField("Enter your email", text: $email)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                SecureField("Create a password (min 6 characters)", text: $password)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Confirm password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                SecureField("Re-enter password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Denomination Picker - WORKING VERSION
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Religious Denomination")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text("*")
                                        .foregroundColor(.red)
                                }
                                
                                NavigationLink(destination: DenominationSelectionView(
                                    denominations: denominations,
                                    selectedDenomination: $selectedDenomination
                                )) {
                                    HStack {
                                        Text(selectedDenomination.isEmpty ? "Select denomination" : selectedDenomination)
                                            .foregroundColor(selectedDenomination.isEmpty ? .gray : .primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 20)
                        
                        // Terms & Privacy Agreement
                        VStack(alignment: .leading, spacing: 12) {
                            
                            Text(
                                try! AttributedString(
                                    markdown: "By creating an account, you agree to our [Terms of Service](https://tobprayer.app/terms)"
                                )
                            )
                            .font(.footnote)
                            .foregroundColor(.gray)
                            
                            Text(
                                try! AttributedString(
                                    markdown: "and [Privacy Policy](https://tobprayer.app/privacy)"
                                )
                            )
                            .font(.footnote)
                            .foregroundColor(.gray)
                        }                        .padding(.horizontal, 30)
                        .padding(.top, 10)
                        
                        // Status messages
                        if let error = errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.horizontal, 30)
                                .multilineTextAlignment(.center)
                        }
                        
                        if let success = successMessage {
                            Text(success)
                                .font(.footnote)
                                .foregroundColor(.green)
                                .padding(.horizontal, 30)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Create Account button
                        Button(action: handleSignup) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(width: 200, height: 50)
                            } else {
                                Text("Create Account")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 200, height: 50)
                            }
                        }
                        .background(isFormValid ? Color.blue : Color.gray)
                        .cornerRadius(25)
                        .disabled(!isFormValid || isLoading)
                        .padding(.top, 10)
                        
                        // Sign in link
                        Button(action: onNavigateToLogin) {
                            HStack(spacing: 4) {
                                Text("Already have an account?")
                                    .foregroundColor(.gray)
                                Text("Sign In")
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .alert(successMessage != nil ? "Success" : "Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if successMessage != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onNavigateToLogin()
                        }
                    }
                }
            } message: {
                Text(successMessage ?? errorMessage ?? "An error occurred")
            }
            .alert("Enter Your Denomination", isPresented: $showingCustomInput) {
                TextField("e.g., Protestant, Catholic, etc.", text: $customDenomination)
                    .autocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    customDenomination = ""
                }
                Button("OK") {
                    if !customDenomination.trimmingCharacters(in: .whitespaces).isEmpty {
                        selectedDenomination = customDenomination.trimmingCharacters(in: .whitespaces)
                    }
                    customDenomination = ""
                }
            } message: {
                Text("We couldn't load denominations from the server. Please enter your religious denomination or spiritual tradition.")
            }
            .onAppear {
                fetchDenominations()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        let nameValid = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let passwordsMatch = password == confirmPassword
        let denominationValid = !selectedDenomination.trimmingCharacters(in: .whitespaces).isEmpty
        
        return emailValid && passwordValid && nameValid && passwordsMatch && denominationValid
    }
    
    // MARK: - Actions
    
    private func fetchDenominations() {
            AuthService.shared.fetchDenominations { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let fetchedDenominations):
                        self.denominations = fetchedDenominations
                        print("✅ Loaded \(fetchedDenominations.count) denominations")
                        
                    case .failure(let error):
                        print("❌ Failed to load denominations: \(error)")
                        // NEW: Instead of hardcoded fallback, show custom input dialog
                        self.showingCustomInput = true
                    }
                }
            }
        }
    
    private func handleSignup() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("selectedDenomination: \(selectedDenomination)")
        
        AuthService.shared.createUser(
            email: email.lowercased(),
            password: password,
            name: name,
            denomination: selectedDenomination
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let user):
                    if user.status == "inactive" {
                        successMessage = "Account created! Please check your email to verify your account."
                        showAlert = true
                    } else {
                        successMessage = "Account created successfully! Please sign in."
                        showAlert = true
                    }
                    
                case .failure(let error):
                    handleError(error)
                }
            }
        }
    }
    
    private func handleError(_ error: AuthError) {
        switch error {
        case .invalidCredentials:
            errorMessage = "Invalid email or password"
        case .userInactive:
            errorMessage = "Please verify your email to activate your account"
        case .networkError(let message):
            errorMessage = "Network error: \(message)"
        case .serverError(let message):
            errorMessage = message
        case .decodingError:
            errorMessage = "Error processing server response"
        case .unknown:
            errorMessage = "An unexpected error occurred"
        case .unauthorized:
            errorMessage = "You are not authorized to perform this action"
        }
        showAlert = true
    }
}

// MARK: - Denomination Selection View

struct DenominationSelectionView: View {
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
        .searchable(text: $searchText, prompt: "Search denominations")
        .navigationTitle("Select Denomination")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Enter Your Denomination", isPresented: $showingCustomInput) {
            TextField("e.g. Protestant, Catholic, etc.", text: $customDenomination)
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

// MARK: - Preview

struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView(onNavigateToLogin: {})
    }
}
