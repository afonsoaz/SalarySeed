import SwiftUI

/// What the chart is plotting. Euros and percentile are two different questions
/// and share no axis, so they are a toggle rather than a second line: your euros
/// can rise for twenty years while your position among everyone else does not
/// move at all, and that is worth being able to see on its own.
enum GrowMetric: String, CaseIterable, Identifiable {
    case net, gross, percentile
    var id: String { rawValue }

    func label(_ s: Strings) -> String {
        switch self {
        case .net: return s.growMetricNet
        case .gross: return s.growMetricGross
        case .percentile: return s.growMetricPercentile
        }
    }

    func value(_ p: GrowthEngine.YearPoint) -> Double {
        switch self {
        case .net: return p.net
        case .gross: return p.gross
        case .percentile: return p.percentile
        }
    }

    var isMoney: Bool { self != .percentile }
}

/// v0.10: the two paths, drawn as what the data actually is.
///
/// STEPS, NOT A CURVE. Quadro 104 publishes six tenure bands, so pay in this
/// model changes at band boundaries and nowhere else. Drawing a smooth rising
/// line would invent nineteen values GEP never measured and would quietly hide
/// that ten of the twenty-four sectors go DOWN between some pair of bands. The
/// staircase is the honest shape.
struct GrowthChart: View {
    let stay: [GrowthEngine.YearPoint]
    let move: [GrowthEngine.YearPoint]?
    let metric: GrowMetric
    /// Applied to money before drawing, so the today's-money toggle changes the
    /// chart and the scrubbed figures together. Percentile is already real.
    let scale: (Int) -> Double
    @Binding var scrubYear: Int

    private let height: CGFloat = 190

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = height
            let range = valueRange
            content(w: w, h: h, range: range)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            guard w > 0, horizon > 0 else { return }
                            let raw = (g.location.x / w) * CGFloat(horizon)
                            let y = Int(raw.rounded())
                            scrubYear = min(horizon, max(0, y))
                        }
                )
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func content(w: CGFloat, h: CGFloat, range: (lo: Double, hi: Double)) -> some View {
        ZStack(alignment: .topLeading) {
            bandTicks(w: w, h: h)
            if let move {
                gapFill(move: move, w: w, h: h, range: range)
                stepPath(points: move, w: w, h: h, range: range)
                    .stroke(moveColor, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                moveMarkers(move: move, w: w, h: h, range: range)
            }
            stepPath(points: stay, w: w, h: h, range: range)
                .stroke(Theme.textSecondary, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            scrubber(w: w, h: h, range: range)
        }
    }

    // MARK: Geometry

    private var horizon: Int { max(1, (stay.last?.year ?? 1)) }

    private func scaled(_ p: GrowthEngine.YearPoint) -> Double {
        let raw = metric.value(p)
        return metric.isMoney ? raw * scale(p.year) : raw
    }

    private var valueRange: (lo: Double, hi: Double) {
        var values = stay.map(scaled)
        if let move { values += move.map(scaled) }
        guard let rawLo = values.min(), let rawHi = values.max() else { return (0, 1) }
        // A flat path would collapse to a zero-height band, so give it room.
        if rawHi - rawLo < 0.0001 { return (rawLo * 0.9, rawHi * 1.1 + 1) }
        let pad = (rawHi - rawLo) * 0.12
        return (rawLo - pad, rawHi + pad)
    }

    private func x(_ year: Int, w: CGFloat) -> CGFloat {
        CGFloat(year) / CGFloat(horizon) * w
    }

    private func y(_ value: Double, h: CGFloat, range: (lo: Double, hi: Double)) -> CGFloat {
        let span = range.hi - range.lo
        guard span > 0 else { return h / 2 }
        return h - CGFloat((value - range.lo) / span) * h
    }

    // MARK: Marks

    /// The staircase. Each year holds its value until the next one, then steps.
    private func stepPath(points: [GrowthEngine.YearPoint], w: CGFloat, h: CGFloat,
                          range: (lo: Double, hi: Double)) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: x(first.year, w: w), y: y(scaled(first), h: h, range: range)))
        for i in 1..<max(1, points.count) {
            let prev = points[i - 1]
            let curr = points[i]
            let cx = x(curr.year, w: w)
            path.addLine(to: CGPoint(x: cx, y: y(scaled(prev), h: h, range: range)))
            path.addLine(to: CGPoint(x: cx, y: y(scaled(curr), h: h, range: range)))
        }
        return path
    }

    /// The area between the two paths. Filled in one colour, decided by where
    /// they end up, because a two-tone fill on a staircase reads as noise.
    private func gapFill(move: [GrowthEngine.YearPoint], w: CGFloat, h: CGFloat,
                         range: (lo: Double, hi: Double)) -> some View {
        var path = stepPath(points: move, w: w, h: h, range: range)
        let back = stepPath(points: stay.reversed(), w: w, h: h, range: range)
        path.addPath(back)
        path.closeSubpath()
        return path.fill(moveColor.opacity(0.13))
    }

    private var moveColor: Color {
        guard let move, let last = move.last, let stayLast = stay.last else { return Theme.accent }
        return scaled(last) >= scaled(stayLast) ? Theme.accent : Theme.danger
    }

    /// A dot at every change of employer, so the sawtooth reads as a reset
    /// rather than as a mistake in the data.
    private func moveMarkers(move: [GrowthEngine.YearPoint], w: CGFloat, h: CGFloat,
                             range: (lo: Double, hi: Double)) -> some View {
        ForEach(move.filter(\.moved)) { p in
            Circle()
                .fill(moveColor)
                .frame(width: 7, height: 7)
                .position(x: x(p.year, w: w), y: y(scaled(p), h: h, range: range))
        }
    }

    /// Faint verticals where the stay path crosses a band boundary. They are the
    /// only years anything can change, and showing them makes the six-band
    /// granularity of the source visible instead of implied.
    private func bandTicks(w: CGFloat, h: CGFloat) -> some View {
        ForEach(bandCrossings, id: \.self) { year in
            Rectangle()
                .fill(Theme.cardBorder)
                .frame(width: 1, height: h)
                .position(x: x(year, w: w), y: h / 2)
        }
    }

    private var bandCrossings: [Int] {
        stay.dropFirst().compactMap { p -> Int? in
            let prev = GrowthEngine.bandIndex(tenureYears: p.tenure - 1)
            let now = GrowthEngine.bandIndex(tenureYears: p.tenure)
            return now != prev ? p.year : nil
        }
    }

    private func scrubber(w: CGFloat, h: CGFloat, range: (lo: Double, hi: Double)) -> some View {
        let year = min(horizon, max(0, scrubYear))
        let px = x(year, w: w)
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Theme.textFaint)
                .frame(width: 1, height: h)
                .position(x: px, y: h / 2)
            if let p = stay.first(where: { $0.year == year }) {
                dot(Theme.textSecondary, at: CGPoint(x: px, y: y(scaled(p), h: h, range: range)))
            }
            if let mp = move?.first(where: { $0.year == year }) {
                dot(moveColor, at: CGPoint(x: px, y: y(scaled(mp), h: h, range: range)))
            }
        }
    }

    private func dot(_ color: Color, at point: CGPoint) -> some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay(Circle().stroke(Theme.background, lineWidth: 2))
            .position(point)
    }
}

/// The two-line key under the chart. Colour is never the only channel: each
/// entry is also named.
struct GrowthLegend: View {
    let s: Strings
    let showMove: Bool
    let moveAhead: Bool

    var body: some View {
        HStack(spacing: 14) {
            entry(color: Theme.textSecondary, text: s.growLegendStay)
            if showMove {
                entry(color: moveAhead ? Theme.accent : Theme.danger, text: s.growLegendMove)
            }
            Spacer(minLength: 0)
        }
    }

    private func entry(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 14, height: 2)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
