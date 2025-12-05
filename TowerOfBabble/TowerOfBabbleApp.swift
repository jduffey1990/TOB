import SwiftUI

@main
struct TowerOfBabbleApp: App {
    @StateObject private var prayerManager = PrayerManager()
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashView(onComplete: {
                    print("onComplete called!")
                    showSplash = false
                })
            } else {
                PrayersListView()
                    .environmentObject(prayerManager)
                    .onAppear {
                        print("PrayersListView appeared!")
                    }
            }
        }
    }
}
