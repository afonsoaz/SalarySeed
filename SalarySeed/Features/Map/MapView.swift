import SwiftUI

/// mapSeed: what your sector pays somewhere else.
///
/// v0.9.2 built the Portuguese half: GEP Quadro 110 (ganho médio by CAE ×
/// distrito) with Quadro 61 for the worker counts. See DistrictDataset for why
/// tenure is not in here, and why adding it would not change a single colour.
///
/// v0.11 adds the European half from Eurostat SES 2022. The two halves share a
/// screen, a sector and a colour ramp, and share NOTHING else: they are separate
/// surveys of separate populations in separate years, so no figure from one is
/// ever placed beside a figure from the other. What crosses is a ratio computed
/// inside Eurostat and applied to the user's own salary. See EuroComparison.
struct MapView: View {
    @EnvironmentObject private var store: SalaryStore
    @EnvironmentObject private var supporter: SupporterStore

    @State private var scope: MapScope = .portugal
    @State private var baseline: MapBaseline = .national
    @State private var selected: District?
    @State private var showSectorSheet = false
    @State private var showConcelhoSheet = false
    @State private var showProfile = false

    // v0.11
    @State private var selectedCountry: Country?
    @State private var purchasingPower = false

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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    scopePicker
                    sectorRow
                    scopeContent
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .sheet(isPresented: $showSectorSheet) { SectorTenureSheet() }
            .sheet(isPresented: $showConcelhoSheet) { ConcelhoSheet() }
            .profileDestination(isPresented: $showProfile)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("mapSeed")
                    .appFont(12)
                    .foregroundStyle(Theme.accent)
                Text(scope == .portugal ? s.mapTitle : s.euroTitle)
                    .appFont(22, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            ProfileButton(isPresented: $showProfile)
        }
        .padding(.top, 8)
    }

    /// Portugal or Europe. The sector picker sits below it because it applies to
    /// both, and moving it would make the two halves feel like two screens.
    private var scopePicker: some View {
        HStack(spacing: 8) {
            ForEach(MapScope.allCases) { option in
                let isOn = scope == option
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { scope = option }
                } label: {
                    Text(option.label(s))
                        .appFont(13, weight: isOn ? .medium : .regular)
                        .foregroundStyle(isOn ? Theme.ink : Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isOn ? Theme.accent : Color.white.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11)
                            .stroke(isOn ? Theme.accent : Theme.cardBorder, lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private var scopeContent: some View {
        switch scope {
        case .portugal: portugalScope
        // v1.0.1: the European half is behind the support payment; Portugal is
        // not, and that split is the whole point. The app's own country stays
        // free because that is what it is for, and the comparison against 26
        // others is the extra.
        case .europe:
            if supporter.isSupporter {
                europeContent
            } else {
                // v1.0.1a: the grid itself, blurred, rather than a page about it.
                // Twenty-seven tiles are recognisable out of focus, which says
                // more about what is behind the payment than a bullet list did.
                //
                // A minimum height, because this one is inside MapView's own
                // ScrollView rather than filling a tab: without it the lock would
                // be as tall as the grid happens to be, and the card would sit
                // wherever that left it.
                SupportLock(title: s.lockEuroTitle, blurb: s.lockEuroBlurb,
                            contentHeight: 540, contentOffsetY: -170) {
                    europeContent
                }
            }
        }
    }

    /// Drawn identically whether or not it is behind the lock, so the blur can
    /// never drift from what is actually being sold.
    private var europeContent: some View {
        EuropeScopeView(sector: store.sector,
                        yourGross: store.breakdown.grossMonthly,
                        purchasingPower: $purchasingPower,
                        selected: $selectedCountry,
                        onPickSector: { showSectorSheet = true })
    }

    private var portugalScope: some View {
        VStack(alignment: .leading, spacing: 18) {
            baselinePicker
            mapBlock
            focusCard
            districtList
            footnotes
        }
    }

    /// Which sector the map is showing. Tapping it opens the same sheet
    /// compareSeed uses, so the two screens can never disagree.
    private var sectorRow: some View {
        Button { showSectorSheet = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "building.2")
                    .appFont(15)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.sector?.label(pt: s.pt) ?? s.mapAllSectors)
                        .appFont(15, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                    Text(store.sector == nil ? s.mapPickSector : s.mapSectorHint)
                        .appFont(10.5)
                        .foregroundStyle(store.sector == nil ? Theme.accent : Theme.textFaint)
                }
                .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .appFont(11)
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(13)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    /// v0.15.3: the home chip only appears when there IS a home district.
    ///
    /// `effectiveBaseline` has always fallen back to national when the district
    /// is unknown, so the chip was a control that lit up and changed nothing.
    /// Rare before, because it needed someone to clear their município; routine
    /// now, because every islander has no district by definition.
    private var baselinePicker: some View {
        HStack(spacing: 8) {
            baselineChip(.national, s.mapVsNational)
            if home != nil {
                baselineChip(.home, s.mapVsHome)
            }
        }
    }

    private func baselineChip(_ mode: MapBaseline, _ label: String) -> some View {
        let enabled = mode == .national || home != nil
        let isOn = effectiveBaseline == mode && enabled
        return Button {
            if enabled {
                withAnimation(.easeOut(duration: 0.15)) { baseline = mode }
            } else {
                showConcelhoSheet = true
            }
        } label: {
            Text(enabled ? label : s.mapNeedConcelho)
                .appFont(12, weight: isOn ? .medium : .regular)
                .foregroundStyle(isOn ? Theme.ink : (enabled ? Theme.textPrimary : Theme.accent))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isOn ? Theme.accent : Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isOn ? Theme.accent : Theme.cardBorder, lineWidth: 1)
                )
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
                HStack(spacing: 8) {
                    Text(focus.district.label)
                        .appFont(17, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                    if focus.district == home {
                        Text(s.mapHomeTag)
                            .appFont(9, weight: .medium)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.accent, in: Capsule())
                    }
                    Spacer()
                    // v0.9.3: the euro figure sits on the same line as the
                    // percentage. It used to be buried in the sentence below,
                    // which made the two numbers read as unrelated.
                    Text(eur(focus.mean))
                        .appFont(15, weight: .medium)
                        .foregroundStyle(Theme.textSecondary)
                    Text(DistrictComparison.formatted(focus.pct))
                        .appFont(19, weight: .semibold)
                        .foregroundStyle(Theme.mapColor(bucket: focus.bucket))
                        .frame(minWidth: 54, alignment: .trailing)
                }
                Text(s.mapBaselineLine(baselineName))
                    .appFont(11.5)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(s.mapAllDistricts)
            ForEach(readings) { reading in
                listRow(reading)
            }
        }
    }

    private func listRow(_ reading: DistrictReading) -> some View {
        let isHome = reading.district == home
        let isSelected = reading.district == selected
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selected = isSelected ? nil : reading.district
            }
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.mapColor(bucket: reading.bucket, thin: reading.thin))
                    .frame(width: 4, height: 22)
                Text(reading.district.label)
                    .appFont(13.5, weight: isHome ? .semibold : .regular)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
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
                Spacer(minLength: 6)
                // v0.9.3: amount and percentage on one line, both right-aligned
                // in fixed columns so they line up down the whole list.
                Text(eur(reading.mean))
                    .appFont(12)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minWidth: 62, alignment: .trailing)
                Text(DistrictComparison.formatted(reading.pct))
                    .appFont(13, weight: .medium)
                    .foregroundStyle(Theme.mapColor(bucket: reading.bucket))
                    .frame(minWidth: 46, alignment: .trailing)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(
                isSelected ? Color.white.opacity(0.06) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }

    // MARK: Footnotes

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
            Text(s.districtSourceLine)
                .appFont(9.5)
                .foregroundStyle(Theme.textFaint)
            Text(s.mapGeoCredit)
                .appFont(9.5)
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.top, 2)
    }
}
