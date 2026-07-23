import SwiftUI

/// Quick edit of the core inputs from anywhere.
/// v0.5: also takes ajudas de custo, clearly marked as outside the gross world.
struct SalaryEditorView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var ajudasText = ""
    @State private var kind: AmountKind = .gross
    @State private var schedule: PaySchedule = .fourteen

    private var s: Strings { store.s }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(s.editorTitle)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 24)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("€").font(.system(size: 24)).foregroundStyle(Theme.textSecondary)
                        TextField(s.editorPlaceholder, text: $amountText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(s.perMonthSuffix).font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.bottom, 10)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.accent).frame(height: 2) }

                    SegmentedPicker(options: AmountKind.allCases, selection: $kind) { $0.label(pt: s.pt) }
                    SegmentedPicker(options: PaySchedule.allCases, selection: $schedule) { $0.label(pt: s.pt) }

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
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.danger.opacity(0.7)).frame(height: 2) }
                        Text(s.editorAjudasNote)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(2)
                    }
                    .padding(.top, 4)

                    PrimaryButton(title: s.updateButton) {
                        if let v = Double(amountText), v > 0 { store.amount = v }
                        store.ajudasMonthly = max(0, Double(ajudasText) ?? 0)
                        store.kind = kind
                        store.schedule = schedule
                        dismiss()
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
        }
        .onAppear {
            amountText = String(Int(store.amount))
            ajudasText = store.ajudasMonthly > 0 ? String(Int(store.ajudasMonthly)) : ""
            kind = store.kind
            schedule = store.schedule
        }
    }
}
