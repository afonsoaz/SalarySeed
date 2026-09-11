import SwiftUI

/// v1.1: the payslip checker, start to finish.
///
/// Presented as a `fullScreenCover` from Home, which is the app's first. A
/// sheet would have been the house pattern, but this is a flow with its own
/// steps rather than one question, and a half-height sheet with a file picker
/// and a verdict inside it reads as two screens fighting for the same space.
///
/// The model is a `@StateObject` created here, so it and the picture it holds
/// die with the cover. Nothing in this feature reaches `SalaryStore` and
/// nothing reaches `UserDefaults`.
struct PayslipCheckFlow: View {
    // Held for `s`, and because everything below draws with `Theme.accent`,
    // which is a computed static SwiftUI cannot observe. See SalarySeedApp.
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @StateObject private var model = PayslipCheckModel()

    /// What to do when the reader keeps the figure the payslip proposed.
    ///
    /// A closure, and not a write inside this file, so the rule that the payslip
    /// feature reads the store and never writes to it stays literally true:
    /// `grep -rn "store\." SalarySeed/Features/Payslip` returns only reads.
    /// `nil` means nobody is offering to keep anything, and the results screen
    /// then asks nothing.
    var onAccept: ((PayslipSalary.GrossProposal) -> Void)?

    private var s: Strings { store.s }

    /// What the app knows about the reader, read once on the way in.
    private var context: PayslipContext {
        PayslipContext(region: store.taxRegion,
                       months: store.schedule.months,
                       marital: store.maritalSituation,
                       dependents: store.dependents,
                       jovemExemption: store.irsJovemExemption)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                content
            }
        }
        .onDisappear { model.discard() }
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
                    HStack {
                        Spacer()
                        closeButton
                    }
                    title
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    title
                    Spacer(minLength: 12)
                    closeButton
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var title: some View {
        Text(s.payslipTitle)
            .appFont(20, weight: .medium)
            .foregroundStyle(Theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .appFont(14, weight: .semibold)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: max(44, Theme.scaled(34, typeSize)),
                       height: max(44, Theme.scaled(34, typeSize)))
                .background(Theme.card, in: Circle())
        }
        .accessibilityLabel(s.closeButton)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .source:
            PayslipSourceStep(
                onFile: { model.load(url: $0, context: context) },
                onImage: { model.load(imageData: $0, context: context) })
        case .reading:
            PayslipReadingStep()
        case .review(let workings):
            PayslipReviewStep(model: model, workings: workings,
                              onConfirm: { model.confirmReview(context: context) })
        case .results(let verdict, let workings):
            PayslipResultsView(verdict: verdict, workings: workings, onAccept: onAccept)
        case .unreadable(let why):
            PayslipUnreadableView(why: why, onRetry: { model.restart() })
        }
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
