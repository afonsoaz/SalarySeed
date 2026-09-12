import SwiftUI

/// The main screens.
///
/// v1.2 REPLACED THE BAR WITH APPLE'S. Until now this was a paged `TabView`
/// (`.tabViewStyle(.page)`) with a hand-drawn bar pushed in through
/// `safeAreaInset`, which meant there was no UIKit tab bar on screen anywhere in
/// the app. That bought horizontal swiping between tabs and a persistently
/// tinted Grow item, and it cost everything the real control does for free:
/// the material behind it, the scroll-edge effect, minimising on scroll, and
/// the accessibility semantics of an actual tab bar. On iOS 26 it also cost the
/// glass, which arrives with no code at all as long as nothing here sets
/// `UITabBar.appearance()` to something opaque. Nothing does, and nothing should.
///
/// Two behaviours went with the old bar and are not reproduced. Swiping between
/// tabs is gone, because that is not what native tabs do. Grow's tab item is no
/// longer tinted while unselected; a real tab bar tints the selected item and
/// only the selected item, and the trick was a workaround for a bar that had no
/// rules of its own.
///
/// THE ORDER runs from the most concrete to the most speculative: what you are
/// actually paid, what your last payslip says about it, how that compares, where
/// it would compare differently, and what it might become. The payslip sits
/// second because it is the one screen about something that already happened.
///
/// PROFILE IS NOT HERE ANY MORE. A native iPhone tab bar shows five items and
/// collapses anything past that into a system "More" list, so the sixth tab the
/// checker needed had to come from somewhere. Profile went, because it is the
/// only one of the six that is settings rather than an answer. It is reached
/// from the sprout in `HomeView.topBar`, and the two `SupportLock` gates still
/// open the support sheet directly, so the payment ask did not move.
///
/// The selection lives on the store rather than in this view so that one screen
/// can hand the user to another without two sources of truth for which tab is
/// showing.
struct RootTabView: View {
    @EnvironmentObject private var store: SalaryStore

    private var s: Strings { store.s }

    var body: some View {
        TabView(selection: $store.selectedTab) {
            HomeView()
                .tabItem { Label(s.tabHome, systemImage: "house.fill") }
                .tag(0)
            // `context` and `onAccept` are built here rather than inside the
            // feature, because `SalaryStore.adopt` is a write and
            // `Features/Payslip/` reads the store and never writes to it. This
            // is the same wiring `HomeView` carried while the checker was a
            // card there.
            PayslipTabView(
                context: PayslipContext(region: store.taxRegion,
                                        months: store.schedule.months,
                                        marital: store.maritalSituation,
                                        dependents: store.dependents,
                                        jovemExemption: store.irsJovemExemption),
                onAccept: { store.adopt($0) })
                .tabItem { Label(s.tabPayslip, systemImage: "doc.text.magnifyingglass") }
                .tag(1)
            CompareView()
                .tabItem { Label(s.tabCompare, systemImage: "chart.bar.fill") }
                .tag(2)
            MapView()
                .tabItem { Label(s.tabMap, systemImage: "map.fill") }
                .tag(3)
            GrowView()
                .tabItem { Label(s.tabGrow, systemImage: "chart.line.uptrend.xyaxis") }
                .tag(4)
        }
        .tabBarMinimisesOnScroll()
    }
}

extension View {
    /// iOS 26 lets the tab bar shrink out of the way as the reader scrolls down
    /// and come back when they scroll up. Worth having on five screens that are
    /// all long scrolls, and it does not exist before 26, so it is asked for
    /// here rather than at the call site: an `if #available` wrapped around the
    /// `TabView` itself would give SwiftUI two different views to identify.
    @ViewBuilder
    func tabBarMinimisesOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
