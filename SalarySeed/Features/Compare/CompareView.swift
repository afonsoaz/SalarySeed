import SwiftUI

/// compareSeed: national percentile + layered "people like you" comparisons.
/// Each filled profile signal adds a layer on top of the national number, never
/// replacing it. Layers are honest: thin cohorts and edge results are flagged,
/// and every number carries its source and reference year.
struct CompareView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var activeDimension: CompareDimension?

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
            ForEach(CompareDimension.all) { dim in
                if let option = dim.selectedOption(in: store, pt: s.pt), let cell = dim.cell(option.id) {
                    LayerCard(
                        dimension: dim,
                        option: option,
                        result: CohortEngine.result(grossMonthly: store.breakdown.grossMonthly, cell: cell),
                        userGross: store.breakdown.grossMonthly,
                        s: s
                    ) { activeDimension = dim }
                } else {
                    lockedLayerRow(dim)
                }
            }
            // offerSeed (compare job offers) is hidden until it actually ships.
            // Bring the LockedRow back here when the feature lands.
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.profileFilledCount)
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

// MARK: - Interactive national distribution (v0.7)

/// The national distribution as a playable chart. It rests on the user's own
/// spot (their bar highlighted, their percentile and salary in the readout).
/// Drag across it to explore any point: the readout tracks the salary and
/// percentile under the finger and names how many people sit in that band.
/// Lift the finger and it springs back to the user.
private struct InteractiveDistribution: View {
    let userGross: Double
    let userPercentile: Double
    let s: Strings

    @State private var scrubFrac: Double? = nil

    private var bars: [Double] { PercentileEngine.distributionBars }
    private var scrubbing: Bool { scrubFrac != nil }
    private var userFrac: Double { PercentileEngine.fractionForSalary(userGross) }
    private var activeFrac: Double { scrubFrac ?? userFrac }
    private var activeGross: Double { scrubbing ? PercentileEngine.salaryAtFraction(scrubFrac!) : userGross }
    private var activePct: Double { scrubbing ? PercentileEngine.percentile(grossMonthly: activeGross) : userPercentile }
    private var activeBar: Int { PercentileEngine.barIndex(forFraction: activeFrac) }
    private var userBar: Int { PercentileEngine.barIndex(forFraction: userFrac) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(s.natDistribution)
                Spacer()
                Text(scrubbing ? s.releaseToReset : s.dragToExplore)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
            }

            readout

            GeometryReader { geo in
                let w = geo.size.width
                let maxBar = bars.max() ?? 1
                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(bars.indices, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor(i))
                                .frame(height: max(3, 84 * bars[i] / maxBar))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 84, alignment: .bottom)

                    // indicator line + handle at the active position
                    ZStack {
                        Rectangle()
                            .fill(Theme.accent.opacity(0.5))
                            .frame(width: 1.5, height: 92)
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                            .offset(y: -46)
                    }
                    .position(x: max(6, min(w - 6, activeFrac * w)), y: 42)
                    .animation(scrubbing ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: activeFrac)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in scrubFrac = min(1, max(0, v.location.x / w)) }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { scrubFrac = nil }
                        }
                )
            }
            .frame(height: 92)

            HStack {
                Text("€600").font(.system(size: 10)).foregroundStyle(Theme.textFaint)
                Spacer()
                Text("€10k+").font(.system(size: 10)).foregroundStyle(Theme.textFaint)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func barColor(_ i: Int) -> Color {
        if i == activeBar { return Theme.accent }
        if !scrubbing && i == userBar { return Theme.accent }
        if scrubbing && i == userBar { return Theme.accent.opacity(0.4) }
        return Color.white.opacity(0.12)
    }

    private var readout: some View {
        let share = PercentileEngine.distributionBarShares[activeBar]
        let band = PercentileEngine.barBand(activeBar)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.0f%%", activePct))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                Text(s.earnLess)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 6)
                Text(s.atLevel(eur(activeGross)))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(s.bandShare(pct(share), rangeText(band)))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
        }
    }

    private func pct(_ fraction: Double) -> String {
        let v = fraction * 100
        if v < 1 { return String(format: "%.1f%%", v) }
        return String(format: "%.0f%%", v)
    }

    private func rangeText(_ band: (lower: Double?, upper: Double?)) -> String {
        switch (band.lower, band.upper) {
        case let (nil, hi?): return s.bandUnder(eur(hi))
        case let (lo?, nil): return s.bandOver(eur(lo))
        case let (lo?, hi?): return "\(eur(lo)) – \(eur(hi))"
        default: return ""
        }
    }
}

// MARK: - One unlocked comparison layer

private struct LayerCard: View {
    let dimension: CompareDimension
    let option: DimensionOption
    let result: CohortResult
    let userGross: Double
    let s: Strings
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
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

                PercentileBar(percent: result.percentile)
                    .padding(.top, 12)

                HStack {
                    Text(s.earnLess)
                    Spacer()
                    Text(s.medianWord)
                    Spacer()
                    Text(s.earnMore)
                }
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 4)

                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 8)

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
        }
        .transition(.scale(scale: 0.97).combined(with: .opacity))
    }

    private var caption: String {
        let diff = userGross - result.median
        return s.medianCaption(median: eur(result.median), diff: diff, diffText: eur(abs(diff)))
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
