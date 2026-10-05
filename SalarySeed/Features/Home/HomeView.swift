import SwiftUI

/// netSeed: the salary, and every way into the rest of the app.
///
/// v0.2: greeting, living-sprout brand mark, count-up + leaf unfurl.
/// v0.3: all copy comes from the string table (EN + PT).
/// v1.4: Home held one number, with the detail a scroll below it.
///
/// THE HUB MADE HOME THE ONLY WAY AROUND THE APP. There is no tab bar. Home
/// shows the salary at the centre, an "Update my salary" bubble on it, and one
/// row per feature below, each opening its own screen on Home's one navigation
/// stack. Profile is behind the person at the top right, and nowhere else.
///
/// What Home showed below the fold, where the money goes, the two detail trees
/// and the annual settlement, is the Tax screen now, drawn by the same views.
/// The "What if…" cards became rows: the job offer has its own, and trying
/// another salary and the hidden cost of ajudas live in Other tools. What is
/// left here is what somebody opening the app wants first: what they earn, and
/// where to go next.
struct HomeView: View {
    @EnvironmentObject private var store: SalaryStore
    /// Read for the row locks, which can only ever draw in a paid build.
    @EnvironmentObject private var supporter: SupporterStore
    /// Read for `leafSize`, and for the rows' trailing glyph.
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var period: ResultPeriod = .m14
    @State private var pickedInitial = false
    /// The one payslip reading the app holds, for as long as the app runs.
    ///
    /// Home owns it because Home is the root and lives exactly that long, which
    /// is the lifetime the checker promised as a tab: leave it and come back and
    /// the verdict is still there; read another payslip, from either way in,
    /// and it is replaced; quit and it is gone. It is never written anywhere.
    @StateObject private var payslip = PayslipCheckModel()

    // `ResultPeriod` lived here until v1.5. It is in Features/Shared now, so the
    // offer screen reads its two salaries through the very same picker, and
    // the Tax screen reads through Home's own `period`, bound.

    private var s: Strings { store.s }
    private var b: SalaryBreakdown { store.breakdown }
    private var factor: Double { period.factor(months: b.months) }

    var body: some View {
        // The one stack every screen in the app is pushed onto, with its path
        // on the store so any screen can return here. See `HubRoute`.
        NavigationStack(path: $store.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    greeting
                        .padding(.top, 14)
                    heroNet
                        .padding(.top, 26)
                    heroFootnotes
                    updateBubble
                        .padding(.top, 14)
                    // The picker changes the number, so it sits under the number.
                    periodPicker
                        .padding(.top, 18)
                    hubRows
                        .padding(.top, 24)
                    profileNudge
                    TaxDisclaimer()
                        .padding(.top, 18)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(alignment: .top) {
                RadialGradient(
                    colors: [Theme.accent.opacity(0.06), .clear],
                    center: .top, startRadius: 0, endRadius: 420
                )
                .ignoresSafeArea()
            }
            .background(Theme.background)
            // On Home's scroll view, INSIDE the stack, so it slides away with
            // Home. Every pushed screen has a navigation bar, which draws its own
            // scroll-edge effect, and rule 30 is "never both".
            .overlay(alignment: .top) { statusBarScrim }
            .hubDestinations(period: $period, payslip: payslip)
            .onAppear {
                // Open on the lens that equals the user's real per-payment amount.
                guard !pickedInitial else { return }
                period = store.schedule == .twelve ? .m12 : .m14
                pickedInitial = true
            }
        }
    }

    // MARK: Top

    /// v1.4 DELETED the two-row accessibility branch this used to have, by
    /// moving the thing it existed for: the 188pt period picker. What is left is
    /// a wordmark and a 44pt button, which fit on one row at every text size,
    /// including AX5, and a reflow branch for a row that no longer overflows is
    /// a branch nobody can check.
    ///
    /// The button is the way into Profile, and the only one: no other screen
    /// carries it, because Home is where the reader goes from.
    private var topBar: some View {
        HStack {
            brandMark
            Spacer()
            ProfileButton { store.path = [.profile] }
        }
        .padding(.top, 8)
    }

    private var brandMark: some View {
        HStack(spacing: 6) {
            // the brand mark is alive: it grows with the profile (sproutStage 1 to 5)
            SproutView(stage: store.sproutStage, size: 18)
            // One line always. It is a wordmark, and a wordmark that wraps is a
            // typo as far as the reader is concerned.
            Text("SalarySeed").appFont(13, weight: .medium).lineLimit(1)
        }
        .foregroundStyle(Theme.accent)
    }

    /// v1.4: one line. 18pt on the `.body` curve, deliberately not 20: 20
    /// crosses into `.title3` and the greeting would then grow more slowly than
    /// the figure beneath it. No lineLimit, because "reflow, do not shrink" is
    /// locked and a long name wrapping to two lines is the correct outcome.
    private var greeting: some View {
        Text(s.hey(store.displayName))
            .appFont(18)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: The figure

    /// v1.4: net leads at 44pt with gross as a 20pt annotation under it.
    ///
    /// 44 is not too big, and it is measured rather than judged. `band(for: 44)`
    /// is `.largeTitle`, so it resolves to 67pt at accessibility-extra-large,
    /// where the widest figure anybody will see ("140 000 €", plus the leaf) is
    /// 334 points of the 335 available. `minimumScaleFactor` never engages.
    ///
    /// THE FIGURE IS NOT A BUTTON ANY MORE. v1.4 made the whole block the way
    /// into the editor, with an 11pt pencil on the label as the only hint that a
    /// number could be tapped. The hub put a bubble on it that says what it
    /// does, so the number is just the number again and the pencil is gone.
    private var heroNet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(s.netWord) / \(s.periodSuffix(period.modeIndex))")
                .appFont(12)
                .foregroundStyle(Theme.textSecondary)

            // `.firstTextBaseline` here is DELIBERATE and is not the rule 31
            // mistake it looks like. LeafGlyph is a Shape with no baseline, so
            // SwiftUI aligns its bottom edge, which is exactly where the leaf's
            // own `.bottomLeading` unfurl anchor wants to be: it sprouts from the
            // baseline of the number. Changing this to `.bottom` detaches it.
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                RollingEuro(value: b.netMonthly * factor, color: Theme.accent, fontSize: 44)
                UnfurlingLeaf(trigger: b.netMonthly * factor, size: leafSize)
            }
            .padding(.top, 2)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(s.grossWord)
                    .appFont(13)
                    .foregroundStyle(Theme.textFaint)
                // No period suffix: the label above already named it, and the
                // gross is the same period by construction.
                Text(eur(b.grossMonthly * factor))
                    .appFont(20, weight: .medium)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // One element, with an explicit label rather than `.combine`: combined,
        // VoiceOver reads four fragments and speaks "(x14)" as punctuation.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            s.heroVoice(net: eur(b.netMonthly * factor),
                        gross: eur(b.grossMonthly * factor),
                        per: s.periodVoice(period.modeIndex))
        )
    }

    /// 18 points beside a 44 point figure keeps the ratio the 13pt leaf had
    /// beside the old 30pt one, and it is scaled on the FIGURE's curve rather
    /// than its own. See the note in `UnfurlingLeaf`.
    private var leafSize: CGFloat { 18 * Theme.scaled(44, typeSize) / 44 }

    /// What the figure above takes for granted.
    ///
    /// The caption is the only thing that says what the 44pt number IS, and the
    /// ajudas line is a pay figure rather than detail: without it the net shown
    /// here understates what actually reaches the reader. At an accessibility
    /// size the Portuguese ajudas sentence runs to three or four lines right
    /// under the figures, and a calm Home that understated somebody's pay would
    /// be the worse trade.
    @ViewBuilder
    private var heroFootnotes: some View {
        // A short note on what the 12x / 14x monthly view means. Nil for annual.
        if let cap = s.resultCaption(period.modeIndex) {
            Text(cap)
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
        // Net above is from the salary alone. Ajudas de custo show as their own
        // line, so it is always clear which net comes from gross and which comes
        // on top.
        if b.ajudasMonthly > 0 {
            // `pocket(in:)` since v1.5, shared with the offer screen so its
            // "now" cannot drift from this line.
            Text(s.heroAjudas(eur(b.allowance(in: period)), total: eur(b.pocket(in: period))))
                .appFont(12)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
    }

    /// "Update my salary", on the figure it changes.
    ///
    /// It opens a fresh choice every time: read it off a payslip, which checks
    /// the payslip on the way, or type it. The figure itself used to be this
    /// button with a pencil for a hint; a bubble that says what it does is
    /// findable, and it leaves the number undecorated.
    ///
    /// A capsule hugging its text rather than a full-width row, so it reads as
    /// belonging to the figure above it and not as the first of the rows below.
    private var updateBubble: some View {
        Button { store.path = [.payslipUpdate] } label: {
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .appFont(12, weight: .semibold)
                    .accessibilityHidden(true)
                Text(s.updateSalaryTitle)
                    .appFont(13, weight: .medium)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.accentSoft, in: Capsule())
            .overlay(Capsule().stroke(Theme.accentBorder, lineWidth: 1))
            // Apple's 44 point minimum, without drawing a bigger capsule.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(s.heroEditHint)
    }

    private var periodPicker: some View {
        SegmentedPicker(options: ResultPeriod.allCases, selection: $period) {
            $0.label(s)
        }
    }

    // MARK: The ways in

    /// One row per feature, full width, in the order the questions arrive.
    ///
    /// `SignalRow`, for the reason rule 29 gives: one row, fixed once, and it
    /// already reflows past an accessibility text size and scales its glyph box.
    /// No figures on any row, even ones that could show one: a row that names
    /// no number can never disagree with the screen it opens.
    ///
    /// A tap REPLACES the path rather than appending to it. Home is the root, so
    /// the path is empty whenever a row can be tapped, and replacing means a
    /// double tap cannot push the same screen twice.
    private var hubRows: some View {
        VStack(spacing: 8) {
            ForEach(HubFeature.allCases) { feature in
                Button { store.path = [feature.route] } label: {
                    SignalRow(icon: feature.glyph,
                              iconTint: Theme.accent,
                              title: feature.title(s, offerKept: store.offer != nil),
                              subtitle: feature.subtitle(s, offerKept: store.offer != nil)) {
                        rowTrailing(locked: isLocked(feature))
                    }
                }
            }
        }
    }

    /// Only ever true in a paid build. In the free one `isSupporter` is forced
    /// true, so no row is locked and Home looks the same for everybody.
    private func isLocked(_ feature: HubFeature) -> Bool {
        feature.tier == .supporter && !supporter.isSupporter
    }

    /// A chevron, or a lock on a row the support payment covers.
    ///
    /// Past an accessibility text size `SignalRow` gives the trailing view a
    /// line of its own, and a chevron alone on a line is a third line per row
    /// saying nothing; the row is a button either way. The lock stays, because
    /// it says something, and it says it to VoiceOver too: the row's button
    /// reads its title, its line and then this, so a locked row is never
    /// announced as an ordinary one.
    @ViewBuilder
    private func rowTrailing(locked: Bool) -> some View {
        if locked {
            Image(systemName: "lock.fill")
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
                .accessibilityLabel(s.hubLockedVoice)
        } else if !typeSize.isAccessibilitySize {
            Image(systemName: "chevron.right")
                .appFont(12)
                .foregroundStyle(Theme.textFaint)
                .accessibilityHidden(true)
        }
    }

    /// v1.2b: how complete the profile is, said on the screen people actually
    /// open. Below the rows, because the rows are what Home is for; it sharpens
    /// what three of them show, and it disappears at ten of ten.
    @ViewBuilder
    private var profileNudge: some View {
        if store.profileFilledCount < store.signalTotal {
            ProfileNudgeCard { store.path = [.profile] }
                .padding(.top, 16)
        }
    }

    /// v1.2a: WHY HOME DRAWS ITS OWN STATUS-BAR SCRIM.
    ///
    /// Home has no navigation bar, because it wants no title: the wordmark is its
    /// header. The cost only shows once you scroll, and it is ugly. Content
    /// passes straight under the clock and the battery, so "Salario bruto  2400
    /// EUR" reads through "00:39". `scrollEdgeEffectStyle(.soft, for: .top)` is
    /// the iOS 26 API for exactly this, and it does nothing without a bar to
    /// draw it.
    ///
    /// So: a scrim in the page's own colour, which is invisible where there is
    /// nothing under it and hides what scrolls beneath it. It never takes a
    /// touch, and the fade means content dissolves rather than meeting a line.
    /// It was on the tab bar's `TabView` until the hub, which also laid it over
    /// Profile's and the offer's navigation bars; on Home alone, it is only
    /// where there is no bar to do the job.
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
