import SwiftUI

/// Where the checker lives, which decides what its chrome means.
///
/// v1.2: it is a tab now, and it was a full-screen cover. Onboarding still
/// presents the cover, because there it genuinely is a detour off a step that
/// is asking for a number. The two differ in three places and nowhere else: an
/// X that closes versus a button that starts again, "Close" versus "Check
/// another payslip" under the verdict, and whether the landing screen explains
/// what the checks are before asking for a file.
enum PayslipChrome {
    case tab
    case cover
}

/// v1.1: the payslip checker, start to finish.
///
/// The steps are a state machine on `PayslipCheckModel.phase` rather than a
/// navigation stack, because every transition here is a replacement rather than
/// a push: there is no back from a verdict to the file picker that means
/// anything other than starting again.
///
/// THE MODEL IS NOT OWNED HERE any more. `PayslipTabView` and
/// `PayslipCheckCover` each own one, and which of them is holding it is exactly
/// the difference between a reading that survives a tab switch and one that
/// dies with a dismissed cover. See `PayslipCheckModel` for what that changed
/// about the promise on screen.
struct PayslipCheckFlow: View {
    // Held for `s`, and because everything below draws with `Theme.accent`,
    // which is a computed static SwiftUI cannot observe. See SalarySeedApp.
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject var model: PayslipCheckModel

    let chrome: PayslipChrome

    private var s: Strings { store.s }

    /// What the app knows about the reader, or nothing at all.
    ///
    /// Passed in rather than read off the store here, because onboarding runs
    /// this flow BEFORE the reader has said where they live, whether they are
    /// married or how many dependants they have. Nil is not a shrug: five of the
    /// ten checks need none of that and still run, and the rest say
    /// `profileIncomplete` on the screen instead of quietly not happening.
    let context: PayslipContext?

    /// What to do when the reader keeps the figure the payslip proposed.
    ///
    /// A closure, and not a write inside this file, so the rule that the payslip
    /// feature reads the store and never writes to it stays literally true:
    /// both `grep -rn "store\.[a-zA-Z]* *=" SalarySeed/Features/Payslip` and
    /// `grep -rn "store\.adopt" SalarySeed/Features/Payslip` return nothing.
    /// (The word `adopted` does appear here, as the name of a case on
    /// `PayslipCheckModel.SalaryAsk`, which records that the reader said yes.
    /// Recording the answer is not making the write.) `nil` means nobody is
    /// offering to keep anything, and the results screen then asks nothing.
    var onAccept: ((PayslipSalary.GrossProposal) -> Void)?

    /// Closes the cover. `nil` in a tab, where there is nothing to close.
    var onClose: (() -> Void)?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                content
            }
        }
    }

    /// v1.1a: the header sits above all five steps, so anything it does badly
    /// it does five times.
    ///
    /// It used to be one row with a 20pt title and a fixed 34 by 34 circle. At
    /// an accessibility size the title wrapped to three or four lines beside an
    /// unmoved button, eating the vertical room every step below it needs, and
    /// the `xmark` grew straight out of its own background because the glyph
    /// scaled and the circle did not. The row now becomes two rows past the
    /// threshold, which is what `HomeView.topBar` does with the same problem,
    /// and the circle scales with the glyph inside it.
    ///
    /// The 34 also failed Apple's 44 point minimum tap target at the DEFAULT
    /// size, on the only way out of this screen.
    private var header: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    if hasTrailingButton {
                        HStack {
                            Spacer()
                            trailingButton
                        }
                    }
                    title
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    title
                    Spacer(minLength: 12)
                    trailingButton
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, chrome == .tab ? 8 : 18)
        .padding(.bottom, 10)
    }

    /// In the tab the title carries the same accent eyebrow every other tab has
    /// (`mapSeed`, `profileSeed`, `compareSeed`). In the cover it does not: that
    /// is a detour off an onboarding step, not a place.
    private var title: some View {
        VStack(alignment: .leading, spacing: 2) {
            if chrome == .tab {
                Text("payslipSeed")
                    .appFont(12)
                    .foregroundStyle(Theme.accent)
            }
            Text(s.payslipTitle)
                .appFont(chrome == .tab ? 22 : 20, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// An X in the cover. In the tab, a way back to the file picker, shown only
    /// once there is something to go back from: on the source step it would be
    /// a button that starts again from where you already are.
    @ViewBuilder
    private var trailingButton: some View {
        switch chrome {
        case .cover:
            circleButton(icon: "xmark", label: s.closeButton) { onClose?() }
        case .tab:
            if !isAtStart {
                circleButton(icon: "arrow.counterclockwise",
                             label: s.payslipCheckAnother) { model.restart() }
            }
        }
    }

    /// Ends the run. In the tab that means going back to the file picker,
    /// which is the only "done" a screen with no way out can offer. In the
    /// cover it closes.
    private func onDone() {
        switch chrome {
        case .tab: model.restart()
        case .cover: onClose?()
        }
    }

    private var isAtStart: Bool {
        if case .source = model.phase { return true }
        return false
    }

    /// Asked separately rather than by testing `trailingButton`, because a
    /// `some View` is never nil: an empty `@ViewBuilder` branch is a real view
    /// that draws nothing, and the accessibility-size layout needs to know
    /// whether to give it a row of its own.
    private var hasTrailingButton: Bool {
        chrome == .cover || !isAtStart
    }

    private func circleButton(icon: String, label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .appFont(14, weight: .semibold)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: max(44, Theme.scaled(34, typeSize)),
                       height: max(44, Theme.scaled(34, typeSize)))
                .background(Theme.card, in: Circle())
        }
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .source:
            PayslipSourceStep(
                showsWhatWeCheck: chrome == .tab,
                onFile: { model.load(url: $0, context: context) },
                onImage: { model.load(imageData: $0, context: context) })
        case .reading:
            PayslipReadingStep()
        case .review(let workings):
            PayslipReviewStep(model: model, workings: workings,
                              onConfirm: { model.confirmReview(context: context) })
        case .results(let verdict, let workings):
            PayslipResultsView(
                verdict: verdict, workings: workings,
                onAccept: onAccept, hasProfile: context != nil,
                ask: model.salaryAsk,
                onAnswerAsk: { model.answerSalaryAsk(adopted: $0) },
                doneTitle: chrome == .tab ? s.payslipCheckAnother : s.closeButton,
                onDone: onDone)
        case .unreadable(let why):
            PayslipUnreadableView(why: why, onRetry: { model.restart() },
                                  onGiveUp: chrome == .cover && context == nil ? onClose : nil)
        }
    }
}

/// The checker as a tab. Owns the model, so a verdict survives a trip to
/// another tab and back.
///
/// `context` and `onAccept` are handed in by `RootTabView` rather than built
/// here, for the same reason `HomeView` used to build them: `Features/Payslip/`
/// reads the store and never writes to it, and `SalaryStore.adopt` is a write.
struct PayslipTabView: View {
    @StateObject private var model = PayslipCheckModel()

    let context: PayslipContext
    var onAccept: (PayslipSalary.GrossProposal) -> Void

    var body: some View {
        PayslipCheckFlow(model: model, chrome: .tab,
                         context: context, onAccept: onAccept)
    }
}

/// The checker as a full-screen cover, which is what onboarding still uses.
///
/// The model is created here and dies with the cover, so on that route the
/// original promise holds unchanged: dismiss it and the file, the lines and
/// everything read from them are gone.
struct PayslipCheckCover: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PayslipCheckModel()

    let context: PayslipContext?
    var onAccept: ((PayslipSalary.GrossProposal) -> Void)?

    var body: some View {
        PayslipCheckFlow(model: model, chrome: .cover,
                         context: context, onAccept: onAccept,
                         onClose: { dismiss() })
            .onDisappear { model.discard() }
    }
}

/// The wait. Reuses the sprout rather than a spinner, because the app already
/// has something of its own to show while it thinks.
struct PayslipReadingStep: View {
    @EnvironmentObject private var store: SalaryStore

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            SproutView(stage: 3, size: 34, animatesIn: true, sways: true)
                .accessibilityHidden(true)
            Text(store.s.payslipReading)
                .appFont(14)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        // Without this a VoiceOver reader is told "reading your payslip" once
        // and then nothing, with no way to know the verdict has arrived.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
