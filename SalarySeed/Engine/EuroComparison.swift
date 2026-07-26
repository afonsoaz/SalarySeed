import Foundation

/// v0.11: turns the SES table into what the Europe grid draws.
///
/// THE METHOD, WHICH IS THE WHOLE POINT. GEP and Eurostat measure different
/// populations in different years under different definitions, so their levels
/// cannot be compared. The only thing allowed across the boundary is a RATIO
/// computed entirely inside Eurostat, country over Portugal, both cells from the
/// same table. That ratio is then applied to the user's own salary. No GEP figure
/// ever touches this calculation, and the euro amounts published by Eurostat are
/// never shown next to a Portuguese salary as though they were the same quantity.
///
/// WHAT THE RESULT IS NOT. A section average is not a job. "Information and
/// communication" holds a telecoms field technician and a principal engineer in
/// one number. The screen says "pay in your sector runs X% higher there", never
/// "you would earn this", and the difference is not cosmetic.
struct EuroReading: Identifiable {
    let country: Country
    /// Mean gross monthly for the section, in the chosen unit. nil = no cell.
    let mean: Double?
    /// Difference from Portugal in the same unit, in percent. nil when either
    /// end of the comparison is missing.
    let pct: Double?
    /// The user's own gross moved by the ratio. nil without a salary or a ratio.
    let yourSalary: Double?

    var id: String { country.rawValue }
    var isPortugal: Bool { country == .portugal }
    var hasData: Bool { mean != nil }
    var bucket: Int? { pct.map(EuroComparison.bucket) }
}

enum EuroComparison {

    /// Bucket edges in percent, and the reason they are not the map's.
    ///
    /// mapSeed uses ±5 / ±15 / ±30, tuned to Portuguese districts where the
    /// median absolute difference is 13.3%. Across Europe the median is 46.9% in
    /// euros and the maximum is 384%, so those edges put 56% of all cells in the
    /// single top bucket and the grid would be one flat colour.
    ///
    /// These edges are RECIPROCAL PAIRS rather than symmetric percentages,
    /// because this is a ratio scale: -40% is 0.60x and +67% is 1.67x, and 0.60 x
    /// 1.67 = 1. Likewise -20% / +25% is 0.80 and 1.25, and the neutral band
    /// -5% / +5% is kept identical to the Portuguese map so the two read the same
    /// way. Percentages look lopsided; the factors behind them are not.
    ///
    /// The lowest bucket stays nearly empty, and that is the finding rather than
    /// a flaw: in most sectors almost every EU country pays above Portugal, so
    /// the red arm of a ramp centred on Portugal has very little to hold.
    static let edges: [Double] = [-40, -20, -5, 5, 25, 67]

    /// 0 = furthest below Portugal, 3 = within ±5%, 6 = furthest above.
    static func bucket(_ pct: Double) -> Int {
        var i = 0
        while i < edges.count && pct >= edges[i] { i += 1 }
        return i
    }

    /// Every EU country for one section, sorted by pay, highest first, with the
    /// ones that have no cell at the end so the list never opens on a gap.
    static func readings(section: EuroSection,
                         purchasingPower: Bool,
                         yourGross: Double?) -> [EuroReading] {
        let portugal = EuroDataset.mean(section: section, country: .portugal,
                                        purchasingPower: purchasingPower)
        return Country.allCases.map { country -> EuroReading in
            let mean = EuroDataset.mean(section: section, country: country,
                                        purchasingPower: purchasingPower)
            var pct: Double?
            var moved: Double?
            if let mean, let portugal, portugal > 0 {
                pct = 100 * (mean - portugal) / portugal
                if let yourGross, yourGross > 0 {
                    moved = yourGross * (mean / portugal)
                }
            }
            return EuroReading(country: country, mean: mean, pct: pct, yourSalary: moved)
        }
        .sorted { a, b in
            switch (a.mean, b.mean) {
            case let (x?, y?): return x > y
            case (nil, _): return false
            case (_, nil): return true
            }
        }
    }

    /// Where Portugal sits among the countries that have a cell. Returned as
    /// (place, outOf) so the copy can say 26 of 27 rather than a bare number
    /// whose denominator the reader has to guess.
    static func portugalRank(in readings: [EuroReading]) -> (place: Int, outOf: Int)? {
        let withData = readings.filter(\.hasData)
        guard let index = withData.firstIndex(where: \.isPortugal) else { return nil }
        return (index + 1, withData.count)
    }

    /// Signed percentage with an explicit sign, so "+0%" and a missing value can
    /// never be confused. Same rule and the same rounding threshold as the
    /// Portuguese map, so the two screens format identically.
    static func formatted(_ pct: Double) -> String {
        if abs(pct) < 0.5 { return "0%" }
        return String(format: "%+.0f%%", pct)
    }

    /// True when several of the app's sectors share this section, so the screen
    /// can say which ones got merged instead of silently widening the question.
    static func sectorsSharing(_ section: EuroSection) -> [Sector] {
        Sector.allCases.filter { $0.euroSection == section }
    }
}
