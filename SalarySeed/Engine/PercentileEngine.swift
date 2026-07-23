import Foundation

/// ⚠️ PLACEHOLDER DISTRIBUTION — illustrative points only.
///
/// Replace with a bundled JSON of real INE gross-salary distribution buckets
/// before release, and show "Fonte: INE, <year>" wherever percentiles appear.
/// (INE data is CC BY 4.0 — commercial use OK with attribution.)
enum PercentileEngine {
    /// (gross monthly €, percentile 0–100) — sorted ascending. Illustrative.
    private static let points: [(gross: Double, pct: Double)] = [
        (760, 5), (870, 15), (1_000, 30), (1_150, 45), (1_330, 55),
        (1_500, 63), (1_700, 70), (2_000, 78), (2_500, 86), (3_000, 91),
        (4_000, 95), (5_000, 97), (7_500, 99), (10_000, 99.5),
    ]

    /// Linear interpolation between placeholder distribution points.
    static func percentile(grossMonthly g: Double) -> Double {
        guard let first = points.first, g > first.gross else { return 2 }
        guard let last = points.last, g < last.gross else { return 99.7 }
        for i in 1..<points.count where g <= points[i].gross {
            let (x0, y0) = points[i - 1]
            let (x1, y1) = points[i]
            let t = (g - x0) / (x1 - x0)
            return y0 + t * (y1 - y0)
        }
        return 50
    }

    /// Rough distribution shape for the Compare chart (density per bucket). Illustrative.
    static let distributionBars: [Double] = [
        0.04, 0.12, 0.2, 0.28, 0.22, 0.16, 0.12, 0.09, 0.06,
        0.045, 0.03, 0.02, 0.013, 0.009, 0.006, 0.004,
    ]

    /// Gross value represented by each distribution bar (for marker placement).
    static let distributionBarGross: [Double] = [
        600, 760, 870, 1_000, 1_150, 1_330, 1_500, 1_700, 2_000,
        2_300, 2_700, 3_200, 4_000, 5_000, 7_000, 10_000,
    ]
}
