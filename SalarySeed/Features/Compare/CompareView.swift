import SwiftUI

/// compareSeed (v0.2) — national percentile + layered "people like you" comparisons.
/// Each filled profile signal adds a layer on top of the national number (never
/// replacing it). Layers are honest: thin cohorts and edge results are flagged,
/// and every number carries its source + reference year.
struct CompareView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var activeDimension: CompareDimension?

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
                Text("Where you stand")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            HStack(spacing: 6) {
                SproutView(stage: store.sproutStage, size: 22)
                Text("\(store.profileFilledCount) of 4 planted")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.bottom, 2)
        }
        .padding(.top, 8)
    }

    private var percentileHero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("All of Portugal")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.0f%%", store.percentile))
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text("of workers earn less than you")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text("Gross vs gross · Fonte: INE · 2025 · estimate")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("National distribution")
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(PercentileEngine.distributionBars.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isUserBar(i) ? Theme.accent : Color.white.opacity(0.12))
                        .frame(height: 70 * PercentileEngine.distributionBars[i] / (PercentileEngine.distributionBars.max() ?? 1))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 70, alignment: .bottom)
            HStack {
                Text("€600").font(.system(size: 10)).foregroundStyle(Theme.textFaint)
                Spacer()
                Text("€10k+").font(.system(size: 10)).foregroundStyle(Theme.textFaint)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func isUserBar(_ index: Int) -> Bool {
        let gross = store.breakdown.grossMonthly
        let bounds = PercentileEngine.distributionBarGross
        guard index < bounds.count else { return false }
        let upper = index + 1 < bounds.count ? bounds[index + 1] : .infinity
        return gross >= bounds[index] && gross < upper
    }

    // MARK: Layers

    private var layers: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("People like you — layer by layer")
            ForEach(CompareDimension.all) { dim in
                if let option = dim.selectedOption(in: store), let cell = dim.cell(option.id) {
                    LayerCard(
                        dimension: dim,
                        option: option,
                        result: CohortEngine.result(grossMonthly: store.breakdown.grossMonthly, cell: cell),
                        userGross: store.breakdown.grossMonthly
                    ) { activeDimension = dim }
                } else {
                    lockedLayerRow(dim)
                }
            }
            // premium teaser stays locked (offerSeed)
            LockedRow(icon: "arrow.left.arrow.right", title: "Compare job offers", unlock: "Premium · offerSeed")
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
                    Text(dim.rowTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(dim.unlockHint) · grows your seed")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Text("+ Add")
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
        Text("Cohort medians: \(CohortEngine.sourceLine) · private-sector employees (mock values in this build). Estimates, not official advice.")
            .font(.system(size: 10))
            .foregroundStyle(Theme.textFaint)
            .lineSpacing(2)
    }
}

// MARK: - One unlocked comparison layer

private struct LayerCard: View {
    let dimension: CompareDimension
    let option: DimensionOption
    let result: CohortResult
    let userGross: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dimension.rowTitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 5) {
                            Text(dimension.cohortWord(option.label))
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
                    Text("earn less")
                    Spacer()
                    Text("median")
                    Spacer()
                    Text("earn more")
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
                        Text(result.thin ? "rough estimate — small sample" : "edge of the data — rough")
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
        if abs(diff) < 40 { return "Median: \(eur(result.median)) gross — right at the median." }
        if diff > 0 { return "Median: \(eur(result.median)) gross — you're \(eur(diff)) above." }
        return "Median: \(eur(result.median)) gross — you're \(eur(-diff)) below."
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

/// Locked ≠ hidden: visible teaser + the input needed to unlock it.
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
