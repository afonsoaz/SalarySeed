import SwiftUI

/// Which half of mapSeed is showing.
enum MapScope: String, CaseIterable, Identifiable {
    case portugal, europe
    var id: String { rawValue }
    func label(_ s: Strings) -> String {
        switch self {
        case .portugal: return s.mapScopePortugal
        case .europe: return s.mapScopeEurope
        }
    }
}

/// v0.11: the European half of mapSeed.
///
/// Everything here is a RATIO, never a level. Eurostat's euro figures are used
/// only to divide one country by Portugal; the result multiplies the user's own
/// salary. A Portuguese salary and a Eurostat mean are never shown as the same
/// kind of number, because they are not: different survey, different year,
/// different population.
///
/// The screen is deliberately talkative about what it cannot do. Three of the
/// app's sectors share NACE section G and three more share J, so someone in IT is
/// being compared as "information and communication" alongside telecoms and
/// publishing, and the screen names the sectors that got merged rather than
/// letting the user assume the comparison is about their job.
struct EuropeScopeView: View {
    @EnvironmentObject private var store: SalaryStore

    let sector: Sector?
    let yourGross: Double
    @Binding var purchasingPower: Bool
    @Binding var selected: Country?
    let onPickSector: () -> Void

    private var s: Strings { store.s }

    private var section: EuroSection? { sector?.euroSection }

    private var readings: [EuroReading] {
        guard let section else { return [] }
        return EuroComparison.readings(section: section,
                                       purchasingPower: purchasingPower,
                                       yourGross: yourGross)
    }

    /// What the readout shows: whatever was tapped, else Portugal, which is the
    /// reference and therefore always the honest default.
    private var focus: EuroReading? {
        readings.first { $0.country == (selected ?? .portugal) }
    }

    var body: some View {
        if sector == nil {
            prompt(title: s.euroPickSector, body: s.euroPickSectorBody, action: s.euroPickSectorButton)
        } else if section == nil {
            prompt(title: s.euroNoSection, body: s.euroNoSectionBody(sector?.label(pt: s.pt) ?? ""), action: nil)
        } else {
            loaded
        }
    }

    private var loaded: some View {
        VStack(alignment: .leading, spacing: 16) {
            unitPicker
            sectionLine
            EuropeGrid(readings: readings, pt: s.pt, selected: $selected)
            Text(s.euroTapHint)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
            EuroLegend(s: s)
            focusCard
            rankLine
            countryList
            footnotes
        }
    }

    // MARK: Controls

    /// v0.12: the two chips are named for what they contain, "Salário absoluto (€)"
    /// and "Salário PPP (€)", instead of the friendlier "In euros" and "What it
    /// buys". PPP is the term on every source that publishes this, so hiding it
    /// behind a paraphrase left people unable to look up what they were reading.
    /// The paraphrase becomes the explanation, and it appears only under the PPP
    /// chip, because that is the only one that needs it.
    private var unitPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                unitChip(on: !purchasingPower, label: s.euroUnitEuros) { purchasingPower = false }
                unitChip(on: purchasingPower, label: s.euroUnitPower) { purchasingPower = true }
            }
            if purchasingPower {
                Text(s.euroPppExplainer)
                    .appFont(10.5)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func unitChip(on: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { action() }
        } label: {
            Text(label)
                .appFont(12, weight: on ? .medium : .regular)
                .foregroundStyle(on ? Theme.ink : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(on ? Theme.accent : Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(on ? Theme.accent : Theme.cardBorder, lineWidth: 1))
        }
    }

    /// Which NACE section the user's sector is being compared as, and, when more
    /// than one of the app's sectors lands on it, which ones. Shown above the
    /// grid rather than in a footnote, because it changes what the grid means.
    @ViewBuilder
    private var sectionLine: some View {
        if let section {
            let shared = EuroComparison.sectorsSharing(section)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.euroSectionLine(section.label(pt: s.pt)))
                    .appFont(11.5)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if shared.count > 1 {
                    Text(s.euroCollapsed(shared.map { $0.label(pt: s.pt) }.joined(separator: ", ")))
                        .appFont(10)
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Readout

    @ViewBuilder
    private var focusCard: some View {
        if let focus {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(focus.country.label(pt: s.pt))
                        .appFont(17, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if focus.isPortugal {
                        Text(s.euroReferenceTag)
                            .appFont(9, weight: .medium)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.accent, in: Capsule())
                    }
                    Spacer(minLength: 6)
                    if let pct = focus.pct, let bucket = focus.bucket {
                        Text(EuroComparison.formatted(pct))
                            .appFont(19, weight: .semibold)
                            .foregroundStyle(Theme.mapColor(bucket: bucket))
                    }
                }
                focusBody(focus)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    /// The sentence under the percentage. Portugal, a country with a cell and a
    /// country without one are three different situations and each gets its own
    /// wording rather than one sentence bent to cover all three.
    @ViewBuilder
    private func focusBody(_ focus: EuroReading) -> some View {
        if focus.isPortugal {
            Text(s.euroPortugalBody)
                .appFont(11.5)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if focus.hasData {
            VStack(alignment: .leading, spacing: 8) {
                // v0.11.1: the two figures the percentage is made of, side by
                // side, so the comparison can be checked rather than trusted.
                // Both come from the same Eurostat table, which is the only
                // reason they are allowed to sit next to each other at all.
                comparisonRow(focus)
                if let moved = focus.yourSalary {
                    Text(s.euroYourSalaryLine(eur(moved), purchasingPower: purchasingPower))
                        .appFont(12.5)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(s.euroNotAJob)
                    .appFont(10)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(s.euroNoDataBody(focus.country.label(pt: s.pt)))
                .appFont(11.5)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// That country's figure and Portugal's, both from the European survey, with
    /// the difference spelled out in words underneath the percentage above.
    @ViewBuilder
    private func comparisonRow(_ focus: EuroReading) -> some View {
        let portugal = readings.first(where: \.isPortugal)
        if let mine = focus.mean, let pt = portugal?.mean {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    euroFigure(focus.country.label(pt: s.pt), eur(mine), Theme.textPrimary)
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 30)
                    euroFigure(s.euroPortugalShort, eur(pt), Theme.textSecondary)
                }
                if let pct = focus.pct {
                    Text(s.euroDirectChange(focus.country.label(pt: s.pt),
                                            String(format: "%.0f%%", abs(pct)),
                                            eur(abs(mine - pt)),
                                            higher: pct >= 0))
                        .appFont(12)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func euroFigure(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .appFont(10)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Text(value)
                .appFont(16, weight: .medium)
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var rankLine: some View {
        if let rank = EuroComparison.portugalRank(in: readings) {
            HStack(spacing: 7) {
                Image(systemName: "flag")
                    .appFont(11)
                    .foregroundStyle(Theme.accent)
                Text(s.euroRank(rank.place, of: rank.outOf, purchasingPower: purchasingPower))
                    .appFont(12)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accentBorder))
        }
    }

    // MARK: List
    //
    // The grid answers "where", the list answers "how much", and the list is also
    // what keeps this screen usable for anyone who cannot separate red from
    // green. Every row carries its own number.

    private var countryList: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(s.euroAllCountries)
            ForEach(readings) { reading in
                listRow(reading)
            }
        }
    }

    private func listRow(_ reading: EuroReading) -> some View {
        let isSelected = reading.country == selected
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selected = isSelected ? nil : reading.country
            }
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(reading.bucket.map { Theme.mapColor(bucket: $0) } ?? Theme.textFaint.opacity(0.4))
                    .frame(width: 4, height: 22)
                Text(reading.country.label(pt: s.pt))
                    .appFont(13.5, weight: reading.isPortugal ? .semibold : .regular)
                    .foregroundStyle(reading.hasData ? Theme.textPrimary : Theme.textFaint)
                    .lineLimit(1)
                if reading.isPortugal {
                    Image(systemName: "location.fill")
                        .appFont(8)
                        .foregroundStyle(Theme.accent)
                }
                Spacer(minLength: 6)
                Text(reading.mean.map { eur($0) } ?? s.euroDash)
                    .appFont(12)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minWidth: 62, alignment: .trailing)
                Text(reading.pct.map { EuroComparison.formatted($0) } ?? s.euroDash)
                    .appFont(13, weight: .medium)
                    .foregroundStyle(reading.bucket.map { Theme.mapColor(bucket: $0) } ?? Theme.textFaint)
                    .frame(minWidth: 46, alignment: .trailing)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(isSelected ? Color.white.opacity(0.06) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: Prompts and footnotes

    private func prompt(title: String, body: String, action: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .appFont(16, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
            Text(body)
                .appFont(12.5)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action: onPickSector) {
                    Text(action)
                        .appFont(14, weight: .semibold)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var footnotes: some View {
        VStack(alignment: .leading, spacing: 5) {
            note(s.euroFootnoteMethod)
            note(s.euroFootnoteVintage)
            note(s.euroFootnoteScope)
            note(s.euroFootnoteGaps)
            Text(EuroDataset.sourceLine)
                .appFont(9.5)
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.top, 2)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .appFont(10)
            .foregroundStyle(Theme.textFaint)
            .fixedSize(horizontal: false, vertical: true)
    }
}
