import Foundation

/// ⚠️ MOCK COHORT DATA — illustrative medians only (v0.2).
///
/// The data SHAPE matches how GEP/MTSSS "Quadros de Pessoal" publishes cells
/// (dados.gov.pt, CC BY 4.0 — commercial use OK with attribution): one cell per
/// one-dimensional cut = (median gross €/month, dispersion, small-sample flag).
/// Swapping these mock values for the real published ones is a data change,
/// not a UI change. Covers private-sector employees only (no civil servants,
/// no self-employed) — say so in the UI where it matters.
struct CohortCell {
    /// Median gross monthly salary for the cohort (mock value).
    let median: Double
    /// Log-normal dispersion around the median (mock value).
    let sigma: Double
    /// True when the underlying sample is small → show "rough estimate" in UI.
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
    let thin: Bool             // small sample → "rough estimate"
    /// Beyond p3/p97 the model is extrapolating → soften the claim.
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

/// One comparison dimension: metadata + how to read/write it on the store.
struct CompareDimension: Identifiable {
    let id: String
    let icon: String            // SF Symbol
    let shortName: String       // "Age"
    let rowTitle: String        // "Vs. people your age"
    let sheetTitle: String
    let sheetNote: String?
    let unlockHint: String      // compareSeed locked row
    let profileHint: String     // profileSeed locked row
    let options: [DimensionOption]
    let selectedID: (SalaryStore) -> String?
    let select: (SalaryStore, String?) -> Void
    let cohortWord: (String) -> String   // option label → "25–34 year olds"
    let cell: (String) -> CohortCell?

    func selectedOption(in store: SalaryStore) -> DimensionOption? {
        guard let id = selectedID(store) else { return nil }
        return options.first { $0.id == id }
    }

    static let all: [CompareDimension] = [
        CompareDimension(
            id: "age",
            icon: "person.crop.circle.badge.clock",
            shortName: "Age",
            rowTitle: "Vs. people your age",
            sheetTitle: "How old are you?",
            sheetNote: nil,
            unlockHint: "Add your age",
            profileHint: "Unlocks: percentile vs. your age group",
            options: AgeBand.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label) },
            selectedID: { $0.ageBand?.rawValue },
            select: { store, id in store.ageBand = id.flatMap(AgeBand.init(rawValue:)) },
            cohortWord: { "\($0) year olds" },
            cell: { AgeBand(rawValue: $0)?.cohort }
        ),
        CompareDimension(
            id: "region",
            icon: "map",
            shortName: "Region",
            rowTitle: "Vs. your region",
            sheetTitle: "Where do you work?",
            sheetNote: "NUTS II regions",
            unlockHint: "Add your region",
            profileHint: "Unlocks: regional comparison",
            options: PTRegion.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label) },
            selectedID: { $0.region?.rawValue },
            select: { store, id in store.region = id.flatMap(PTRegion.init(rawValue:)) },
            cohortWord: { $0 },
            cell: { PTRegion(rawValue: $0)?.cohort }
        ),
        CompareDimension(
            id: "education",
            icon: "graduationcap",
            shortName: "Education",
            rowTitle: "Vs. your education level",
            sheetTitle: "Your highest education?",
            sheetNote: nil,
            unlockHint: "Add your education",
            profileHint: "Unlocks: qualification comparison",
            options: EducationLevel.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label) },
            selectedID: { $0.education?.rawValue },
            select: { store, id in store.education = id.flatMap(EducationLevel.init(rawValue:)) },
            cohortWord: { $0 },
            cell: { EducationLevel(rawValue: $0)?.cohort }
        ),
        CompareDimension(
            id: "occupation",
            icon: "briefcase",
            shortName: "Profession",
            rowTitle: "Vs. your profession",
            sheetTitle: "What kind of work do you do?",
            sheetNote: "Broad occupation groups",
            unlockHint: "Add your profession",
            profileHint: "Unlocks: 'people like you' benchmark",
            options: OccupationGroup.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label) },
            selectedID: { $0.occupation?.rawValue },
            select: { store, id in store.occupation = id.flatMap(OccupationGroup.init(rawValue:)) },
            cohortWord: { $0 },
            cell: { OccupationGroup(rawValue: $0)?.cohort }
        ),
    ]
}
