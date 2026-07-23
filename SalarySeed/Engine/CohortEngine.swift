import Foundation

/// Cohort comparisons from real data (v0.4). Values live in SalaryDataset;
/// this file is the model plus the UI-facing dimension descriptors.
///
/// Each one-dimensional cut is a SalaryDataset.Cell: the published mean ganho,
/// a dispersion, and a caveat flag. Percentile within a cohort is modelled
/// log-normal around the cell's model median. Covers employees only (no
/// self-employed); the UI says so where it matters.
typealias CohortCell = SalaryDataset.Cell

/// A computed comparison against one cohort.
struct CohortResult {
    let percentile: Int        // 1…99
    let median: Double
    let thin: Bool             // small sample or grouped category, show the chip
    /// Beyond p3/p97 the model is extrapolating, so soften the claim.
    var edge: Bool { percentile < 3 || percentile > 97 }
}

enum CohortEngine {
    static let referenceYear = SalaryDataset.referenceYear
    static let sourceLine = "Fontes: GEP-MTSSS, Quadros de Pessoal, out. 2024 · INE, Estrutura dos Ganhos 2022"

    /// Percentile within a cohort, modelled log-normal around the cell median.
    static func result(grossMonthly: Double, cell: CohortCell) -> CohortResult {
        let pct: Int
        if grossMonthly > 0 && cell.median > 0 {
            let z = log(grossMonthly / cell.median) / cell.sigma
            pct = min(99, max(1, Int((PercentileEngine.normCdf(z) * 100).rounded())))
        } else {
            pct = 1
        }
        return CohortResult(percentile: pct, median: cell.median, thin: cell.thin)
    }
}

// MARK: - Cell lookups per dimension

extension AgeBand {
    var cohort: CohortCell? { SalaryDataset.age[self] }
}

extension PTRegion {
    var cohort: CohortCell? { SalaryDataset.region[self] }
}

extension EducationLevel {
    var cohort: CohortCell? { SalaryDataset.education[self] }
}

extension OccupationGroup {
    var cohort: CohortCell? { SalaryDataset.occupation[self] }
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

    /// Only dimensions that have real data ship. A dimension whose dataset
    /// table is empty (no published cells yet) stays out of the pickers and
    /// compare layers, and comes back the moment its data lands.
    static let all: [CompareDimension] = allDefined.filter { dim in
        dim.options(false).contains { dim.cell($0.id) != nil }
    }

    private static let allDefined: [CompareDimension] = [
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
            // Only regions with published cells appear (Açores and Madeira
            // stay hidden until their data lands; QP covers Continente).
            options: { _ in PTRegion.allCases.filter { $0.cohort != nil }.map { DimensionOption(id: $0.rawValue, label: $0.label) } },
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
