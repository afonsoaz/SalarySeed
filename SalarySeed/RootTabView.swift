import SwiftUI

/// The main screens. v0.8.2: a paged TabView so the user can swipe horizontally,
/// with a custom bottom bar that also lets them tap to jump. safeAreaInset
/// reserves the bar's space so each screen's scroll content never hides behind it.
/// v0.9.2 adds mapSeed as the fourth tab, between Compare and Profile.
struct RootTabView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var tab = 0

    private var s: Strings { store.s }

    var body: some View {
        TabView(selection: $tab) {
            HomeView().tag(0)
            CompareView().tag(1)
            MapView().tag(2)
            ProfileView().tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(.keyboard)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selection: $tab, s: s)
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selection: Int
    let s: Strings

    private var items: [(icon: String, title: String)] {
        [("house.fill", s.tabHome), ("chart.bar.fill", s.tabCompare),
         ("map.fill", s.tabMap), ("person.fill", s.tabProfile)]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                tabButton(index: i)
            }
        }
        .padding(.top, 9)
        .padding(.bottom, 4)
        .background(alignment: .top) {
            Rectangle()
                .fill(Theme.background)
                .overlay(Rectangle().fill(Theme.cardBorder).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(index i: Int) -> some View {
        let selected = selection == i
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { selection = i }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: items[i].icon)
                    .font(.system(size: 19))
                Text(items[i].title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
