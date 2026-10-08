import SwiftUI

/// v0.9: bonus, commission and prémios over a year.
///
/// Stored apart from the salary and deliberately kept out of the monthly tax
/// estimate. Withholding on non-monthly pay follows its own rules, and the 2026
/// tables in TaxEngine are verified for regular salary. Showing an approximate
/// number here would quietly make an otherwise correct engine wrong.
///
/// "I don't get any" writes a real zero rather than leaving the field nil, so a
/// deliberate no can be told apart from a question never answered.
struct VariablePaySheet: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @FocusState private var focused: Bool

    private var s: Strings { store.s }

    private var parsed: Double { typedEuros(text) ?? 0 }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }

            // Scrolls, and can be pulled up to full height: at an
            // accessibility size the two paragraphs alone outgrow the medium
            // detent, and with a fixed column the Ok and "I don't get any"
            // buttons sat below the sheet where nobody could reach them. Two
            // detents, because one would make the drag rubber-band (rule 26).
            ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 34, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                Text(s.variableSheetTitle)
                    .appFont(18, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 14)

                Text(s.enrichWhy("variablePay"))
                    .appFont(11.5)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                amountBlock.padding(.top, 20)

                Text(s.variableTaxNote)
                    .appFont(10.5)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)

                Button {
                    store.variableAnnual = parsed
                    dismissKeyboard()
                    dismiss()
                } label: {
                    Text(s.okButton)
                        .appFont(16, weight: .semibold)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.top, 18)

                Button {
                    store.variableAnnual = 0
                    dismissKeyboard()
                    dismiss()
                } label: {
                    Text(s.variableNone)
                        .appFont(13)
                        .foregroundStyle(Theme.textSecondary)
                        .underline()
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            if let existing = store.variableAnnual, existing > 0 {
                text = fieldDigits(existing.rounded(.down))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }

    /// Pulled out of `body` so the enclosing ViewBuilder stays under its
    /// ten-child limit.
    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(s.variableFieldLabel)
                .appFont(12)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 6) {
                Text("€")
                    .appFont(26, weight: .light)
                    .foregroundStyle(Theme.textSecondary)
                TextField("0", text: $text)
                    .appFont(32, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                    .keyboardType(.decimalPad)
                    .focused($focused)
            }
            .padding(.top, 4)

            Rectangle()
                .fill(Theme.cardBorder)
                .frame(height: 1)
                .padding(.top, 8)

            if parsed > 0 {
                Text(s.variableYearly(eur(parsed)))
                    .appFont(12)
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 8)
            }
        }
    }
}
