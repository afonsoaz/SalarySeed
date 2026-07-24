import SwiftUI

/// compareSeed: national percentile + layered "people like you" comparisons.
/// Each filled profile signal adds a layer on top of the national number, never
/// replacing it. Layers are honest: thin cohorts and edge results are flagged,
/// and every number carries its source and reference year.
struct CompareView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var activeDimension: CompareDimension?
    @State private var showSectorSheet = false

    private var s: Strings { store.s }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    percentileHero
                    distributionChart
                    layers
                    sourceNote
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .sheet(isPresented: $showSectorSheet) { SectorTenureSheet() }
            .sheet(item: $activeDimension) { dim in
                ProfilePickerSheet(dimension: dim)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("compareSeed")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                Text(s.compareTitle)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            HStack(spacing: 6) {
                SproutView(stage: store.sproutStage, size: 22)
                Text(s.planted(store.profileFilledCount, of: 4))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.bottom, 2)
        }
        .padding(.top, 8)
    }

    private var percentileHero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.allPortugal)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Text(String(format: "%.0f%%", store.percentile))
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Theme.accent)
            Text(s.earnLessThanYou)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.grossVsGross)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 4)
            if store.breakdown.ajudasMonthly > 0 {
                Text(s.ajudasExcludedNote)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.danger.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var distributionChart: some View {
        InteractiveDistribution(
            userGross: store.breakdown.grossMonthly,
            userPercentile: store.percentile,
            s: s
        )
    }

    // MARK: Layers

    private var layers: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.peopleLikeYou)

            // Sector × tenure leads: it's the combined "people like you" cohort.
            if let sector = store.sector, let cell = store.sectorCell {
                SectorCard(
                    sector: sector,
                    tenureYears: store.tenureYears,
                    result: CohortEngine.result(grossMonthly: store.breakdown.grossMonthly, cell: cell),
                    cell: cell,
                    userGross: store.breakdown.grossMonthly,
                    s: s
                ) { showSectorSheet = true }
            } else {
                lockedSectorRow
            }

            ForEach(CompareDimension.all) { dim in
                if let option = dim.selectedOption(in: store, pt: s.pt), let cell = dim.cell(option.id) {
                    LayerCard(
                        dimension: dim,
                        option: option,
                        result: CohortEngine.result(grossMonthly: store.breakdown.grossMonthly, cell: cell),
                        cell: cell,
                        userGross: store.breakdown.grossMonthly,
                        s: s
                    ) { activeDimension = dim }
                } else {
                    lockedLayerRow(dim)
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.profileFilledCount)
    }

    private var lockedSectorRow: some View {
        Button { showSectorSheet = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "building.2")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.sectorRowTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(s.sectorAddHint)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Text(s.addPill)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: 0x06281C))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9))
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .opacity(0.9)
        }
    }

    private func lockedLayerRow(_ dim: CompareDimension) -> some View {
        Button { activeDimension = dim } label: {
            HStack(spacing: 12) {
                Image(systemName: dim.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.dimRowTitle(dim.id))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(s.dimAdd(dim.id))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Text(s.addPill)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: 0x06281C))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9))
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .opacity(0.9)
        }
    }

    private var sourceNote: some View {
        Text(s.compareSourceNote)
            .font(.system(size: 10))
            .foregroundStyle(Theme.textFaint)
            .lineSpacing(2)
    }
}

// MARK: - Interactive national distribution (v0.8)

/// The national distribution as a percentile you can play with. The bell curve
/// (salary axis) sits on top for context, with a marker at the current salary.
/// Below it a linear percentile slider is the thing you drag: pick any percentile
/// and the readout shows how much people at that level earn. Let go and it springs
/// back to the user's own percentile.
private struct InteractiveDistribution: View {
    let userGross: Double
    let userPercentile: Double
    let s: Strings

    /// The percentile (0-100) under the finger, or nil when resting on the user.
    @State private var scrubPct: Double? = nil

    private var bars: [Double] { PercentileEngine.distributionBars }
    private var scrubbing: Bool { scrubPct != nil }
    private var activePct: Double { scrubPct ?? userPercentile }
    /// Salary at the active percentile. On the user's own spot we use their exact
    /// gross rather than the model inverse, so their real number always shows.
    private var activeSalary: Double {
        scrubbing ? PercentileEngine.salaryAtPercentile(activePct) : userGross
    }
    private var curveFrac: Double { PercentileEngine.fractionForSalary(activeSalary) }
    private var userCurveFrac: Double { PercentileEngine.fractionForSalary(userGross) }
    private var activeBar: Int { PercentileEngine.barIndex(forFraction: curveFrac) }
    private var userBar: Int { PercentileEngine.barIndex(forFraction: userCurveFrac) }
    private var sliderFrac: Double { min(1, max(0, activePct / 100)) }
    private var userSliderFrac: Double { min(1, max(0, userPercentile / 100)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(s.natDistribution)
                Spacer()
                Text(scrubbing ? s.releaseToReset : s.exploreByPercentile)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
            }

            readout

            // Bell curve (salary axis) with a marker at the active salary.
            GeometryReader { geo in
                let w = geo.size.width
                let maxBar = bars.max() ?? 1
                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(bars.indices, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor(i))
                                .frame(height: max(3, 74 * bars[i] / maxBar))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 74, alignment: .bottom)

                    ZStack {
                        Rectangle()
                            .fill(Theme.accent.opacity(0.5))
                            .frame(width: 1.5, height: 82)
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                            .offset(y: -41)
                    }
                    .position(x: max(6, min(w - 6, curveFrac * w)), y: 37)
                    .animation(scrubbing ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: curveFrac)
                }
            }
            .frame(height: 82)

            HStack {
                Text("€600").font(.system(size: 10)).foregroundStyle(Theme.textFaint)
                Spacer()
                Text("€10k+").font(.system(size: 10)).foregroundStyle(Theme.textFaint)
            }

            // The percentile slider: the thing you drag.
            percentileSlider

            Text(s.exploreHint)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var percentileSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    Capsule()
                        .fill(Theme.accent.opacity(0.5))
                        .frame(width: max(6, sliderFrac * w), height: 6)
                    // the user's own percentile, a fixed tick to return to
                    Rectangle()
                        .fill(Theme.textPrimary.opacity(0.35))
                        .frame(width: 1.5, height: 16)
                        .offset(x: min(w - 1, max(0, userSliderFrac * w)) - 0.75)
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                        .offset(x: min(w - 20, max(0, sliderFrac * w - 10)))
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in scrubPct = min(99.9, max(0.5, v.location.x / w * 100)) }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { scrubPct = nil }
                        }
                )
                .animation(scrubbing ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: sliderFrac)
            }
            .frame(height: 24)

            HStack {
                Text(s.lowestEarners).font(.system(size: 10)).foregroundStyle(Theme.textFaint)
                Spacer()
                Text(s.youMarker).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(s.highestEarners).font(.system(size: 10)).foregroundStyle(Theme.textFaint)
            }
        }
    }

    private func barColor(_ i: Int) -> Color {
        if i == activeBar { return Theme.accent }
        if !scrubbing && i == userBar { return Theme.accent }
        if scrubbing && i == userBar { return Theme.accent.opacity(0.4) }
        return Color.white.opacity(0.12)
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(s.percentileEarns(s.ordinalPercentile(Int(activePct.rounded()))))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(eur(activeSalary))
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                Text(s.perMonthSuffix)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

// MARK: - One unlocked comparison layer

private struct LayerCard: View {
    let dimension: CompareDimension
    let option: DimensionOption
    let result: CohortResult
    let cell: CohortCell
    let userGross: Double
    let s: Strings
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Only the header edits the dimension, so the slider below is free to drag.
            Button(action: onTap) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.dimRowTitle(dimension.id))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 5) {
                            Text(s.cohortWord(dimension.id, option.label))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                    Spacer()
                    Text("\(result.percentile)%")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            .buttonStyle(.plain)

            PercentileSlider(userPercentile: Double(result.percentile), salaryAt: salaryAt, s: s)
                .padding(.top, 12)

            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.leading)
                .padding(.top, 10)

            if result.thin || result.edge {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 9))
                    Text(result.thin ? s.thinChip : s.edgeChip)
                        .font(.system(size: 10))
                }
                .foregroundStyle(Theme.segEmployeeSS)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.segEmployeeSS.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.segEmployeeSS.opacity(0.25)))
                .padding(.top, 7)
            }

            Text(CohortEngine.sourceLine)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 6)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .transition(.scale(scale: 0.97).combined(with: .opacity))
    }

    /// Salary at a percentile (0-100) within this cohort's log-normal.
    private func salaryAt(_ p: Double) -> Double {
        let clamped = min(99.9, max(0.1, p))
        return cell.median * exp(cell.sigma * PercentileEngine.normInv(clamped / 100))
    }

    private var caption: String {
        let diff = userGross - result.median
        return s.medianCaption(median: eur(result.median), diff: diff, diffText: eur(abs(diff)))
    }
}

// MARK: - Sector × tenure card (the combined cohort)

private struct SectorCard: View {
    let sector: Sector
    let tenureYears: Int?
    let result: CohortResult
    let cell: CohortCell
    let userGross: Double
    let s: Strings
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.sectorKicker)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 5) {
                            Text(cohortName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                    Spacer(minLength: 8)
                    Text("\(result.percentile)%")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            .buttonStyle(.plain)

            PercentileSlider(userPercentile: Double(result.percentile), salaryAt: salaryAt, s: s)
                .padding(.top, 12)

            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.leading)
                .padding(.top, 10)

            if tenureYears == nil {
                Text(s.tenureAddHint)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 6)
            }

            if result.edge {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 9))
                    Text(s.edgeChip)
                        .font(.system(size: 10))
                }
                .foregroundStyle(Theme.segEmployeeSS)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.segEmployeeSS.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.segEmployeeSS.opacity(0.25)))
                .padding(.top, 7)
            }

            Text(CohortEngine.sourceLine)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 6)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .transition(.scale(scale: 0.97).combined(with: .opacity))
    }

    private var cohortName: String {
        s.sectorCohort(sector.label(pt: s.pt), tenure: tenureYears.map { s.yearsText($0) })
    }

    private func salaryAt(_ p: Double) -> Double {
        let clamped = min(99.9, max(0.1, p))
        return cell.median * exp(cell.sigma * PercentileEngine.normInv(clamped / 100))
    }

    private var caption: String {
        let diff = userGross - result.median
        return s.medianCaption(median: eur(result.median), diff: diff, diffText: eur(abs(diff)))
    }
}

// MARK: - Reusable percentile slider (used by every cohort layer)

/// A compact version of the national explorer's slider: drag to any percentile
/// and the readout shows the salary at that level. It rests on the user's own
/// percentile (a fixed tick marks it) and springs back on release.
private struct PercentileSlider: View {
    let userPercentile: Double
    let salaryAt: (Double) -> Double
    let s: Strings

    @State private var scrubPct: Double? = nil

    private var scrubbing: Bool { scrubPct != nil }
    private var activePct: Double { scrubPct ?? userPercentile }
    private var activeSalary: Double { salaryAt(activePct) }
    private var frac: Double { min(1, max(0, activePct / 100)) }
    private var userFrac: Double { min(1, max(0, userPercentile / 100)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(s.percentileEarns(s.ordinalPercentile(Int(activePct.rounded()))))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 6)
                Text(eur(activeSalary))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                Text(s.perMonthSuffix)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    Capsule()
                        .fill(Theme.accent.opacity(scrubbing ? 0.9 : 0.5))
                        .frame(width: max(6, frac * w), height: 6)
                    Rectangle()
                        .fill(Theme.textPrimary.opacity(0.35))
                        .frame(width: 1.5, height: 14)
                        .offset(x: min(w - 1, max(0, userFrac * w)) - 0.75)
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                        .offset(x: min(w - 18, max(0, frac * w - 9)))
                }
                .frame(height: 22)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in scrubPct = min(99.9, max(0.5, v.location.x / w * 100)) }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { scrubPct = nil }
                        }
                )
                .animation(scrubbing ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: frac)
            }
            .frame(height: 22)
        }
    }
}

// MARK: - Percentile bar (fixed median tick at 50%, animated "you" dot)

struct PercentileBar: View {
    let percent: Int
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let frac = appeared ? CGFloat(percent) / 100 : 0
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: w, height: 8)
                    .position(x: w / 2, y: 7)
                Capsule()
                    .fill(LinearGradient(
                        colors: [Theme.accent.opacity(0.15), Theme.accent.opacity(0.55)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: max(8, w * frac), height: 8)
                    .position(x: max(8, w * frac) / 2, y: 7)
                Rectangle()
                    .fill(Theme.textPrimary.opacity(0.35))
                    .frame(width: 1.5, height: 14)
                    .position(x: w / 2, y: 7)
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.18)).frame(width: 19, height: 19)
                    Circle().fill(Theme.accent).frame(width: 11, height: 11)
                }
                .position(x: w * frac, y: 7)
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.85), value: frac)
        }
        .frame(height: 14)
        .onAppear { appeared = true }
    }
}

/// Locked but visible: a teaser plus the input needed to unlock it.
struct LockedRow: View {
    let icon: String
    let title: String
    let unlock: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(unlock)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .opacity(0.85)
    }
}
