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
