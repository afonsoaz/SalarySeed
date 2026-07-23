import Foundation

/// ⚠️ MOCK COHORT DATA. Illustrative medians only (v0.2).
///
/// The data SHAPE matches how GEP/MTSSS "Quadros de Pessoal" publishes cells
/// (dados.gov.pt, CC BY 4.0, commercial use OK with attribution): one cell per
/// one-dimensional cut = (median gross €/month, dispersion, small-sample flag).
/// Swapping these mock values for the real published ones is a data change,
/// not a UI change. Covers private-sector employees only (no civil servants,
/// no self-employed). The UI says so where it matters.
struct CohortCell {
    /// Median gross monthly salary for the cohort (mock value).
    let median: Double
    /// Log-normal dispersion around the median (mock value).
    let sigma: Double
    /// True when the underlying sample is small. The UI shows a caveat chip.
    let thin: Bool

    init(median: Double, sigma: Double, thin: Bool = false) {
        self.median = median
        self.sigma = sigma
        self.thin = thin
    }
}

/// A computed comparison against one cohort.
struct CohortResult {
    let percentile: Int        // 1…99
    let median: Double
    let thin: Bool             // small sample, show the caveat chip
    /// Beyond p3/p97 the model is extrapolating, so soften the claim.
    var edge: Bool { percentile < 3 || percentile > 97 }
}

enum CohortEngine {
    static let referenceYear = 2025
    static let sourceLine = "Fonte: GEP-MTSSS · Quadros de Pessoal · 2025"

    /// Percentile within a cohort, modelled log-normal around the cell median.
    static func result(grossMonthly: Double, cell: CohortCell) -> CohortResult {
        let pct: Int
        if grossMonthly > 0 && cell.median > 0 {
            let z = log(grossMonthly / cell.median) / cell.sigma
            pct = min(99, max(1, Int((normCdf(z) * 100).rounded())))
        } else {
            pct = 1
        }
        return CohortResult(percentile: pct, median: cell.median, thin: cell.thin)
    }

    /// Standard normal CDF.
    private static func normCdf(_ z: Double) -> Double {
        0.5 * erfc(-z / 2.0.squareRoot())
    }
}

// MARK: - Mock cells per dimension (thin = islands, smallest bands)

extension AgeBand {
    var cohort: CohortCell {
        switch self {
        case .under25: CohortCell(median: 950, sigma: 0.50, thin: true)
        case .band25to34: CohortCell(median: 1_180, sigma: 0.50)
        case .band35to44: CohortCell(median: 1_350, sigma: 0.50)
        case .band45to54: CohortCell(median: 1_380, sigma: 0.50)
        case .band55to64: CohortCell(median: 1_320, sigma: 0.50)
        case .over65: CohortCell(median: 1_250, sigma: 0.50, thin: true)
        }
    }
}

extension PTRegion {
    var cohort: CohortCell {
        switch self {
        case .norte: CohortCell(median: 1_150, sigma: 0.50)
        case .centro: CohortCell(median: 1_100, sigma: 0.50)
        case .amLisboa: CohortCell(median: 1_550, sigma: 0.50)
        case .alentejo: CohortCell(median: 1_100, sigma: 0.50, thin: true)
        case .algarve: CohortCell(median: 1_050, sigma: 0.50, thin: true)
        case .acores: CohortCell(median: 1_050, sigma: 0.50, thin: true)
        case .madeira: CohortCell(median: 1_100, sigma: 0.50, thin: true)
        }
    }
}

extension EducationLevel {
    var cohort: CohortCell {
        switch self {
        case .basic: CohortCell(median: 900, sigma: 0.55)
        case .secondary: CohortCell(median: 1_050, sigma: 0.55)
        case .postSecondary: CohortCell(median: 1_250, sigma: 0.55, thin: true)
        case .higher: CohortCell(median: 1_750, sigma: 0.55)
        }
    }
}

extension OccupationGroup {
    var cohort: CohortCell {
        switch self {
        case .managers: CohortCell(median: 2_600, sigma: 0.60)
        case .specialists: CohortCell(median: 1_900, sigma: 0.60)
        case .technicians: CohortCell(median: 1_450, sigma: 0.60)
        case .administrative: CohortCell(median: 1_100, sigma: 0.60)
        case .services: CohortCell(median: 950, sigma: 0.60)
        case .trades: CohortCell(median: 1_050, sigma: 0.60)
        case .operators: CohortCell(median: 1_000, sigma: 0.60)
        case .elementary: CohortCell(median: 870, sigma: 0.60)
        }
    }
}

// MARK: - UI-facing dimension descriptors (shared by compareSeed + profileSeed)

struct DimensionOption: Identifiable {
    let id: String
    let label: String
}

/// One comparison dimension: id, icon, and how to read/write it on the store.
/// All display text lives in `Strings` (v0.3), keyed by `id`.
struct CompareDimension: Identifiable {
    let id: String
    let icon: String                              // SF Symbol
    let options: (_ pt: Bool) -> [DimensionOption]
    let selectedID: (SalaryStore) -> String?
    let select: (SalaryStore, String?) -> Void
    let cell: (String) -> CohortCell?

    func selectedOption(in store: SalaryStore, pt: Bool) -> DimensionOption? {
        guard let id = selectedID(store) else { return nil }
        return options(pt).first { $0.id == id }
    }

    static let all: [CompareDimension] = [
        CompareDimension(
            id: "age",
            icon: "person.crop.circle.badge.clock",
            options: { _ in AgeBand.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label) } },
            selectedID: { $0.ageBand?.rawValue },
            select: { store, id in store.ageBand = id.flatMap(AgeBand.init(rawValue:)) },
            cell: { AgeBand(rawValue: $0)?.cohort }
        ),
        CompareDimension(
            id: "region",
            icon: "map",
            options: { _ in PTRegion.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label) } },
            selectedID: { $0.region?.rawValue },
            select: { store, id in store.region = id.flatMap(PTRegion.init(rawValue:)) },
            cell: { PTRegion(rawValue: $0)?.cohort }
        ),
        CompareDimension(
            id: "education",
            icon: "graduationcap",
            options: { pt in EducationLevel.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label(pt: pt)) } },
            selectedID: { $0.education?.rawValue },
            select: { store, id in store.education = id.flatMap(EducationLevel.init(rawValue:)) },
            cell: { EducationLevel(rawValue: $0)?.cohort }
        ),
        CompareDimension(
            id: "occupation",
            icon: "briefcase",
            options: { pt in OccupationGroup.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label(pt: pt)) } },
            selectedID: { $0.occupation?.rawValue },
            select: { store, id in store.occupation = id.flatMap(OccupationGroup.init(rawValue:)) },
            cell: { OccupationGroup(rawValue: $0)?.cohort }
        ),
    ]
}
