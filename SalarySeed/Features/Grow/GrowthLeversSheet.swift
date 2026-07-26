import SwiftUI

/// v0.10: everything the user can change about the projection, in one place.
///
/// The levers are separated from the toggles on purpose. A lever changes the
/// situation being modelled (a different employer, sector, district, tax rule);
/// a toggle changes the unit the answer is drawn in (euros or percentile,
/// nominal or today's money) and lives on the screen itself.
///
/// Two things people expect to find here are deliberately absent, because the
/// data cannot carry them. Occupation is never crossed with sector or with
/// antiguidade in the Quadros de Pessoal, and is published only at two digits,
/// so there is no occupation path to project. Qualification level (Quadros 101
/// to 103) is a real joint cell, but it is a DIFFERENT cut of the same workbook,
/// not something that can be stacked on top of the tenure cut, so it would have
/// to replace the base curve rather than modify it.
struct GrowthLeversSheet: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss

    let ctx: GrowthEngine.Context
    @Binding var scenario: GrowthEngine.Scenario

    @State private var expectedText: String = ""
    @FocusState private var expectedFocused: Bool

    private var s: Strings { store.s }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    horizonBlock
                    cadenceBlock
                    expectedBlock
                    sectorBlock
                    districtBlock
                    fiscalBlock
                    doneButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let expected = scenario.expectedMoveGross, expected > 0 {
                expectedText = String(Int(expected.rounded()))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.growLeversTitle)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(s.growLeversSub)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 14)
    }

    // MARK: How far ahead

    private var horizonBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(s.growLeverHorizon)
            HStack(spacing: 8) {
                ForEach(GrowthEngine.Scenario.horizons, id: \.self) { years in
                    chip(label: s.growYears(years), on: scenario.horizon == years) {
                        scenario.horizon = years
                        // Shortening the window can strand the cadence outside
                        // it, which would leave a lit chip doing nothing.
                        if scenario.switchEvery > years { scenario.switchEvery = 0 }
                    }
                }
            }
        }
    }

    // MARK: Changing employer

    private var cadenceBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(s.growLeverCadence)
            // A cadence longer than the horizon means no move ever lands inside
            // the window, so the second path silently vanishes while the chip
            // stays lit as though it had done something. Offer only the ones the
            // chosen horizon can actually contain.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(GrowthEngine.Scenario.cadences.filter { $0 <= scenario.horizon }, id: \.self) { years in
                    chip(label: years == 0 ? s.growCadenceNever : s.growCadenceEvery(years),
                         on: scenario.switchEvery == years) {
                        scenario.switchEvery = years
                    }
                }
            }
            Text(s.growCadenceNote)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The number that decides the whole stay-versus-move comparison, asked in
    /// euros because that is how an offer arrives, with the percentage it
    /// represents and the percentage it has to beat shown underneath.
    @ViewBuilder
    private var expectedBlock: some View {
        if scenario.switchEvery > 0 {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(s.growLeverExpected)
                HStack(spacing: 6) {
                    Text("€")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Theme.textSecondary)
                    TextField(String(Int(ctx.grossToday.rounded())), text: $expectedText)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .keyboardType(.decimalPad)
                        .focused($expectedFocused)
                        .onChange(of: expectedText) { _, _ in commitExpected() }
                    Text(s.growPerMonthGross)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                }
                Rectangle().fill(Theme.cardBorder).frame(height: 1)
                expectedFootnotes
            }
        }
    }

    private var expectedFootnotes: some View {
        let breakEven = GrowthEngine.breakEvenPremium(
            scenario.sector ?? ctx.sector,
            tenureYears: ctx.startTenure + Double(max(scenario.switchEvery, 1))
        )
        let gain = GrowthEngine.statedGain(ctx: ctx, scenario: scenario)
        return VStack(alignment: .leading, spacing: 4) {
            Text(s.growBreakEvenHint(pctString(breakEven), years: Int(ctx.startTenure) + scenario.switchEvery))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            // v0.10: shown in BOTH branches. The assumption the model makes when
            // the field is empty is not "nothing", it is "you match your salary",
            // and that has to be as visible as a number the user typed.
            Text(gain == nil ? s.growExpectedEmpty : s.growExpectedImplied(pctString(gain ?? 0)))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func commitExpected() {
        let cleaned = expectedText
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        let value = Double(cleaned) ?? 0
        scenario.expectedMoveGross = value > 0 ? value : nil
    }

    // MARK: Sector

    private var sectorBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(s.growLeverSector)
            Menu {
                Button(s.growSameAsNow) { scenario.sector = nil }
                ForEach(Sector.allCases) { sector in
                    Button(sector.label(pt: s.pt)) { scenario.sector = sector }
                }
            } label: {
                pickerRow(value: (scenario.sector ?? ctx.sector).label(pt: s.pt),
                          changed: scenario.sector != nil && scenario.sector != ctx.sector)
            }
            Text(s.growSectorNote)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: District

    private var districtBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(s.growLeverDistrict)
            Menu {
                Button(s.growSameAsNow) { scenario.district = nil }
                ForEach(District.allCases) { district in
                    Button(district.label) { scenario.district = district }
                }
            } label: {
                pickerRow(value: scenario.district?.label ?? ctx.homeDistrict?.label ?? s.growNoDistrict,
                          changed: scenario.district != nil && scenario.district != ctx.homeDistrict)
            }
            Text(s.growRegionNote)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Tax and prices

    private var fiscalBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(s.growLeverFiscal)
            Toggle(isOn: $scenario.bracketsIndexed) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.growBracketsTitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textPrimary)
                    Text(s.growBracketsHint)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.accent)
            slider(title: s.growPayGrowth, hint: s.growPayGrowthHint,
                   value: $scenario.payGrowth, range: 0...0.06)
            slider(title: s.growInflation, hint: s.growInflationHint,
                   value: $scenario.inflation, range: 0...0.06)
        }
    }

    private func slider(title: String, hint: String, value: Binding<Double>,
                        range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(String(format: "%.1f%%", value.wrappedValue * 100))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            Slider(value: value, in: range, step: 0.005).tint(Theme.accent)
            Text(hint)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Bits

    private var doneButton: some View {
        Button {
            dismissKeyboard()
            dismiss()
        } label: {
            Text(s.growLeversDone)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: 0x06281C))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 15))
        }
    }

    private func chip(label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.12)) { action() }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: on ? .medium : .regular))
                .foregroundStyle(on ? Color(hex: 0x06281C) : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(on ? Theme.accent : Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11)
                    .stroke(on ? Theme.accent : Theme.cardBorder, lineWidth: 1))
        }
    }

    private func pickerRow(value: String, changed: Bool) -> some View {
        HStack {
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(changed ? Theme.accent : Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func pctString(_ value: Double) -> String {
        String(format: "%+.1f%%", value * 100)
    }
}
