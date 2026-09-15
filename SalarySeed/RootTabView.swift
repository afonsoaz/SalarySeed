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

    /// v1.4: the intro screen is a SIBLING IN A ZSTACK, not a `fullScreenCover`.
    ///
    /// A cover would work now that nothing has to reach the tab bar, but its
    /// dismissal slides the screen down off the top, and the right ending for
    /// "here is your app" is the app fading up underneath. `.transition(.opacity)`
    /// on a sibling gives that for one line more.
    ///
    /// `finish()` and `SalarySeedApp` are untouched by this, there is still no
    /// `.id()` anywhere on the root (see the note at the top of SalarySeedApp),
    /// and every `@State` in the tab tree stays alive behind it.
    var body: some View {
        ZStack {
            tabs
            if store.showingIntro {
                FeatureIntroView(onDone: { store.showingIntro = false })
                    .transition(.opacity)
            }
        }
    }

    private var tabs: some View {
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
        .overlay(alignment: .top) { statusBarScrim }
    }

    /// v1.2a: WHY THE APP DRAWS ITS OWN STATUS-BAR SCRIM.
    ///
    /// None of the five tabs has a navigation bar, because none of them wants a
    /// title: each screen draws its own header inside its scroll view. The cost
    /// only shows once you scroll, and it is ugly. Content passes straight under
    /// the clock and the battery, white on near-black with nothing between them,
    /// so "Salario bruto  2400 EUR" reads through "00:39".
    ///
    /// `scrollEdgeEffectStyle(.soft, for: .top)` is the iOS 26 API for exactly
    /// this and it was tried first and does nothing here: the effect is drawn by
    /// a bar at that edge, and there is no bar. Adding one to get it would cost
    /// 44 points on five screens to display a title none of them has.
    ///
    /// So: a scrim in the page's own colour, which is invisible where there is
    /// nothing under it and hides what scrolls beneath it. It sits on the
    /// `TabView` rather than in five screens, it never takes a touch, and the
    /// fade means content dissolves rather than meeting a line.
    private var statusBarScrim: some View {
        LinearGradient(
            stops: [.init(color: Theme.background, location: 0),
                    .init(color: Theme.background, location: 0.62),
                    .init(color: Theme.background.opacity(0), location: 1)],
            startPoint: .top, endPoint: .bottom)
            .frame(height: 96)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

// v1.2a REMOVED `.tabBarMinimizeBehavior(.onScrollDown)`, which was added in
// v1.2 and looked right in a list of iOS 26 features and wrong on the screen.
//
// Minimising collapses the bar to a small circle that floats OVER the content
// with no material behind most of its width, so it sat on top of a card and cut
// a line of text in half; and while it is collapsed the other four tabs cannot
// be reached without scrolling back up. Apple uses it where the content is the
// point and the chrome is in the way, which is a video or a web page. Five long
// scrolls of figures, where the whole job is moving between them, is the other
// case. The full glass bar already blurs what passes under it, which is the part
// that was worth having.
