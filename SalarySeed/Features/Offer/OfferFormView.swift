import SwiftUI

/// v1.5: the offer, as the reader types it.
///
/// Laid out like `SalaryEditorView`, because it asks the same questions about a
/// different salary: how the number is written, gross or net, and 12 or 14
/// payments. The last one is always asked and never guessed, because it moves
/// the monthly figure by a sixth.
///
/// Place and sector start as the reader's own, since most offers are in the
/// same city and the same line of work, and both stay one tap from changing.
/// The household never appears here at all: an offer changes the job, not the
/// person, and the subtitle says so.
///
/// It writes nothing. Compare hands an `OfferTerms` back to `OfferView`.
struct OfferFormView: View {
    @EnvironmentObject private var store: SalaryStore

    let starting: OfferTerms?
    let onCompare: (OfferTerms) -> Void
    let onCancel: (() -> Void)?

    @State private var amountText = ""
    @State private var kind: AmountKind = .gross
    @State private var schedule: PaySchedule = .fourteen
    @State private var inputPeriod: SalaryInputPeriod = .monthly
    @State private var ajudasText = ""
    @State private var bonusText = ""
    @State private var sector: Sector?
    @State private var concelhoID: String?
    @State private var showPlace = false
    @State private var loaded = false

    private var s: Strings { store.s }

    private var amountValue: Double? {
        guard let v = Self.euros(amountText), v > 0 else { return nil }
        return v
    }

    /// Converting only in this binding's setter, as the salary editor does, keeps
    /// the first load from converting a number that was already in the right unit.
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
                VStack(alignment: .leading, spacing: 22) {
                    header
                    amountBlock
                    SegmentedPicker(options: AmountKind.allCases, selection: $kind) { $0.label(pt: s.pt) }
                    VStack(alignment: .leading, spacing: 6) {
                        SegmentedPicker(options: PaySchedule.allCases, selection: $schedule) { $0.label(pt: s.pt) }
                        Text(s.monthsHint)
                            .appFont(11)
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    placeRow
                    sectorRow
                    euroField(label: s.editorAjudasLabel, text: $ajudasText, suffix: s.perMonthSuffix,
                              note: s.offerAllowanceNote, decimals: true)
                    euroField(label: s.offerBonusLabel, text: $bonusText, suffix: s.perYearSuffix,
                              note: s.offerBonusNote, decimals: false)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        // Rule 24: a pinned button is an inset, not a sibling under the scroll
        // view. v1.2 found the sibling under iOS 26's floating tab bar, winning
        // none of its taps; there is no tab bar now, and the inset is still the
        // shape the system understands for anything over the bottom edge.
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: s.offerCompareButton) { compare() }
                .opacity(amountValue == nil ? 0.4 : 1)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.background)
        }
        .sheet(isPresented: $showPlace) { OfferPlaceSheet(concelhoID: $concelhoID) }
        .onAppear(perform: load)
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("offerSeed")
                        .appFont(12)
                        .foregroundStyle(Theme.accent)
                    Text(s.offerFormTitle)
                        .appFont(22, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer(minLength: 8)
                if let onCancel {
                    Button(action: onCancel) {
                        Text(s.cancelButton)
                            .appFont(14)
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                    }
                }
            }
            Text(s.offerFormSub)
                .appFont(13)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(s.editorPeriodLabel)
                    .appFont(13, weight: .medium)
                    .foregroundStyle(Theme.textSecondary)
                SegmentedPicker(options: SalaryInputPeriod.allCases, selection: periodBinding) {
                    $0.label(pt: s.pt)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("€")
                    .appFont(24)
                    .foregroundStyle(Theme.textSecondary)
                TextField(inputPeriod == .yearly ? "30000" : "2000", text: $amountText)
                    .keyboardType(.numberPad)
                    .appFont(34, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                Text(inputPeriod == .yearly ? s.perYearSuffix : s.perMonthSuffix)
                    .appFont(14)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.accent).frame(height: 2) }
            if inputPeriod == .yearly {
                Text(s.offerYearlyNote(Int(schedule.months)))
                    .appFont(11)
                    .foregroundStyle(Theme.textSecondary)
            }
            if amountValue == nil {
                Text(s.offerAmountNeeded)
                    .appFont(12)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var placeText: String {
        guard let c = ConcelhoCatalog.concelho(concelhoID) else { return s.offerPlaceNone }
        return "\(c.name) · \(c.region.label)"
    }

    private var placeRow: some View {
        Button { showPlace = true } label: {
            SignalRow(icon: "mappin.and.ellipse", title: s.offerPlaceLabel, subtitle: placeText) {
                EditGlyph()
            }
        }
        .buttonStyle(.plain)
    }

    private var sectorRow: some View {
        Menu {
            Button(s.offerSectorNone) { sector = nil }
            ForEach(Sector.allCases) { option in
                Button(option.label(pt: s.pt)) { sector = option }
            }
        } label: {
            SignalRow(icon: "building.2", title: s.offerSectorLabel,
                      subtitle: sector?.label(pt: s.pt) ?? s.offerSectorNone) {
                EditGlyph()
            }
        }
        .buttonStyle(.plain)
    }

    private func euroField(label: String, text: Binding<String>, suffix: String,
                           note: String, decimals: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .appFont(13, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("€")
                    .appFont(18)
                    .foregroundStyle(Theme.textSecondary)
                TextField("0", text: text)
                    .keyboardType(decimals ? .decimalPad : .numberPad)
                    .appFont(24, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                Text(suffix)
                    .appFont(13)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.accent).frame(height: 2) }
            Text(note)
                .appFont(11)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Behaviour

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let terms = starting {
            kind = terms.kind
            schedule = terms.schedule
            inputPeriod = terms.inputYearly ? .yearly : .monthly
            let shown = terms.inputYearly ? terms.amount * terms.schedule.months : terms.amount
            amountText = fieldDigits(shown)
            ajudasText = terms.ajudasMonthly > 0 ? Self.plain(terms.ajudasMonthly) : ""
            bonusText = terms.bonusAnnual.map { fieldDigits($0) } ?? ""
            sector = terms.sector
            concelhoID = terms.concelhoID
        } else {
            // The reader's own place and sector, the commonest case, stated on
            // the rows rather than assumed out of sight.
            sector = store.sector
            concelhoID = store.concelhoID
        }
    }

    private func compare() {
        guard let v = amountValue else { return }
        dismissKeyboard()
        let bonus = Self.euros(bonusText) ?? 0
        onCompare(OfferTerms(
            amount: inputPeriod == .yearly ? v / schedule.months : v,
            kind: kind,
            schedule: schedule,
            inputYearly: inputPeriod == .yearly,
            ajudasMonthly: max(0, Self.euros(ajudasText) ?? 0),
            sector: sector,
            concelhoID: concelhoID,
            bonusAnnual: bonus > 0 ? bonus : nil
        ))
    }

    /// The same conversion the salary editor makes when monthly and yearly are
    /// flipped, so the figure in the field keeps meaning the same pay.
    private func convertAmount(to period: SalaryInputPeriod) {
        guard let v = amountValue else { return }
        let months = schedule.months
        switch period {
        case .yearly: amountText = fieldDigits(v * months)
        case .monthly: amountText = fieldDigits(v / months)
        }
    }

    /// Reads what a reader types: spaces and a euro sign are ignored, and a
    /// decimal comma is a decimal point.
    static func euros(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let v = Double(cleaned), v.isFinite, v < typedAmountLimit else { return nil }
        return v
    }

    /// A stored allowance back into the field, with a decimal comma and no
    /// decimals when there are none. A formatter rather than `String(format:)`,
    /// which writes a POSIX point whatever the language (rule 28).
    private static func plain(_ value: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "pt_PT")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? String(Int(value.rounded()))
    }
}

/// Where the offer's job is. `ConcelhoPickerList` on a local binding, because
/// `ConcelhoSheet` writes the reader's own município and this is not that.
///
/// No `presentationDetents`, on purpose: a single `.large` detent is what breaks
/// swipe-to-dismiss on the six sheets rule 26 lists, and the default sheet is
/// already large.
struct OfferPlaceSheet: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss
    @Binding var concelhoID: String?

    private var s: Strings { store.s }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 34, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                Text(s.offerPlaceTitle)
                    .appFont(17, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 14)
                ConcelhoPickerList(selectedID: $concelhoID, onPick: { _ in dismiss() }, s: s)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }
}
