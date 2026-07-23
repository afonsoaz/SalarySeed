import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: SalaryStore

    private var s: Strings { store.s }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(s.tabHome, systemImage: "house.fill") }
            CompareView()
                .tabItem { Label(s.tabCompare, systemImage: "chart.bar.fill") }
            ProfileView()
                .tabItem { Label(s.tabProfile, systemImage: "person.fill") }
        }
    }
}
