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

    // MARK: Occupation [QP Oct 2024, Quadro 113, CPP major groups]

    /// GEP-MTSSS, Quadros de Pessoal, Oct 2024 ganho médio by profissão
    /// (Quadro 113). CPP group 6, agriculture, is not offered in the
    /// picker: €1,167.21.
    static let occupation: [OccupationGroup: Cell] = [
        .managers:       Cell(mean: 3_295.85, sigma: 0.60),
        .specialists:    Cell(mean: 2_400.04, sigma: 0.60),
        .technicians:    Cell(mean: 1_947.34, sigma: 0.60),
        .administrative: Cell(mean: 1_391.17, sigma: 0.60),
        .services:       Cell(mean: 1_162.67, sigma: 0.60),
        .trades:         Cell(mean: 1_246.38, sigma: 0.60),
        .operators:      Cell(mean: 1_341.97, sigma: 0.60),
        .elementary:     Cell(mean: 1_058.48, sigma: 0.60),
    ]

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
