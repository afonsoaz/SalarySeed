import SwiftUI

/// Quick edit of the core inputs from anywhere.
/// v0.5: also takes ajudas de custo, clearly marked as outside the gross world.
/// v0.8: the salary can be typed monthly (per payment) or as a yearly total.
struct SalaryEditorView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var ajudasText = ""
    @State private var kind: AmountKind = .gross
    @State private var schedule: PaySchedule = .fourteen
    @State private var inputPeriod: SalaryInputPeriod = .monthly

    private var s: Strings { store.s }

    /// User taps to switch monthly <-> yearly. Converting only on this binding's
    /// setter (not on the raw @State) keeps the onAppear setup from double-counting.
    private var periodBinding: Binding<SalaryInputPeriod> {
        Binding(
            get: { inputPeriod },
            set: { newValue in
                if newValue != inputPeriod { convertAmount(to: newValue) }
                inputPeriod = newValue
            }
        )
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(s.editorTitle)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 24)

                    // Monthly vs yearly: how the number below is read.
                    VStack(alignment: .leading, spacing: 8) {
                        Text(s.editorPeriodLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        SegmentedPicker(options: SalaryInputPeriod.allCases, selection: periodBinding) {
                            $0.label(pt: s.pt)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("€").font(.system(size: 24)).foregroundStyle(Theme.textSecondary)
                        TextField(s.editorPlaceholder, text: $amountText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(inputPeriod == .yearly ? s.perYearSuffix : s.perMonthSuffix)
                            .font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.bottom, 10)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.accent).frame(height: 2) }

                    if inputPeriod == .yearly {
                        Text(s.editorYearlyNote(Int(schedule.months)))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(2)
                            .padding(.top, -12)
                    }

                    SegmentedPicker(options: AmountKind.allCases, selection: $kind) { $0.label(pt: s.pt) }

                    VStack(alignment: .leading, spacing: 6) {
                        SegmentedPicker(options: PaySchedule.allCases, selection: $schedule) { $0.label(pt: s.pt) }
                        Text(s.monthsHint)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(2)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.editorAjudasLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("€").font(.system(size: 18)).foregroundStyle(Theme.textSecondary)
                            TextField("0", text: $ajudasText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Text(s.perMonthSuffix).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.bottom, 8)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.accent).frame(height: 2) }
                        Text(s.editorAjudasNote)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(2)
                    }
                    .padding(.top, 4)

                    PrimaryButton(title: s.updateButton) {
                        if let v = Double(amountText), v > 0 {
                            store.amount = inputPeriod == .yearly ? v / schedule.months : v
                        }
                        store.ajudasMonthly = max(0, Double(ajudasText) ?? 0)
                        store.kind = kind
                        store.schedule = schedule
                        store.inputYearly = inputPeriod == .yearly
                        dismiss()
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            kind = store.kind
            schedule = store.schedule
            inputPeriod = store.inputYearly ? .yearly : .monthly
            let shown = store.inputYearly ? store.amount * store.schedule.months : store.amount
            amountText = String(Int(shown.rounded()))
            ajudasText = store.ajudasMonthly > 0 ? String(Int(store.ajudasMonthly)) : ""
        }
    }

    /// Convert the number in the field when the user flips monthly <-> yearly,
    /// so the amount they see keeps meaning the same pay.
    private func convertAmount(to period: SalaryInputPeriod) {
        guard let v = Double(amountText), v > 0 else { return }
        let months = schedule.months
        switch period {
        case .yearly:  amountText = String(Int((v * months).rounded()))   // was monthly
        case .monthly: amountText = String(Int((v / months).rounded()))   // was yearly
        }
    }
}
