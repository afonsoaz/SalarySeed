import SwiftUI

// The two ways into the payslip reader from Home, and the wiring both need.
//
// THEY LIVE HERE, IN Features/Home, AND NOT IN Features/Payslip, because both
// have to write: `store.adopt` when the reader keeps a figure, and `store.path`
// to send them back to Home. `Features/Payslip/` reads the store and never
// writes it, and the greps that say so (`store\.[a-zA-Z]* *=`, `store\.adopt`
// and `store\.path`) have to stay empty there. Everything that moves the
// reader or changes their salary is a closure handed in from this file.

extension SalaryStore {
    /// What the payslip checks know about the reader. Built in one place, so
    /// "Check my payslip" and "Update my salary" can never check the same
    /// payslip against two different households.
    var payslipContext: PayslipContext {
        PayslipContext(region: taxRegion,
                       months: schedule.months,
                       marital: maritalSituation,
                       dependents: dependents,
                       jovemExemption: irsJovemExemption)
    }
}

/// "Update my salary": four ways to a new figure, always fresh.
///
/// The bubble on Home's figure opens this. It never shows an older verdict,
/// even though Home keeps the last reading until the app quits: tapping
/// "Update my salary" a week after checking a payslip should offer the choice,
/// not last week's result. Picking a payslip reads it into Home's one model,
/// replacing whatever was there, and pushes the checker on top of this screen,
/// so back from the verdict comes here and back again goes to Home.
struct SalaryUpdateScreen: View {
    @EnvironmentObject private var store: SalaryStore
    /// Home's own. Only `load` is called on it here, so it is a plain
    /// reference rather than observed: this screen draws nothing from it.
    let payslip: PayslipCheckModel

    @State private var showEditor = false

    private var s: Strings { store.s }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                // The same header the checker draws under "Update my salary",
                // so the hand-over reads as one screen continuing.
                PayslipHeader(title: s.updateSalaryTitle)
                PayslipSourceStep(
                    lead: s.updateSalaryLead,
                    onFile: { url in
                        hand { payslip.load(url: url, context: store.payslipContext) }
                    },
                    onImage: { data in
                        hand { payslip.load(imageData: data, context: store.payslipContext) }
                    },
                    onTypeInstead: { showEditor = true })
            }
            // Rule 34: the header is furniture and may not move, whatever the
            // content below it turns out to be.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .salaryEditor(isPresented: $showEditor) { store.path = [] }
    }

    /// Reads the payslip and pushes the checker, if the reader is still here.
    ///
    /// THE GUARD IS NOT DEFENSIVE NOISE. A photo can take seconds to load from
    /// iCloud, and a reader can leave meanwhile. `PayslipSourceStep` now cancels
    /// that load when it disappears, which is the real fix; this check is the
    /// second line, so a hand-over that still arrives late can neither replace
    /// the reading Home keeps nor push a screen nobody asked for.
    ///
    /// The push waits ONE TURN OF THE MAIN QUEUE, and that is all it waits: it
    /// is not a wait for a picker's dismissal to finish. The file importer
    /// hands over after it has closed, and the push has been driven on the
    /// simulator after a file and after a photo and was clean both times. If a
    /// dropped or janky push ever shows up after picking something, look here
    /// first. It checks again after the turn, because the reader may have left.
    private func hand(_ load: () -> Void) {
        guard store.path == [.payslipUpdate] else { return }
        load()
        DispatchQueue.main.async {
            guard store.path == [.payslipUpdate] else { return }
            store.path.append(.payslipCheck(.update))
        }
    }
}

/// The checker, opened from Home for one of two reasons.
struct PayslipCheckScreen: View {
    @EnvironmentObject private var store: SalaryStore
    @ObservedObject var payslip: PayslipCheckModel
    let intent: PayslipIntent

    @State private var showEditor = false

    var body: some View {
        PayslipCheckFlow(
            model: payslip,
            chrome: .check(intent),
            context: store.payslipContext,
            onAccept: { store.adopt($0) },
            onFinished: { store.path = [] },
            onTypeInstead: intent == .update ? { showEditor = true } : nil,
            onChooseAgain: intent == .update ? { store.path = [.payslipUpdate] } : nil)
            .salaryEditor(isPresented: $showEditor) { store.path = [] }
    }
}

extension View {
    /// The salary editor, and what to do once the reader has SAVED in it.
    ///
    /// One modifier for both payslip screens, so they cannot differ in when they
    /// move the reader on. `onSaved` runs from the sheet's `onDismiss`, after
    /// the sheet has gone, because changing the navigation stack under a sheet
    /// that is still on its way down is the moment SwiftUI handles worst. A
    /// sheet swiped away without saving does nothing.
    func salaryEditor(isPresented: Binding<Bool>, onSaved: @escaping () -> Void) -> some View {
        modifier(SalaryEditorPresenter(isPresented: isPresented, onSaved: onSaved))
    }
}

private struct SalaryEditorPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let onSaved: () -> Void
    @State private var saved = false

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: {
            guard saved else { return }
            saved = false
            onSaved()
        }) {
            SalaryEditorView(onSaved: { saved = true })
        }
    }
}
