import SwiftUI

/// The headline of Compare in Portugal: the share of the country that earns
/// less than you, with the country's pay drawn under it.
///
/// Phase two (Afonso) made it one centred figure, like Home's, and folded the
/// distribution explorer into it. It was two cards: the percentage, then a
/// chart whose first line was "The 88th percentile earns 2600 €", which is the
/// reader's own salary said back to them.
///
/// THE HANDLE RUNS ALONG THE SAME AXIS AS THE CHART. It used to run along
/// percentiles while the bars above it run along salaries, so "you" sat in two
/// places at once, two thirds of the way along the chart and nine tenths of the
/// way along the slider, and the slider needed "Lowest" and "Highest" under it
/// to say it was a ranking. Now the handle sits under the marker, and dragging
/// it rewrites the headline in the same shape: "40% of workers in Portugal earn
/// less than 1100 € gross". Let go and it comes back to you.
struct NationalStanding: View {
    @EnvironmentObject private var store: SalaryStore

    /// Where the finger is along the chart, 0 to 1, or nil when resting on you.
    @State private var scrubFrac: Double?

    private var s: Strings { store.s }
    private var bars: [Double] { PercentileEngine.distributionBars }

    var body: some View {
        // The salary is read ONCE per drawing. `store.breakdown` is worked out
        // afresh on every read, and for a salary typed as net that is a
        // bisection; the first version read it once per bar, on every frame
        // of a drag. Found in review.
        let b = store.breakdown
        let r = Reading(userGross: b.grossMonthly, scrubFrac: scrubFrac)
        VStack(spacing: 0) {
            headline(r)
            Text(s.compareBasis)
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            if b.ajudasMonthly > 0 {
                Text(s.ajudasExcludedNote)
                    .appFont(11)
                    .foregroundStyle(Theme.danger.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            chart(r)
                .padding(.top, 26)
            axis
                .padding(.top, 6)
            handle(r)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private func sentence(_ r: Reading) -> String {
        r.scrubbing ? s.compareLessThan(eur(r.activeSalary)) : s.compareLessThanYou
    }

    private func spoken(_ r: Reading) -> String {
        "\(percent(Double(r.activePercent) / 100, decimals: 0)) \(sentence(r))"
    }

    // MARK: The figure

    /// The percentage and what it means, as one thing to VoiceOver.
    ///
    /// The sentence's height is RESERVED for its longest form, the one with the
    /// widest amount in it. Otherwise the line could wrap differently mid-drag
    /// and push the chart, and the handle under the reader's finger, down the
    /// screen while they hold it.
    private func headline(_ r: Reading) -> some View {
        VStack(spacing: 2) {
            Text(percent(Double(r.activePercent) / 100, decimals: 0))
                .appFont(56, weight: .medium)
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
            ZStack(alignment: .top) {
                Text(s.compareLessThan(eur(PercentileEngine.distributionBarGross.last ?? 0))).hidden()
                Text(s.compareLessThanYou).hidden()
                Text(sentence(r))
            }
            .appFont(15)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(r))
    }

    // MARK: The chart

    private func chart(_ r: Reading) -> some View {
        let activeBar = PercentileEngine.barIndex(forFraction: r.frac)
        let userBar = PercentileEngine.barIndex(forFraction: r.userFrac)
        return GeometryReader { geo in
            let w = geo.size.width
            let maxBar = bars.max() ?? 1
            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(bars.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(i, active: activeBar, user: userBar, scrubbing: r.scrubbing))
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
                .position(x: max(6, min(w - 6, r.frac * w)), y: 37)
            }
        }
        .frame(height: 82)
        .animation(r.scrubbing ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: r.frac)
        // The figure above says what the shape shows; the handle below is the
        // way to explore it without sight.
        .accessibilityHidden(true)
    }

    private func barColor(_ i: Int, active: Int, user: Int, scrubbing: Bool) -> Color {
        if i == active { return Theme.accent }
        if scrubbing && i == user { return Theme.accent.opacity(0.4) }
        return Color.white.opacity(0.12)
    }

    /// The two ends of the salary axis, from the data rather than typed in.
    /// These were the literals "€600" and "€10k+", which printed the euro sign
    /// before the number in Portuguese too.
    private var axis: some View {
        HStack {
            Text(eur(PercentileEngine.distributionBarGross.first ?? 0))
            Spacer()
            Text(eur(PercentileEngine.distributionBarGross.last ?? 0) + "+")
        }
        .appFont(10)
        .foregroundStyle(Theme.textFaint)
        .accessibilityHidden(true)
    }

    // MARK: The handle

    /// Drag it and the headline reads that salary instead of yours; let go and
    /// it springs back. The tick marks where you are, to return to.
    private func handle(_ r: Reading) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 6)
                Capsule()
                    .fill(Theme.accent.opacity(r.scrubbing ? 0.9 : 0.5))
                    .frame(width: max(6, r.frac * w), height: 6)
                Rectangle()
                    .fill(Theme.textPrimary.opacity(0.35))
                    .frame(width: 1.5, height: 16)
                    .offset(x: min(w - 1, max(0, r.userFrac * w)) - 0.75)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                    .offset(x: min(w - 20, max(0, r.frac * w - 10)))
            }
            .frame(height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in scrubFrac = min(1, max(0, v.location.x / w)) }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { scrubFrac = nil }
                    }
            )
            .animation(r.scrubbing ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: r.frac)
        }
        .frame(height: 28)
        // VoiceOver adjusts it a bar at a time and hears the headline it
        // writes. Nothing ever lets go of it, so stepping back onto the
        // reader's own place IS "you" again, not the salary nearest it:
        // otherwise nothing could return the headline to "you". Found in
        // review, along with the steps drifting off it after hitting an end.
        .accessibilityElement()
        .accessibilityLabel(s.compareExploreVoice)
        .accessibilityValue(spoken(r))
        .accessibilityAdjustableAction { direction in
            let step = 1 / Double(bars.count)
            let by: Double
            switch direction {
            case .increment: by = step
            case .decrement: by = -step
            @unknown default: return
            }
            let to = min(1, max(0, r.frac + by))
            scrubFrac = abs(to - r.userFrac) < step / 2 ? nil : to
        }
    }
}

/// Everything the headline, the chart and the handle read, worked out once
/// per drawing from one read of the salary.
private struct Reading {
    let scrubFrac: Double?
    /// Where the reader sits along the chart.
    let userFrac: Double
    /// The salary being read: under the finger, to the nearest 10 €, so the
    /// headline steps rather than flickers; otherwise the reader's own.
    let activeSalary: Double
    let activePercent: Int

    init(userGross: Double, scrubFrac: Double?) {
        self.scrubFrac = scrubFrac
        userFrac = PercentileEngine.fractionForSalary(userGross)
        if let scrubFrac {
            activeSalary = (PercentileEngine.salaryAtFraction(scrubFrac) / 10).rounded() * 10
        } else {
            activeSalary = userGross
        }
        activePercent = PercentileEngine.shown(PercentileEngine.percentile(grossMonthly: activeSalary))
    }

    var scrubbing: Bool { scrubFrac != nil }
    var frac: Double { scrubFrac ?? userFrac }
}
