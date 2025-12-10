import SwiftUI

struct SplashView: View {
    @State private var showTitle = false
    @State private var showTagline = false
    @State private var showLoginButton = false
    var onComplete: () -> Void  // Simple callback instead of binding
    
    var body: some View {
        ZStack {
            // Angelic gradient background
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Title
                if showTitle {
                    Text("Tower of Babble")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundColor(.blue)
                        .transition(.opacity)
                }
                
                // Tagline
                if showTagline {
                    Text("The closest we can get to God is through prayer")
                        .font(.system(size: 18, weight: .light, design: .serif))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                }
                
                Spacer()
                
                // Login button
                if showLoginButton {
                    Button(action: {
                        print("Button tapped!")
                        onComplete()  // Just call the callback
                    }) {
                        Text("Enter")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(25)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            // Animate title first
            withAnimation(.easeIn(duration: 1.0)) {
                showTitle = true
            }
            
            // Then tagline after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeIn(duration: 1.0)) {
                    showTagline = true
                }
            }
            
            // Then button after another second
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showLoginButton = true
                }
            }
        }
    }
}
