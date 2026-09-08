import SwiftUI

/// v1.1: "this is what we read", shown only when something needs the reader.
///
/// A PDF that carried its own text, read cleanly and agreed with itself skips
/// this entirely: every figure came from the file rather than from a
/// recogniser's opinion of it, and asking somebody to check figures their own
/// file supplied is ceremony. Anything recognised from pixels stops here.
///
/// Only the uncertain figures are editable. The certain ones are shown because
/// the reader should see what the app thinks it read, and are not editable
/// because inviting corrections to figures we are sure of is inviting typos
/// into the one place they would do damage.
struct PayslipReviewStep: View {
    // Held because this view draws with Theme.accent, which is a computed
    // static SwiftUI cannot observe. See SalarySeedApp.
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject var model: PayslipCheckModel
    let workings: PayslipCheckModel.Workings
    let onConfirm: () -> Void

    @State private var drafts: [Int: String] = [:]

    private var s: Strings { store.s }
    private var lines: [PayslipClassifiedLine] { model.reviewable(workings) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(workings.reading.source == .ocr
                         ? s.payslipReviewSub : s.payslipReviewSubUnclear)
                        .appFont(13)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    SectionLabel(s.payslipReviewTitle)
                        .padding(.top, 4)

                    ForEach(lines, id: \.lineIndex) { line in
                        row(line)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 0) {
                Rectangle().fill(Theme.cardBorder).frame(height: 1)
                PrimaryButton(title: s.payslipReviewConfirm) {
                    dismissKeyboard()
                    onConfirm()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .onAppear {
            for line in lines where drafts[line.lineIndex] == nil {
                drafts[line.lineIndex] = line.cents.map { PayslipNumber.format(cents: $0) } ?? ""
            }
        }
    }

    @ViewBuilder
    private func row(_ line: PayslipClassifiedLine) -> some View {
        let uncertain = model.isUncertain(line, in: workings)
        VStack(alignment: .leading, spacing: 6) {
            // The name and the figure stop fitting together well before the
            // accessibility sizes, so they become two lines rather than
            // shrinking.
            //
            // v1.1a: this used to test `isAccessibilitySize`, which is false
            // for xLarge, xxLarge and xxxLarge. In that band a two-line concept
            // name still had to share a row with a 96 point minimum text field
            // inside 32 points of padding. `.large` and `.xLarge` are unchanged,
            // so the default look is untouched, which is the whole promise of
            // going through UIFontMetrics.
            if typeSize >= .xxLarge {
                VStack(alignment: .leading, spacing: 6) {
                    names(line)
                    value(line, uncertain: uncertain)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    names(line)
                    Spacer(minLength: 8)
                    value(line, uncertain: uncertain)
                }
            }
            if line.provenance == .disputed {
                Text(s.payslipReviewDisputed)
                    .appFont(11)
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(uncertain ? Theme.dangerBorder : Theme.cardBorder, lineWidth: 1))
    }

    private func names(_ line: PayslipClassifiedLine) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(line.concept.map { s.payslipConceptName($0) } ?? "")
                .appFont(14, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !line.rawLabel.isEmpty {
                // What the payslip itself calls it, so the reader can find the
                // line on their own paper.
                Text(line.rawLabel)
                    .appFont(11)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func value(_ line: PayslipClassifiedLine, uncertain: Bool) -> some View {
        if uncertain {
            TextField("", text: binding(for: line.lineIndex))
                .appFont(15, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(typeSize >= .xxLarge ? .leading : .trailing)
                .keyboardType(.decimalPad)
                .frame(minWidth: 96)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.dangerBorder, lineWidth: 1))
                .accessibilityLabel(fieldLabel(line))
                .accessibilityValue(drafts[line.lineIndex] ?? "")
                .accessibilityHint(s.payslipReviewA11yHint)
        } else {
            Text(line.cents.map { PayslipNumber.format(cents: $0) } ?? "")
                .appFont(15, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    /// Writes straight through to the model's edit map, so a correction is a
    /// correction to the reading and gets classified again rather than being
    /// patched onto a verdict that has already been decided.
    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { drafts[index] ?? "" },
            set: { text in
                drafts[index] = text
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                // Three cases, and the third used to be silently the second.
                //
                // An empty field means "we could not read this, skip the checks
                // that need it", and that is a deliberate act worth honouring.
                // A figure that parses replaces the amount. A figure that does
                // NOT parse is half-typed: "1.2" on the way to "1.234,56", or a
                // typo. `PayslipNumber.cents` returns nil for both that and an
                // empty string, and `applying` reads nil as "remove this
                // amount", so v1.1 deleted the figure the moment the reader
                // typed a character the parser did not like yet. Leaving the
                // last good edit in place is the only safe reading of a
                // half-typed number.
                if trimmed.isEmpty {
                    model.edits[index] = Int?.none
                } else if let cents = PayslipNumber.cents(from: trimmed) {
                    model.edits[index] = cents
                }
            })
    }

    /// Never empty. A control with an empty accessibility label is not an
    /// unlabelled control, it is a control VoiceOver reads as nothing at all,
    /// which is worse than the fallback it replaces.
    private func fieldLabel(_ line: PayslipClassifiedLine) -> String {
        if let concept = line.concept { return s.payslipConceptName(concept) }
        return line.rawLabel.isEmpty ? s.payslipReviewA11yUnnamed : line.rawLabel
    }
}
