import SwiftUI

struct PrayersListView: View {
    @StateObject private var prayerManager = PrayerManager()
    @State private var showingNewPrayer = false
    @State private var showingLogoutAlert = false
    @State private var shouldLogout = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                mainContent
                
                // Floating + button
                floatingAddButton
            }
            .navigationTitle("My Prayers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    userMenu
                }
            }
            .sheet(isPresented: $showingNewPrayer) {
                // Pass prayerManager as environment object
                PrayerEditorView(prayer: nil)
                    .environmentObject(prayerManager)
            }
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var mainContent: some View {
        if prayerManager.prayers.isEmpty {
            emptyStateView
        } else {
            prayersList
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "hands.sparkles")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.3))
            
            Text("No Prayers Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            Text("Tap the + button to create your first prayer")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var prayersList: some View {
        List {
            ForEach(prayerManager.prayers) { prayer in
                prayerRow(prayer)
            }
            .onDelete(perform: deletePrayer)
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func prayerRow(_ prayer: Prayer) -> some View {
        NavigationLink(destination:
            PrayerEditorView(prayer: prayer)
                .environmentObject(prayerManager)
        ) {
            VStack(alignment: .leading, spacing: 5) {
                Text(prayer.title)
                    .font(.headline)
                
                Text(prayer.text)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            .padding(.vertical, 5)
        }
    }
    
    private var floatingAddButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    showingNewPrayer = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    private var userMenu: some View {
        Menu {
            userMenuContent
        } label: {
            Image(systemName: "person.circle")
                .font(.title3)
        }
    }
    
    @ViewBuilder
    private var userMenuContent: some View {
        if let user = AuthService.shared.getCurrentUser() {
            Text(user.name)
            Text(user.email)
                .font(.caption)
            
            Divider()
        }
        
        Button(role: .destructive, action: {
            showingLogoutAlert = true
        }) {
            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
        }
    }
    
    // MARK: - Actions
    
    private func deletePrayer(at offsets: IndexSet) {
        prayerManager.prayers.remove(atOffsets: offsets)
        prayerManager.savePrayers()
    }
    
    private func logout() {
        AuthService.shared.logout()
        // Force quit to restart authentication flow
        // This is a simple approach for MVP
        exit(0)
    }
}

struct PrayersListView_Previews: PreviewProvider {
    static var previews: some View {
        PrayersListView()
    }
}
