import Foundation

/// National percentile from real data (v0.4).
///
/// Model: two-piece log-normal around the national median. The shape comes
/// from INE's Estrutura dos Ganhos 2022 decile ratios; the level is anchored
/// to GEP-MTSSS Quadros de Pessoal, Oct 2024. See SalaryDataset for sources.
enum PercentileEngine {

    /// Percentile (0-100) of a gross monthly salary among Portuguese employees.
    static func percentile(grossMonthly g: Double) -> Double {
        guard g > 0 else { return 0 }
        let med = SalaryDataset.nationalMedian
        let sigma = g < med ? SalaryDataset.sigmaLow : SalaryDataset.sigmaHigh
        let z = log(g / med) / sigma
        let p = 100 * normCdf(z)
        // Clamp the display range: beyond these the model is extrapolating.
        return min(99.9, max(0.5, p))
    }

    /// Standard normal CDF.
    static func normCdf(_ z: Double) -> Double {
        0.5 * erfc(-z / 2.0.squareRoot())
    }

    /// Unclamped share of employees earning at or below a gross monthly salary (0-1).
    static func cdf(grossMonthly g: Double) -> Double {
        guard g > 0 else { return 0 }
        let med = SalaryDataset.nationalMedian
        let sigma = g < med ? SalaryDataset.sigmaLow : SalaryDataset.sigmaHigh
        return normCdf(log(g / med) / sigma)
    }

    // MARK: Interactive distribution helpers (v0.7)

    /// Bin edges around each bar marker, in log space (geometric midpoints).
    /// count = distributionBarGross.count + 1; first edge 0, last edge +inf.
    static let distributionBarEdges: [Double] = {
        let m = distributionBarGross
        var edges: [Double] = [0]
        for i in 0..<(m.count - 1) { edges.append((m[i] * m[i + 1]).squareRoot()) }
        edges.append(.infinity)
        return edges
    }()

    /// Share of employees (0-1) whose gross falls in each distribution bar's band.
    static let distributionBarShares: [Double] = {
        let e = distributionBarEdges
        return (0..<distributionBarGross.count).map { i in
            max(0, cdf(grossMonthly: e[i + 1]) - cdf(grossMonthly: e[i]))
        }
    }()

    /// The €a-€b band a bar covers, for the readout. Uses the geometric edges,
    /// rounded to friendly numbers. nil lower shown as "< first", inf upper as "+".
    static func barBand(_ index: Int) -> (lower: Double?, upper: Double?) {
        let e = distributionBarEdges
        guard index >= 0, index < distributionBarGross.count else { return (nil, nil) }
        let lo = index == 0 ? nil : e[index]
        let hi = e[index + 1].isFinite ? e[index + 1] : nil
        return (lo, hi)
    }

    /// Salary for a horizontal fraction (0-1) across the equally-spaced bars,
    /// interpolated in log space between the bar markers.
    static func salaryAtFraction(_ fx: Double) -> Double {
        let m = distributionBarGross
        let n = m.count
        let pos = min(Double(n - 1), max(0, fx * Double(n) - 0.5))
        let lo = Int(pos.rounded(.down))
        let hi = min(n - 1, lo + 1)
        let t = pos - Double(lo)
        let v = log(m[lo]) * (1 - t) + log(m[hi]) * t
        return exp(v)
    }

    /// Inverse of `salaryAtFraction`: the fraction (0-1) where a salary sits.
    static func fractionForSalary(_ g: Double) -> Double {
        let m = distributionBarGross
        let n = m.count
        if g <= m.first! { return 0 }
        if g >= m.last! { return 1 }
        var k = 0
        while k < n - 1 && g > m[k + 1] { k += 1 }
        let t = (log(g) - log(m[k])) / (log(m[k + 1]) - log(m[k]))
        let pos = Double(k) + t
        return (pos + 0.5) / Double(n)
    }

    /// The bar index a horizontal fraction lands on.
    static func barIndex(forFraction fx: Double) -> Int {
        let n = distributionBarGross.count
        return min(n - 1, max(0, Int((fx * Double(n)).rounded(.down))))
    }

    /// Distribution silhouette for the Compare chart. Continuous variant of
    /// the model density evaluated at distributionBarGross, normalised to 1.
    static let distributionBars: [Double] = [
        0.017, 0.18, 0.445, 0.796, 1.0, 0.986, 0.939, 0.863,
        0.735, 0.611, 0.469, 0.333, 0.193, 0.1, 0.03, 0.007,
    ]

    /// Gross value represented by each distribution bar (marker placement).
    static let distributionBarGross: [Double] = [
        600, 760, 870, 1_000, 1_150, 1_330, 1_500, 1_700, 2_000,
        2_300, 2_700, 3_200, 4_000, 5_000, 7_000, 10_000,
    ]
}
