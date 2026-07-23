import SwiftUI

@main
struct SalarySeedApp: App {
    @StateObject private var store = SalaryStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if store.hasOnboarded {
                    RootTabView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(store)
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
        }
    }
}
