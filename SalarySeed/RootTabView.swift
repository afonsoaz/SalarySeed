import SwiftUI

/// The main screens. v0.8.2: a paged TabView so the user can swipe horizontally,
/// with a custom bottom bar that also lets them tap to jump. safeAreaInset
/// reserves the bar's space so each screen's scroll content never hides behind it.
/// v0.9.2 added mapSeed as a fourth tab. v0.10 added Grow as a fifth.
///
/// v0.10.1 moves Grow to the right, next to the profile. The order now runs from
/// the most concrete to the most speculative: what you earn now, how that
/// compares, where it would compare differently, what it might become, and the
/// inputs behind all of it. Grow is the one screen that projects rather than
/// reports, so it belongs at the far end of that run rather than second.
///
/// Grow's tab item is tinted even when it is not selected. It is the newest and
/// least obvious of the five, and one persistently coloured item is a cheaper way
/// to say "there is something here" than a card on Home telling people to go
/// there. Selection stays legible because the selected item, whichever it is,
/// gets a soft pill behind it.
///
/// The selection lives on the store rather than in this view so that one screen
/// can hand the user to another without two sources of truth for which tab is
/// showing.
struct RootTabView: View {
    @EnvironmentObject private var store: SalaryStore

    private var s: Strings { store.s }

    var body: some View {
        TabView(selection: $store.selectedTab) {
            HomeView().tag(0)
            CompareView().tag(1)
            MapView().tag(2)
            GrowView().tag(3)
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

    /// `tinted` marks a tab that stays accent-coloured when it is not selected.
    private var items: [(icon: String, title: String, tinted: Bool)] {
        [("house.fill", s.tabHome, false),
         ("chart.bar.fill", s.tabCompare, false),
         ("map.fill", s.tabMap, false),
         ("chart.line.uptrend.xyaxis", s.tabGrow, true),
         ("person.fill", s.tabProfile, false)]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                tabButton(index: i)
            }
        }
        .padding(.top, 7)
        .padding(.bottom, 4)
        .background(alignment: .top) {
            Rectangle()
                .fill(Theme.background)
                .overlay(Rectangle().fill(Theme.cardBorder).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(index i: Int) -> some View {
        let item = items[i]
        let selected = selection == i
        // Unselected: grey, except the tinted one. Selected: accent for everyone,
        // with the pill doing the work of showing which one it is.
        let tint = selected ? Theme.accent : (item.tinted ? Theme.accent.opacity(0.8) : Theme.textSecondary)
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { selection = i }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: 18))
                Text(item.title)
                    // v0.10: five tabs instead of four, so the label gets a
                    // point less and is allowed to shrink rather than truncate.
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(tint)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(selected ? Theme.accentSoft : .clear,
                        in: RoundedRectangle(cornerRadius: 11))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
