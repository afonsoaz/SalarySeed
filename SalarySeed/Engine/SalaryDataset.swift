import Foundation

/// Real Portuguese salary data, v0.4. All values in gross € per month.
///
/// This file is the single home for every published number the app uses.
/// Engines read from here; nothing in the UI hardcodes data.
///
/// Sources (all open data, commercial use OK with attribution):
/// - [QP]  GEP-MTSSS, Quadros de Pessoal, October 2024, Continente
///         (qp2024pub.xlsx, parsed by parse_qp2024.py). "Ganho médio mensal"
///         = base pay + regular subsidies + overtime. Private-sector employees.
///         National mean: €1,582.74, consistent across Quadros 105, 113, 114,
///         138 and the GEP síntese. Occupation, education, age and region
///         cells all come from this workbook.
/// - [SES] INE, Inquérito à Estrutura dos Ganhos 2022 (Eurostat: earn_ses_monthly,
///         earn_ses22_23; geo=PT, NACE B-S excl. O, firms with 10+ employees).
///         Full-time monthly earnings, Oct 2022: D1 €814, median €1,099,
///         D9 €2,612, mean €1,483. Education means: see below.
/// - [DMR] INE, remuneração bruta mensal média por trabalhador (Social Security
///         DMR + CGA). Annual means, total remuneration: 2022 €1,412,
///         2024 €1,604, 2025 €1,694. Used for level checks and future uprating.
///
/// Model notes (kept deliberately simple, documented in README):
/// - National curve: two-piece log-normal. Shape (sigma below / above the
///   median) comes from SES 2022 decile ratios; the median level is set at the
///   QP Oct 2024 concept: QP mean × SES median/mean ratio = 1582.74 × 0.7411.
/// - Cohort cells store the published mean and derive a model median with the
///   log-normal identity median = mean × exp(-sigma²/2), the same sigma the
///   percentile model uses. Self-consistent, no extra fitted constants.
/// - Everything is anchored to October 2024 (the latest QP wave) so that the
///   national bar and the cohort bars are comparable. Salaries have grown
///   since (DMR: +5.6% in 2025); percentiles are therefore slightly generous.
enum SalaryDataset {

    // MARK: National distribution [SES shape × QP level]

    /// Reference period for all percentile math in the app.
    static let referenceYear = 2024

    /// Derived national median, QP ganho concept, Oct 2024.
    static let nationalMedian: Double = 1_173

    /// Log-normal sigma below the median. From SES 2022: ln(1099/814)/z90.
    static let sigmaLow: Double = 0.2342

    /// Log-normal sigma above the median. From SES 2022: ln(2612/1099)/z90.
    static let sigmaHigh: Double = 0.6755

    /// Published SES 2022 anchors kept for verification and tests.
    static let ses2022 = (d1: 814.0, median: 1_099.0, d9: 2_612.0, mean: 1_483.0)

    /// QP Oct 2024 national mean ganho (GEP síntese).
    static let qpNationalMean2024: Double = 1_582.74

    // MARK: Cohort cells

    /// One published cohort figure and how the model should treat it.
    struct Cell {
        /// Published mean gross monthly ganho for the cohort.
        let mean: Double
        /// Log-normal dispersion used for within-cohort percentiles.
        let sigma: Double
        /// Small sample or grouped category. The UI shows a caveat chip.
        let thin: Bool

        init(mean: Double, sigma: Double, thin: Bool = false) {
            self.mean = mean
            self.sigma = sigma
            self.thin = thin
        }

        /// Model median, log-normal identity. Same sigma as the percentile
        /// model, so the cohort bar and its median tick never disagree.
        var median: Double { mean * exp(-sigma * sigma / 2) }
    }

    // MARK: Sector [QP Oct 2024, Quadro 104: ganho médio by CAE × antiguidade]

    /// Overall mean gross monthly (ganho médio) per sector, used when tenure is
    /// unknown. GEP Quadros de Pessoal, Oct 2024, Quadro 104 (TOTAL column).
    static let sectorTotalMean: [Sector: Double] = [
        .agriculture: 1210.12, .extractive: 2021.23, .manufacturing: 1521.41,
        .energy: 3320.84, .water: 1478.51, .construction: 1336.73,
        .autoTrade: 1351.55, .wholesale: 1769.01, .retail: 1317.08,
        .transport: 1856.47, .hospitality: 1125.34, .media: 2262.35,
        .telecom: 2449.54, .it: 2628.75, .finance: 2718.0, .realEstate: 1535.48,
        .consulting: 1980.2, .admin: 1367.59, .publicAdmin: 1479.66,
        .education: 1682.53, .health: 1712.74, .socialWork: 1125.87,
        .arts: 2222.99, .otherServices: 1356.2,
    ]

    /// Mean gross monthly per sector × tenure band. Six values per sector, in the
    /// GEP "escalão de antiguidade" order: <1, 1-4, 5-9, 10-14, 15-19, 20+ years.
    /// Source: GEP Quadros de Pessoal, Oct 2024, Quadro 104.
    static let sectorTenureMean: [Sector: [Double]] = [
        .agriculture: [1131.83, 1200.88, 1242.7, 1273.28, 1338.8, 1346.85],
        .extractive: [1747.09, 1950.12, 1957.4, 2349.12, 2337.34, 2165.24],
        .manufacturing: [1343.11, 1409.87, 1485.24, 1566.44, 1684.77, 1767.74],
        .energy: [2405.17, 2929.42, 2696.98, 3372.6, 3875.47, 4149.32],
        .water: [1229.57, 1303.73, 1390.48, 1545.14, 1738.47, 2014.81],
        .construction: [1208.09, 1293.61, 1370.48, 1430.54, 1543.3, 1689.99],
        .autoTrade: [1189.44, 1270.64, 1356.87, 1427.75, 1547.97, 1585.92],
        .wholesale: [1488.26, 1642.36, 1724.76, 1885.84, 2035.72, 2152.63],
        .retail: [1152.68, 1246.37, 1343.96, 1419.85, 1477.37, 1515.73],
        .transport: [1379.2, 1561.54, 1764.14, 1959.51, 2394.48, 2527.4],
        .hospitality: [1052.84, 1099.64, 1191.17, 1242.55, 1291.69, 1390.88],
        .media: [1946.64, 2198.96, 2154.66, 2186.45, 2365.2, 2671.84],
        .telecom: [1722.25, 2156.89, 2552.31, 2323.42, 2805.6, 2910.71],
        .it: [2418.85, 2580.53, 2767.77, 2969.68, 3087.25, 3226.07],
        .finance: [2140.86, 2417.09, 2672.93, 2773.49, 2730.86, 3151.46],
        .realEstate: [1387.29, 1492.63, 1572.88, 1549.0, 1915.54, 2048.04],
        .consulting: [1786.98, 1974.99, 1971.13, 2179.52, 2294.72, 2239.97],
        .admin: [1225.7, 1384.59, 1414.26, 1544.89, 1587.08, 1847.93],
        .publicAdmin: [1305.87, 1337.2, 1421.96, 1557.72, 1529.6, 1876.91],
        .education: [1458.13, 1605.75, 1699.23, 1732.2, 1772.38, 1911.75],
        .health: [1375.79, 1478.63, 1803.34, 2131.63, 2078.2, 1935.73],
        .socialWork: [1030.75, 1045.86, 1094.19, 1166.33, 1218.41, 1289.77],
        .arts: [2256.89, 2440.9, 2029.23, 1878.96, 1852.68, 2055.72],
        .otherServices: [1182.25, 1251.71, 1349.09, 1415.87, 1491.72, 1679.08],
    ]

    /// Within-cell dispersion for the log-normal percentile model. The crossed
    /// sector×tenure cell is narrower (both fixed) than a sector taken whole.
    static let sectorSigma = 0.55
    static let sectorTenureSigma = 0.50

    /// Build the cohort cell for a sector, optionally crossed with a tenure band.
    /// Falls back to the sector total when tenure is unknown.
    static func sectorCell(_ sector: Sector, tenure: TenureBand?) -> Cell {
        if let tb = tenure, let arr = sectorTenureMean[sector], tb.index < arr.count {
            return Cell(mean: arr[tb.index], sigma: sectorTenureSigma)
        }
        if let m = sectorTotalMean[sector] {
            return Cell(mean: m, sigma: sectorSigma)
        }
        return Cell(mean: qpNationalMean2024, sigma: sectorSigma)
    }

    // MARK: Education [QP Oct 2024, Quadro 105, count-weighted aggregates]

    /// GEP-MTSSS, Quadros de Pessoal, Oct 2024 ganho médio by habilitação
    /// (Quadro 105 TOTAL row), aggregated to the app's four levels with
    /// worker-count weights from Quadro 39. See parse_qp2024.py.
    /// basic = up to 3º ciclo; postSecondary = pós-secundário + CTeSP
    /// (0.9% of workers, thin); higher = bacharelato through doutoramento.
    static let education: [EducationLevel: Cell] = [
        .basic:         Cell(mean: 1_206.8, sigma: 0.55),
        .secondary:     Cell(mean: 1_378.7, sigma: 0.55),
        .postSecondary: Cell(mean: 1_542.0, sigma: 0.55, thin: true),
        .higher:        Cell(mean: 2_364.8, sigma: 0.55),
    ]

    // MARK: Age [QP Oct 2024, Quadro 138, Continente row]

    /// under25 is the count-weighted aggregate of <18 and 18-24 (Quadro 39
    /// weights). 65+ is 2.0% of workers, so it keeps the thin flag.
    static let age: [AgeBand: Cell] = [
        .under25:    Cell(mean: 1_191.9, sigma: 0.50),
        .band25to34: Cell(mean: 1_459.8, sigma: 0.50),
        .band35to44: Cell(mean: 1_645.5, sigma: 0.50),
        .band45to54: Cell(mean: 1_722.6, sigma: 0.50),
        .band55to64: Cell(mean: 1_600.2, sigma: 0.50),
        .over65:     Cell(mean: 1_651.2, sigma: 0.50, thin: true),
    ]

    // MARK: Region [QP Oct 2024, Quadro 114, NUTS II 2024]

    /// The publication covers Continente only. Açores and Madeira have no
    /// cells yet; the pickers hide them until their data lands.
    static let region: [PTRegion: Cell] = [
        .norte:         Cell(mean: 1_474.7, sigma: 0.50),
        .centro:        Cell(mean: 1_410.9, sigma: 0.50),
        .oesteValeTejo: Cell(mean: 1_346.6, sigma: 0.50),
        .grandeLisboa:  Cell(mean: 1_935.7, sigma: 0.50),
        .penSetubal:    Cell(mean: 1_545.4, sigma: 0.50),
        .alentejo:      Cell(mean: 1_409.5, sigma: 0.50),
        .algarve:       Cell(mean: 1_320.2, sigma: 0.50),
    ]
}
