import SwiftUI

/// Quick edit of the core inputs from anywhere.
struct SalaryEditorView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var kind: AmountKind = .gross
    @State private var schedule: PaySchedule = .fourteen

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Text("Your salary")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 24)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("€").font(.system(size: 24)).foregroundStyle(Theme.textSecondary)
                    TextField("Monthly amount", text: $amountText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text("/mo").font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                }
                .padding(.bottom, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.accent).frame(height: 2) }

                SegmentedPicker(options: AmountKind.allCases, selection: $kind) { $0.label }
                SegmentedPicker(options: PaySchedule.allCases, selection: $schedule) { $0.label }

                Spacer()
                PrimaryButton(title: "Update") {
                    if let v = Double(amountText), v > 0 { store.amount = v }
                    store.kind = kind
                    store.schedule = schedule
                    dismiss()
                }
            }
            .padding(24)
        }
        .onAppear {
            amountText = String(Int(store.amount))
            kind = store.kind
            schedule = store.schedule
        }
    }
}
