import SwiftUI

/// v0.9.4: try a number without committing to it.
///
/// WHY THIS EXISTS. Until now there was one salary field, and it did two jobs:
/// recording what you actually earn, and answering "what would happen if". Those
/// are different intentions with different consequences — the first should stick
/// and the second should not — and merging them meant every idle experiment
/// silently rewrote the user's real figure. This screen is the second job, and it
/// touches nothing.
///
/// It reuses the user's own tax context (marital situation, dependants, IRS Jovem,
/// pay schedule), because the question is "what if my salary were different",
/// not "what if I were a different person".
struct SalaryExplorerSheet: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var kind: AmountKind = .gross
    @FocusState private var focused: Bool

    private var s: Strings { store.s }

    private var typed: Double {
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return max(0, Double(cleaned) ?? 0)
    }

    /// The typed amount resolved to a monthly gross, using the user's own tax setup.
    private var grossMonthly: Double {
        guard typed > 0 else { return 0 }
        switch kind {
        case .gross: return typed
        case .net:
            return TaxEngine.grossFromNet(
                typed,
                marital: store.maritalSituation,
                dependents: store.dependents,
                jovemExemption: store.irsJovemExemption,
                months: store.schedule.months
            )
        }
    }

    private var breakdown: SalaryBreakdown {
        TaxEngine.breakdown(
            grossMonthly: grossMonthly,
            months: store.schedule.months,
            marital: store.maritalSituation,
            dependents: store.dependents,
            jovemExemption: store.irsJovemExemption
        )
    }

    private var hasValue: Bool { grossMonthly > 0 }

    /// Difference against the salary actually stored, which is the comparison the
    /// user is really making when they type a number in here.
    private var deltaPct: Double {
        let current = store.breakdown.grossMonthly
        guard current > 0, hasValue else { return 0 }
        return 100 * (grossMonthly - current) / current
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    grabber
                    headerBlock.padding(.top, 14)
                    inputBlock.padding(.top, 18)

                    if hasValue {
                        resultBlock.padding(.top, 20)
                        cohortBlock.padding(.top, 18)
                        promoteBlock.padding(.top, 20)
                    } else {
                        Text(s.explorerEmpty)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textFaint)
                            .padding(.top, 24)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            kind = store.kind
            text = String(Int(store.amount.rounded()))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.white.opacity(0.15))
            .frame(width: 34, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.explorerTitle)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(s.explorerSub)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var inputBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("€")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Theme.textSecondary)
                TextField("0", text: $text)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                Text(store.schedule.label(pt: s.pt))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }
            Rectangle().fill(Theme.cardBorder).frame(height: 1)

            HStack(spacing: 8) {
                ForEach(AmountKind.allCases) { option in
                    kindChip(option)
                }
            }
        }
    }

    private func kindChip(_ option: AmountKind) -> some View {
        let isOn = option == kind
        return Button {
            withAnimation(.easeOut(duration: 0.12)) { kind = option }
        } label: {
            Text(option.label(pt: s.pt))
                .font(.system(size: 13, weight: isOn ? .medium : .regular))
                .foregroundStyle(isOn ? Color(hex: 0x06281C) : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isOn ? Theme.accent : Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(isOn ? Theme.accent : Theme.cardBorder, lineWidth: 1)
                )
        }
    }

    private var resultBlock: some View {
        let pct = PercentileEngine.percentile(grossMonthly: breakdown.grossMonthly)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(pct.rounded()))")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                Text(s.explorerPercentileSuffix)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 10) {
                figure(s.explorerNet, eur(breakdown.netMonthly))
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 32)
                figure(s.explorerGross, eur(breakdown.grossMonthly))
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 32)
                figure(s.explorerVsYours, DistrictComparison.formatted(deltaPct))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder, lineWidth: 1))
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The same cohorts compareSeed shows, recomputed for the typed number.
    private var cohortBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(s.peopleLikeYou)

            if let sector = store.sector, let cell = store.sectorCell {
                cohortRow(
                    name: s.sectorCohort(sector.label(pt: s.pt),
                                         tenure: store.tenureBand?.label(pt: s.pt)),
                    cell: cell
                )
            }

            ForEach(CompareDimension.all) { dim in
                if let option = dim.selectedOption(in: store, pt: s.pt),
                   let cell = dim.cell(option.id) {
                    cohortRow(name: s.cohortWord(dim.id, option.label), cell: cell)
                }
            }

            if store.sector == nil && CompareDimension.all.allSatisfy({ $0.selectedOption(in: store, pt: s.pt) == nil }) {
                Text(s.explorerNoCohorts)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func cohortRow(name: String, cell: CohortCell) -> some View {
        let result = CohortEngine.result(grossMonthly: breakdown.grossMonthly, cell: cell)
        return HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(s.explorerPercentileShort(result.percentile))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
    }

    /// The one deliberate way out of exploring and into changing the real number.
    private var promoteBlock: some View {
        VStack(spacing: 10) {
            Text(s.explorerNotSaved)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.kind = kind
                store.amount = typed
                store.inputYearly = false
                dismissKeyboard()
                dismiss()
            } label: {
                Text(s.explorerPromote)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x06281C))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 15))
            }

            Button {
                dismissKeyboard()
                dismiss()
            } label: {
                Text(s.explorerClose)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

/// v0.9.4: the fork between the two intentions, asked once, in one place, so
/// Home and profileSeed cannot word it differently.
extension View {
    func salaryChangeConfirmation(
        isPresented: Binding<Bool>,
        s: Strings,
        onChange: @escaping () -> Void,
        onExplore: @escaping () -> Void
    ) -> some View {
        confirmationDialog(s.salaryChangeTitle, isPresented: isPresented, titleVisibility: .visible) {
            Button(s.salaryChangeYes) { onChange() }
            Button(s.salaryChangeNo) { onExplore() }
            Button(s.cancelButton, role: .cancel) {}
        } message: {
            Text(s.salaryChangeMessage)
        }
    }
}
