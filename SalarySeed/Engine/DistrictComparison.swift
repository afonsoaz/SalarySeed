import Foundation

/// v0.9.2: turns the district table into what mapSeed draws.
///
/// One reading per district: the mean, its distance from the baseline, and
/// whether the cell is thin enough that the number should not be trusted.
struct DistrictReading: Identifiable {
    let district: District
    let mean: Double
    /// Percentage difference from the baseline. Positive = pays more.
    let pct: Double
    /// Employees in the cell, when a sector is selected.
    let count: Int?
    let thin: Bool

    var id: String { district.rawValue }
    var bucket: Int { DistrictComparison.bucket(pct) }
}

enum DistrictComparison {

    /// Bucket edges in percent. Chosen from the real spread rather than picked
    /// out of the air: across all 432 sector × district cells the median absolute
    /// difference from the national mean is 13.3%, p75 is 21.3% and p90 is 32.0%,
    /// so ±5 / ±15 / ±30 puts roughly a tenth of cells in each extreme bucket and
    /// keeps the middle of the map from collapsing into one flat colour.
    ///
    /// The scale is clamped at the ends on purpose. Arts in Setúbal is +187.7%
    /// against the national arts mean, which is a real figure on 2,343 workers
    /// (professional sport sits in CAE R), but letting one cell set the scale
    /// would flatten every other district into the midpoint.
    static let edges: [Double] = [-30, -15, -5, 5, 15, 30]

    /// 0 = furthest below, 3 = within ±5% of the baseline, 6 = furthest above.
    static func bucket(_ pct: Double) -> Int {
        var i = 0
        while i < edges.count && pct >= edges[i] { i += 1 }
        return i
    }

    /// Every district, sorted by pay, highest first.
    static func readings(sector: Sector?, baseline: Double) -> [DistrictReading] {
        guard baseline > 0 else { return [] }
        return District.allCases.compactMap { district -> DistrictReading? in
            guard let mean = DistrictDataset.mean(sector: sector, district: district) else { return nil }
            return DistrictReading(
                district: district,
                mean: mean,
                pct: 100 * (mean - baseline) / baseline,
                count: DistrictDataset.count(sector: sector, district: district),
                thin: DistrictDataset.isThin(sector: sector, district: district)
            )
        }
        .sorted { $0.mean > $1.mean }
    }

    /// Signed percentage, always with an explicit sign so "+0%" and "0%" cannot
    /// be confused with a missing value.
    static func formatted(_ pct: Double) -> String {
        let rounded = (pct * 10).rounded() / 10
        if abs(rounded) < 0.05 { return "0%" }
        return String(format: "%+.0f%%", rounded)
    }
}
