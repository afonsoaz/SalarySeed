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

    /// Inverse standard normal CDF (Acklam's rational approximation). Good to
    /// ~1e-9 across the middle range, which is far more than the display needs.
    static func normInv(_ p: Double) -> Double {
        let pp = min(1 - 1e-9, max(1e-9, p))
        let a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
                 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
        let b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
                 6.680131188771972e+01, -1.328068155288572e+01]
        let c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
                 -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
        let d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
                 3.754408661907416e+00]
        let pLow = 0.02425, pHigh = 1 - 0.02425
        if pp < pLow {
            let q = (-2 * log(pp)).squareRoot()
            return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
                   ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        } else if pp <= pHigh {
            let q = pp - 0.5
            let r = q * q
            return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
                   (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
        } else {
            let q = (-2 * log(1 - pp)).squareRoot()
            return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
                    ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
    }

    /// Inverse of `percentile`: the gross monthly salary at a given percentile
    /// (0-100) of the national distribution. Uses the same two-piece log-normal,
    /// so `percentile(salaryAtPercentile(p)) ≈ p`.
    static func salaryAtPercentile(_ p: Double) -> Double {
        let clamped = min(99.9, max(0.1, p))
        let z = normInv(clamped / 100)
        let sigma = z < 0 ? SalaryDataset.sigmaLow : SalaryDataset.sigmaHigh
        return SalaryDataset.nationalMedian * exp(sigma * z)
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
