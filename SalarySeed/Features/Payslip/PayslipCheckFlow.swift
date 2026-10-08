import SwiftUI

/// Why the checker was opened, when Home opens it.
///
/// A ROUTE PARAMETER AND NOTHING ELSE. It lives in `HubRoute.payslipCheck` for
/// as long as the screen does and is never written anywhere: a "this salary
/// came from a payslip" flag on the store would be the one-bit payslip history
/// CLAUDE.md forbids, and it is exactly the shape this would take if it leaked.
enum PayslipIntent: Hashable {
    /// "Check payslip". The verdict is the point; the offer to keep the
    /// figure comes after it, and the reader stays on the verdict afterwards.
    case check
    /// "Update my salary". The reader came for the number. The verdict still
    /// comes first, and answering the question about the figure takes them
    /// back to Home, where the number is.
    case update
}

/// Where the checker lives, which decides what its chrome means.
///
/// v1.2 made it a tab, and it had been a full-screen cover. Onboarding still
/// presents the cover, because there it genuinely is a detour off a step that
/// is asking for a number. The hub made the tab a screen Home opens, for one
/// of two reasons, and the reason changes the title, what "done" does, and
/// whether the reader is offered to type the number instead.
enum PayslipChrome: Equatable {
    case check(PayslipIntent)
    case cover
}

/// v1.1: the payslip checker, start to finish.
///
/// The steps are a state machine on `PayslipCheckModel.phase` rather than a
/// navigation stack, because every transition here is a replacement rather than
/// a push: there is no back from a verdict to the file picker that means
/// anything other than starting again.
///
/// THE MODEL IS NOT OWNED HERE. Home owns the one the checker uses, and
/// `PayslipCheckCover` owns onboarding's, and which of them is holding it is
/// exactly the difference between a reading that survives leaving the checker
/// and one that dies with a dismissed cover. See `PayslipCheckModel` for what
/// that means for the promise on screen.
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

    /// Closes the cover. `nil` when Home opened the checker.
    var onClose: (() -> Void)?

    /// "Update my salary" only: the way back to Home once the reader has
    /// answered, or is done. A closure for the same reason `onAccept` is one:
    /// moving the reader means writing the navigation path, which lives on the
    /// store, and this feature never writes the store.
    var onFinished: (() -> Void)?

    /// "Update my salary" only: open the salary editor instead, when the
    /// payslip could not be read or could not give a figure.
    var onTypeInstead: (() -> Void)?

    /// "Update my salary" only: back to the chooser, for "Try again" on a
    /// payslip that could not be read. The chooser is right underneath, so
    /// trying again there is one step back rather than a second chooser drawn
    /// inside this screen.
    var onChooseAgain: (() -> Void)?

    private var isUpdate: Bool { chrome == .check(.update) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                content
            }
            // v1.4a: the header is pinned, whatever `content` turns out to be.
            //
            // All five phases happen to be flexible today, four ScrollViews and
            // one column with Spacers top and bottom, so this changes nothing
            // now. It is here because GrowView had exactly this shape and one
            // inflexible state, and the whole title row slid to the middle of
            // the screen. A sixth phase should not be able to do that.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    /// The checker carries the same accent eyebrow as every other place in the
    /// app (`taxSeed`, `compareSeed`, `growSeed`). The cover does not: that
    /// is a detour off an onboarding step, not a place. Nor does "Update my
    /// salary", which is a way to change one number and looks exactly like the
    /// chooser it came from.
    private var header: some View {
        PayslipHeader(eyebrow: chrome == .check(.check) ? "payslipSeed" : nil,
                      title: isUpdate ? s.updateSalaryTitle : s.payslipTitle,
                      titleSize: chrome == .cover ? 20 : 22,
                      topPadding: chrome == .cover ? 18 : 8,
                      hasTrailing: hasTrailingButton) {
            trailingButton
        }
    }

    /// An X in the cover. In the checker, a way back to the file picker, shown
    /// only once there is something to go back from: on the source step it would
    /// be a button that starts again from where you already are. Nothing under
    /// "Update my salary", where back already means "choose again".
    @ViewBuilder
    private var trailingButton: some View {
        switch chrome {
        case .cover:
            circleButton(icon: "xmark", label: s.closeButton) { onClose?() }
        case .check(.check):
            // No way into Profile here: the hub leaves Profile to Home.
            if !isAtStart {
                circleButton(icon: "arrow.counterclockwise",
                             label: s.payslipCheckAnother) { model.restart() }
            }
        case .check(.update):
            EmptyView()
        }
    }

    /// Ends the run. In the checker that means going back to the file picker,
    /// which is the only "done" a screen with nothing to close can offer; under
    /// "Update my salary" it means going back to Home; in the cover it closes.
    private func onDone() {
        switch chrome {
        case .check(.check): model.restart()
        case .check(.update): onFinished?()
        case .cover: onClose?()
        }
    }

    private var isAtStart: Bool {
        if case .source = model.phase { return true }
        return false
    }

    private var hasTrailingButton: Bool {
        switch chrome {
        case .cover: return true
        case .check(.check): return !isAtStart
        case .check(.update): return false
        }
    }

    private var doneTitle: String {
        switch chrome {
        case .check(.check): return s.payslipCheckAnother
        case .check(.update): return s.updateSalaryBack
        case .cover: return s.closeButton
        }
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
                showsWhatWeCheck: chrome == .check(.check),
                onFile: { model.load(url: $0, context: context) },
                onImage: { model.load(imageData: $0, context: context) },
                onTypeInstead: isUpdate ? onTypeInstead : nil)
        case .reading:
            PayslipReadingStep()
        case .review(let workings):
            PayslipReviewStep(model: model, workings: workings,
                              onConfirm: { model.confirmReview(context: context) })
        case .results(_, let workings):
            // Checked again against the answers as they are now, not as they
            // were when the payslip was read. Home keeps the reading for the
            // whole session and the tax answers are one screen away on Tax, so
            // a household or município changed in between used to leave a
            // verdict judged on the old one under a footer naming the new one.
            // The facts already carry the review's corrections, and the check
            // is pure, so with unchanged answers the verdict is identical.
            PayslipResultsView(
                verdict: PayslipReconciler.check(workings.facts, context: context),
                workings: workings,
                onAccept: onAccept, hasProfile: context != nil,
                ask: model.salaryAsk,
                onAnswerAsk: { adopted in
                    model.answerSalaryAsk(adopted: adopted)
                    // Either answer ends an update: the reader came for the
                    // number, and now it is settled one way or the other.
                    if isUpdate { onFinished?() }
                },
                doneTitle: doneTitle,
                onDone: onDone,
                onTypeInstead: isUpdate ? onTypeInstead : nil)
        case .unreadable(let why):
            PayslipUnreadableView(
                why: why,
                onRetry: {
                    model.restart()
                    if isUpdate { onChooseAgain?() }
                },
                onGiveUp: chrome == .cover && context == nil ? onClose
                    : (isUpdate ? onTypeInstead : nil))
        }
    }
}

/// The checker as a full-screen cover, which is what onboarding still uses.
///
/// The model is created here and dies with the cover, so on that route the
/// original promise holds unchanged: dismiss it and the file, the lines and
/// everything read from them are gone.
struct PayslipCheckCover: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: PayslipCheckModel

    let context: PayslipContext?
    /// v1.4: what the reader already handed over on the way in.
    ///
    /// Onboarding's step 1 is now the choice of file, camera or typing, so by
    /// the time this cover appears the question has been answered. Opening on
    /// `PayslipSourceStep` would be the same question asked twice. `nil` keeps
    /// the old behaviour, where the cover opens on its own picker.
    let starting: PayslipInput?
    var onAccept: ((PayslipSalary.GrossProposal) -> Void)?

    init(context: PayslipContext?,
         starting: PayslipInput? = nil,
         onAccept: ((PayslipSalary.GrossProposal) -> Void)? = nil) {
        self.context = context
        self.starting = starting
        self.onAccept = onAccept
        _model = StateObject(wrappedValue: PayslipCheckModel(opensReading: starting != nil))
    }

    var body: some View {
        PayslipCheckFlow(model: model, chrome: .cover,
                         context: context, onAccept: onAccept,
                         onClose: { dismiss() })
            // `.task` and not `.onChange`: rule 11. `starting` is a value this
            // view already has on its first render, so no onChange would fire.
            .task {
                if let starting { model.load(starting, context: context) }
            }
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
