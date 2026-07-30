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

    /// v0.12: tax and prices start folded away. Almost nobody opens this sheet to
    /// change the escalões, and three sliders nobody asked for sitting between
    /// the district picker and the Done button made the whole thing look like
    /// work. Collapsed, never hidden: the settings still exist and still apply,
    /// they just do not have to be scrolled past to reach Done.
    @State private var showMore = false

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
                    moreBlock
                    doneButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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

    /// The number that decides the whole stay-versus-move comparison.
    ///
    /// v0.11.1 made it a PERCENTAGE. It used to be a euro figure, which only ever
    /// described the first move: with a ten-year horizon and a change every three
    /// years there are three moves, and one absolute number cannot say what
    /// happens at the second and third. A percentage applies identically to every
    /// move, and it annualises, so it can be set directly beside what staying is
    /// worth per year and compared without arithmetic in the reader's head.
    ///
    /// A slider rather than a field: this is a small bounded number, and a
    /// keyboard plus decimal-comma parsing bought nothing.
    ///
    /// v0.12 CHANGED WHAT IS SHOWN, not what is set. The slider still moves a
    /// percentage, because a percentage is the only thing that can mean the same
    /// at a move in year 3 and a move in year 9. But "+20%" is not what anyone
    /// walks into a room and asks for, so the big number is now the euro increase
    /// the percentage produces at the first change, and every later change is
    /// listed underneath with its own amount. They differ, and they should: the
    /// same percentage on a bigger salary is more money.
    @ViewBuilder
    private var expectedBlock: some View {
        if scenario.switchEvery > 0 {
            let steps = GrowthEngine.moveSteps(ctx: ctx, scenario: scenario)
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(s.growLeverExpected)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(signedEur(steps.first?.uplift ?? 0))
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(scenario.movePremium > 0 ? Theme.accent : Theme.textSecondary)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(s.growPerMoveSuffix)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Slider(value: $scenario.movePremium, in: 0...0.6, step: 0.01).tint(Theme.accent)
                stepList(steps)
                expectedFootnotes
            }
        }
    }

    /// Each change of employer, with the salary before it, the salary after it,
    /// and the raise in between. Shown even for a single move, because the
    /// headline above says the amount and this says which year it happens in.
    @ViewBuilder
    private func stepList(_ steps: [GrowthEngine.MoveStep]) -> some View {
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(steps) { step in
                    HStack(spacing: 6) {
                        Text(s.growYears(step.year))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textFaint)
                            .frame(width: 62, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(s.growStepArrow(eur(step.from), eur(step.to)))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 6)
                        Text(signedEur(step.uplift))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(step.uplift >= 0 ? Theme.accent : Theme.danger)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func signedEur(_ value: Double) -> String {
        (value >= 0 ? "+" : "-") + eur(abs(value))
    }

    /// The whole point of the percentage: both rates, side by side, built the
    /// same way, so the comparison needs no arithmetic.
    private var expectedFootnotes: some View {
        // Both rates come from the paths, over the same horizon, so the verdict
        // underneath them cannot contradict the chart the user just looked at.
        let rates = GrowthEngine.rates(ctx: ctx, scenario: scenario)
        let staying = rates.staying
        let moving = rates.moving ?? staying
        let beats = moving > staying
        return VStack(alignment: .leading, spacing: 5) {
            rateRow(label: s.growRateMoving, value: moving, tint: Theme.accent)
            rateRow(label: s.growRateStaying, value: staying, tint: Theme.textSecondary)
            // v0.11.1: shown in BOTH branches. The verdict when the premium is
            // zero is not "nothing to say", it is "this move costs you", and that
            // has to be as loud as the flattering case.
            Text(beats
                 ? s.growMoveBeats(pct(moving - staying))
                 : s.growMoveLoses(pct(staying - moving)))
                .font(.system(size: 11.5))
                .foregroundStyle(beats ? Theme.accent : Theme.danger)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.growPremiumNote(scenario.horizon))
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func rateRow(label: String, value: Double, tint: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(String(format: "%+.1f%%", value * 100))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
        }
    }

    private func pct(_ value: Double) -> String { String(format: "%.1f", abs(value) * 100) }

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

    // MARK: Tax and prices, behind one tap

    /// The disclosure. The chevron and the count of what is inside are both on
    /// the row, so a folded section cannot read as an empty one.
    private var moreBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { showMore.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(s.growMoreTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(s.growLeverFiscal)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Image(systemName: showMore ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            }
            if showMore {
                fiscalBlock
            }
        }
        // A lever that is already set must never be the one hidden. If the user
        // turned any of these on earlier in the session, the section opens with
        // the sheet rather than making them find it again.
        .onAppear {
            if scenario.bracketsIndexed || scenario.payGrowth != 0
                || scenario.inflation != GrowthEngine.Scenario().inflation {
                showMore = true
            }
        }
    }

    private var fiscalBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
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

}
