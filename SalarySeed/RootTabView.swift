import SwiftUI

/// The main screens. v0.8.2: a paged TabView so the user can swipe horizontally,
/// with a custom bottom bar that also lets them tap to jump. safeAreaInset
/// reserves the bar's space so each screen's scroll content never hides behind it.
/// v0.9.2 added mapSeed as a fourth tab.
///
/// v0.10 adds Grow and REORDERS the five. The grouping is "you" and then
/// "everyone else": Home is you now, Grow is you over time, Compare is other
/// people now, the map is other people by place, and the profile is the inputs
/// behind all of it. Grow sitting next to Home also means the two screens that
/// answer questions about the user's own salary are one swipe apart.
///
/// The selection lives on the store rather than in this view so that one screen
/// can hand the user to another (Home's "what if" section sends people to Grow)
/// without two sources of truth for which tab is showing.
struct RootTabView: View {
    @EnvironmentObject private var store: SalaryStore

    private var s: Strings { store.s }

    var body: some View {
        TabView(selection: $store.selectedTab) {
            HomeView().tag(0)
            GrowView().tag(1)
            CompareView().tag(2)
            MapView().tag(3)
            ProfileView().tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(.keyboard)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selection: $store.selectedTab, s: s)
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selection: Int
    let s: Strings

    private var items: [(icon: String, title: String)] {
        [("house.fill", s.tabHome),
         ("chart.line.uptrend.xyaxis", s.tabGrow),
         ("chart.bar.fill", s.tabCompare),
         ("map.fill", s.tabMap),
         ("person.fill", s.tabProfile)]
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
                    // v0.10: five tabs instead of four, so the label gets one
                    // point less and is allowed to shrink rather than truncate.
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
