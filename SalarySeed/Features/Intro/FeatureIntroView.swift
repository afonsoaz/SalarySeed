import SwiftUI

/// v1.4: the app introduces itself, once, right after onboarding.
///
/// Nine questions used to end in a hard cut to a five-tab app, with nobody ever
/// saying what Compare, Map or Grow were for. This is one screen: a headline,
/// four cards naming what the app does, and a button.
///
/// ONE SCREEN AND NOT A TOUR, deliberately. A four-card tour was designed first
/// and thrown away: it needed a figure per card to be worth paging through, and
/// three of the four figures have a bare-profile case to get right, so it was
/// four cards to keep honest instead of one screen to read. This asks for
/// nothing, claims nothing, and is over in the time it takes to read it.
///
/// It also carries NO figures, which is what makes it safe: a card that cannot
/// contradict the tab it names is worth more than one that could. And nothing
/// here names a price or leads to one, in a free build or a paid one. See the
/// money rules in CLAUDE.md.
struct FeatureIntroView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The app's first reduce-motion path. See `choreographed`.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Called when the reader is done. The caller animates the dismissal.
    let onDone: () -> Void

    @State private var shown = false

    private var s: Strings { store.s }

    /// One of the four things the app does, in tab order.
    ///
    /// An enum rather than four hand-written cards, so they cannot drift apart:
    /// the glyphs are the same symbols `RootTabView` gives the tabs, and three
    /// of the four titles are the same strings, so a card and the tab it names
    /// say the same word by construction.
    private enum IntroFeature: Int, CaseIterable, Identifiable {
        case compare, map, grow, more
        var id: Int { rawValue }

        var glyph: String {
            switch self {
            case .compare: return "chart.bar.fill"
            case .map: return "map.fill"
            case .grow: return "chart.line.uptrend.xyaxis"
            case .more: return "ellipsis.circle.fill"
            }
        }

        func title(_ s: Strings) -> String {
            switch self {
            case .compare: return s.tabCompare
            case .map: return s.tabMap
            case .grow: return s.tabGrow
            // THE FOURTH IS "MORE" AND NOT THE PAYSLIP CHECKER, which is the
            // app's best screen and would be the obvious thing to name. It is
            // left out because onboarding step 1 now opens with it: naming it
            // here would introduce something the reader has already used.
            case .more: return s.introMore
            }
        }
    }

    /// Whether to run the staggered entrance.
    ///
    /// Off for reduce motion, for the obvious reason. Also off at an
    /// accessibility text size, and that is a design decision rather than
    /// caution: there the four cards become a vertical stack that fills the
    /// screen and scrolls, so a rise-and-settle on each one is motion the
    /// reader has to sit through before they can read anything.
    private var choreographed: Bool { !reduceMotion && !typeSize.isAccessibilitySize }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.accent.opacity(0.07), .clear],
                center: .top, startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()

            // The `scrollingStep` shape from OnboardingView, and the same
            // reason: every step here is a column ending in a button, and with
            // no scroll view the column can never be taller than the screen, so
            // once the reader's text no longer fits SwiftUI takes the space back
            // out of the Text views. `minHeight: geo.size.height` is what keeps
            // the default look identical, because without it the column shrinks
            // to its content and the Spacer stops pushing.
            //
            // Nothing inside a card scrolls, so rule 17 is clear.
            GeometryReader { geo in
                ScrollView {
                    column.frame(minHeight: geo.size.height, alignment: .top)
                }
            }
            .padding(24)
        }
        // So VoiceOver cannot wander into the live tabs underneath.
        .accessibilityAddTraits(.isModal)
        .task {
            // Marked seen ON APPEAR, not on the button. Somebody who
            // backgrounds the app while this is up has seen it and chose to
            // leave; showing it again on the next launch is the nag the money
            // rules forbid.
            store.hasSeenIntro = true
            // One runloop, so the entrance animates from its starting state
            // rather than being the first thing rendered.
            await Task.yield()
            withAnimation(nil) { }
            shown = true
        }
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Two Spacers of equal weight, so the block sits in the middle of
            // the screen with the button at the bottom. Without the first one
            // everything crowds the top and leaves a screen and a half of void
            // above the button, which is what this looked like when it was
            // first drawn.
            //
            // Past an accessibility text size the content is taller than the
            // screen, both collapse to their minLength, and it scrolls.
            Spacer(minLength: 16)

            HStack {
                Spacer()
                SproutView(stage: 3, size: 64, animatesIn: choreographed)
                    .accessibilityHidden(true)
                Spacer()
            }
            .modifier(Rise(shown: shown, delay: 0, choreographed: choreographed))

            Text(s.introTitle)
                .appFont(26, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)
                .modifier(Rise(shown: shown, delay: 0.04, choreographed: choreographed))

            Text(s.introSub)
                .appFont(14)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .modifier(Rise(shown: shown, delay: 0.08, choreographed: choreographed))

            cards
                .padding(.top, 26)

            Spacer(minLength: 16)

            PrimaryButton(title: s.introButton) { finish() }
                .modifier(Rise(shown: shown,
                               delay: 0.14 + 0.08 * Double(IntroFeature.allCases.count),
                               choreographed: choreographed))
        }
    }

    /// Four cards across, or four rows down past an accessibility text size.
    ///
    /// THE REFLOW IS MANDATORY, not a nicety. Four cards on a 402 point phone
    /// are about 76 points wide, and `band(for: 11)` is `.caption2`, so an 11pt
    /// label becomes 28pt at `accessibilityExtraLarge`: "Comparar" measures
    /// around 122 points against 76 available and would truncate or break
    /// mid-word, which is the v1.0.3 class of bug. Below the threshold nothing
    /// changes at all.
    @ViewBuilder
    private var cards: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                ForEach(Array(IntroFeature.allCases.enumerated()), id: \.element.id) { i, feature in
                    wideCard(feature)
                        .modifier(Rise(shown: shown, delay: 0.14 + 0.08 * Double(i),
                                       choreographed: choreographed))
                }
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(IntroFeature.allCases.enumerated()), id: \.element.id) { i, feature in
                    tallCard(feature)
                        .modifier(Rise(shown: shown, delay: 0.14 + 0.08 * Double(i),
                                       choreographed: choreographed))
                }
            }
            // A fixed, scaled height rather than an intrinsic one, so the four
            // are equal without any `fixedSize` gymnastics. Safe only because
            // of the reflow above: this branch never runs past the accessibility
            // threshold, and below it an 11pt label reaches at most about 15pt,
            // which a 104 point card holding a 24pt glyph has room for.
            .frame(height: Theme.scaled(104, typeSize))
        }
    }

    private func tallCard(_ feature: IntroFeature) -> some View {
        VStack(spacing: 8) {
            // A fixed, scaled BOX for the glyph, so the four labels share a
            // line. The four symbols do not have the same vertical extent
            // (`ellipsis.circle.fill` is a full circle where `chart.bar.fill`
            // is bars with no descender), and without this the labels sit a
            // few points apart from each other, which reads as a wobble across
            // a row of four. Scaled, not a literal, so the box grows with the
            // glyph.
            Image(systemName: feature.glyph)
                .appFont(24)
                .foregroundStyle(Theme.accent)
                .frame(height: Theme.scaled(28, typeSize))
                .accessibilityHidden(true)
            Text(feature.title(s))
                .appFont(11, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1))
        // One element, so a screen reader hears "Compare" rather than a symbol
        // name and a word.
        .accessibilityElement(children: .combine)
    }

    private func wideCard(_ feature: IntroFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: feature.glyph)
                .appFont(24)
                .foregroundStyle(Theme.accent)
                .frame(width: Theme.scaled(34, typeSize))
                .accessibilityHidden(true)
            Text(feature.title(s))
                .appFont(15, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func finish() {
        // The fade lives on the caller's side of the ZStack, so the app comes up
        // underneath rather than this sliding away off something.
        withAnimation(.easeOut(duration: 0.28)) { onDone() }
    }
}

/// The staggered entrance, as one modifier so the four cards, the headline and
/// the button all use the same curve and cannot drift.
///
/// `anchor: .bottom` so things rise rather than bloom, matching `SproutView`'s
/// own `animatesIn`. The spring is a touch slower than the house
/// `0.45 / 0.8` because several of these are in flight at once and a snap reads
/// as a flicker when it is four things instead of one.
///
/// When `choreographed` is false this is a plain fade and nothing moves at all.
private struct Rise: ViewModifier {
    let shown: Bool
    let delay: Double
    let choreographed: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: choreographed ? (shown ? 0 : 14) : 0)
            .scaleEffect(choreographed ? (shown ? 1 : 0.96) : 1, anchor: .bottom)
            .animation(choreographed
                       ? .spring(response: 0.5, dampingFraction: 0.82).delay(delay)
                       : .easeOut(duration: 0.2),
                       value: shown)
    }
}
