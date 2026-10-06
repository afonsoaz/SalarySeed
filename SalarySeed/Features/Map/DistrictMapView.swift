import SwiftUI

/// What your sector pays, district by district, against the country or against
/// where you are. The Portuguese half of what used to be mapSeed.
///
/// v0.9.2 built it: GEP Quadro 110 (ganho médio by CAE × distrito) with
/// Quadro 61 for the worker counts. See DistrictDataset for why tenure is not in
/// here, and why adding it would not change a single colour.
///
/// It became a view of its own when the map split in two. The European half is
/// a separate survey of a separate population in a separate year, and it now
/// has a screen of its own. This half is the last section of Compare in
/// Portugal (phase two, Afonso): where you stand, then people like you, then
/// your sector across the country. It was behind a People / Districts switch,
/// which gave the screen two titles and hid half of it.
///
/// The list of every district is folded, one tap away. The map and the card
/// under it already answer "where" and "how much" for any district you touch;
/// the list is the table for reading them all at once, and the way in for
/// anyone who cannot tell the red from the green, so it stays, closed.
struct DistrictMapView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var baseline: MapBaseline = .national
    @State private var selected: District?
    @State private var showSectorSheet = false
    @State private var showAll = false

    private var s: Strings { store.s }

    private var home: District? { store.district }

    /// v0.9.3: if the user clears their município while the home baseline is
    /// selected, fall back to the national one rather than showing a blank map.
    private var effectiveBaseline: MapBaseline {
        (baseline == .home && home == nil) ? .national : baseline
    }

    private var baselineValue: Double? {
        DistrictDataset.baseline(sector: store.sector, mode: effectiveBaseline, home: home)
    }

    private var readings: [DistrictReading] {
        guard let baselineValue else { return [] }
        return DistrictComparison.readings(sector: store.sector, baseline: baselineValue)
    }

    /// The row the readout shows: whatever was tapped, else the user's own.
    private var focus: DistrictReading? {
        let target = selected ?? home
        return readings.first { $0.district == target }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(s.compareDistrictsLabel)
                // Which sector the map is showing. Tapping it opens the same
                // sheet the sector line above uses, so the two can never
                // disagree.
                SectorRow { showSectorSheet = true }
            }
            baselinePicker
            mapBlock
            focusCard
            districtList
            footnotes
        }
        .sheet(isPresented: $showSectorSheet) { SectorTenureSheet() }
    }

    /// What the colours are measured against, as a quiet lens like ×12 / ×14:
    /// it re-reads the map, it is not the map. It was two bright green buttons.
    ///
    /// v0.15.3: the home option only exists when there IS a home district.
    /// `effectiveBaseline` has always fallen back to national when the district
    /// is unknown, so it was a control that lit up and changed nothing. Rare
    /// before, because it needed someone to clear their município; routine
    /// now, because every islander has no district by definition.
    ///
    /// With one option there is nothing to choose, so the switch gives way to
    /// the sentence the card under the map uses. Something has to say what the
    /// colours are measured against: with no home district that card does not
    /// appear until a district is tapped, and the lone "vs the country" chip
    /// was what said it before. Found by looking, as an islander.
    @ViewBuilder
    private var baselinePicker: some View {
        if home != nil {
            QuietSwitch(options: MapBaseline.allCases, selection: $baseline) {
                $0 == .national ? s.mapVsNational : s.mapVsHome
            }
        } else {
            Text(s.mapBaselineLine(baselineName))
                .appFont(11.5)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Map

    /// Portugal is tall and narrow (the outline is about 0.49 wide for 1.0 high),
    /// so a full-height map leaves a lot of empty width. The legend and the
    /// readout live in that space instead of below the map.
    private var mapBlock: some View {
        HStack(alignment: .top, spacing: 14) {
            PortugalMap(readings: readings, home: home, selected: $selected)
                .frame(height: 360)

            VStack(alignment: .leading, spacing: 14) {
                MapLegend(s: s)
                if home != nil {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Theme.textPrimary, lineWidth: 1.5)
                            .frame(width: 14, height: 10)
                        Text(s.mapYouAreHere)
                            .appFont(9.5)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Text(s.mapTapHint)
                    .appFont(9.5)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
                // v0.15: the islands sit beside the mainland rather than being
                // left off it. They carry no colour because the source carries no
                // figure for them, which is a fact worth showing rather than
                // hiding. See IslandTiles.
                IslandTiles(s: s, home: store.region)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Readout

    @ViewBuilder
    private var focusCard: some View {
        if let focus {
            VStack(alignment: .leading, spacing: 6) {
                // Reflow, do not shrink: past an accessibility size the name
                // and the figures each get a row. On one row they broke
                // "Aveiro" into "Aveir / o" and "+2%" into "+2 / %", found by
                // looking at it at accessibility-extra-large.
                if typeSize.isAccessibilitySize {
                    HStack(spacing: 8) { focusName(focus) }
                    HStack(alignment: .firstTextBaseline, spacing: 12) { focusFigures(focus) }
                } else {
                    HStack(spacing: 8) {
                        focusName(focus)
                        Spacer()
                        focusFigures(focus)
                    }
                }
                // With no home district this sentence already stands above
                // the map, where the switch would be; saying it twice would
                // be an echo.
                if home != nil {
                    Text(s.mapBaselineLine(baselineName))
                        .appFont(11.5)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let count = focus.count {
                    Text(focus.thin ? s.mapThinCell(count) : s.mapCellSize(count))
                        .appFont(10)
                        .foregroundStyle(focus.thin ? Theme.danger : Theme.textFaint)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func focusName(_ focus: DistrictReading) -> some View {
        Text(focus.district.label)
            .appFont(17, weight: .medium)
            .foregroundStyle(Theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
        if focus.district == home {
            Text(s.mapHomeTag)
                .appFont(9, weight: .medium)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Theme.accent, in: Capsule())
        }
    }

    /// v0.9.3: the euro figure sits on the same line as the percentage. It
    /// used to be buried in the sentence below, which made the two numbers
    /// read as unrelated.
    @ViewBuilder
    private func focusFigures(_ focus: DistrictReading) -> some View {
        Text(eur(focus.mean))
            .appFont(15, weight: .medium)
            .foregroundStyle(Theme.textSecondary)
        Text(DistrictComparison.formatted(focus.pct))
            .appFont(19, weight: .semibold)
            .foregroundStyle(Theme.mapColor(bucket: focus.bucket))
            .frame(minWidth: typeSize.isAccessibilitySize ? nil : 54, alignment: .trailing)
    }

    private var baselineName: String {
        switch effectiveBaseline {
        case .national: return s.mapBaselineNationalName
        case .home: return home?.label ?? s.mapBaselineNationalName
        }
    }

    // MARK: List
    //
    // The map answers "where", the list answers "how much". It is also the table
    // view that keeps this screen readable for anyone who cannot separate the red
    // from the green, which is why every row carries its own number.

    private var districtList: some View {
        VStack(spacing: 0) {
            Button {
                if reduceMotion {
                    showAll.toggle()
                } else {
                    withAnimation(.snappy(duration: 0.3)) { showAll.toggle() }
                }
            } label: {
                HStack {
                    Text(s.mapAllDistricts)
                        .appFont(15, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .appFont(12, weight: .semibold)
                        .foregroundStyle(Theme.textFaint)
                        .rotationEffect(.degrees(showAll ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowPressStyle())
            .accessibilityValue(showAll ? s.voiceExpanded : s.voiceCollapsed)

            if showAll {
                VStack(spacing: 0) {
                    ForEach(readings) { reading in
                        listRow(reading)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func listRow(_ reading: DistrictReading) -> some View {
        let isHome = reading.district == home
        let isSelected = reading.district == selected
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selected = isSelected ? nil : reading.district
            }
        } label: {
            // Past an accessibility size the name gets a row of its own and
            // the figures go under it: on one row "Viana do Castelo" was cut
            // to "Viana do…", found by looking.
            if typeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 10) {
                    swatch(reading)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) { rowName(reading, isHome: isHome) }
                        HStack(alignment: .firstTextBaseline, spacing: 12) { rowFigures(reading) }
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(
                    isSelected ? Color.white.opacity(0.06) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10)
                )
            } else {
                HStack(spacing: 10) {
                    swatch(reading)
                    rowName(reading, isHome: isHome)
                    Spacer(minLength: 6)
                    rowFigures(reading)
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(
                    isSelected ? Color.white.opacity(0.06) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
        }
    }

    private func swatch(_ reading: DistrictReading) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Theme.mapColor(bucket: reading.bucket, thin: reading.thin))
            .frame(width: 4, height: 22)
    }

    @ViewBuilder
    private func rowName(_ reading: DistrictReading, isHome: Bool) -> some View {
        Text(reading.district.label)
            .appFont(13.5, weight: isHome ? .semibold : .regular)
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
        if isHome {
            Image(systemName: "location.fill")
                .appFont(8)
                .foregroundStyle(Theme.accent)
        }
        if reading.thin {
            Text(s.mapThinTag)
                .appFont(8.5)
                .foregroundStyle(Theme.danger)
        }
    }

    /// v0.9.3: amount and percentage on one line, both right-aligned in fixed
    /// columns so they line up down the whole list.
    @ViewBuilder
    private func rowFigures(_ reading: DistrictReading) -> some View {
        Text(eur(reading.mean))
            .appFont(12)
            .foregroundStyle(Theme.textSecondary)
            .frame(minWidth: typeSize.isAccessibilitySize ? nil : 62, alignment: .trailing)
        Text(DistrictComparison.formatted(reading.pct))
            .appFont(13, weight: .medium)
            .foregroundStyle(Theme.mapColor(bucket: reading.bucket))
            .frame(minWidth: typeSize.isAccessibilitySize ? nil : 46, alignment: .trailing)
    }

    // MARK: Footnotes

    /// What the map cannot do. Its sources are named with the rest of the
    /// screen's, at the foot of Compare in Portugal.
    private var footnotes: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(s.mapNoTenureNote)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.mapScopeNote)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.mapIslandNote)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }
}
