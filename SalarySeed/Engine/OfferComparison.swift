import Foundation

/// v1.5: offerSeed, a job offer put next to the job the reader has.
///
/// WHAT IT ANSWERS, in the order the screen asks it: what reaches you under
/// each, where the difference goes in tax, where each sits against other
/// people, and what staying where you are would pay instead.
///
/// A DIFFERENT JOB, THE SAME PERSON. The principle `SalaryExplorerSheet` set
/// for a typed number, carried over: an offer changes the job (its pay, its
/// payments, its place, its sector, its allowance) and never the person. Marital
/// situation, dependants, IRS Jovem, age band and education are the reader's own
/// on both sides, which is why they arrive once, as `Person`, and not per job.
///
/// PAY IS COMPARED ON A YEAR. Twelve and fourteen payments make two monthly
/// figures incomparable: the same year's pay is a bigger number paid in twelve.
/// So every difference here is a yearly one, and the only per-payment figure
/// that survives is the one the percentiles take, because that is the quantity
/// GEP publishes.
///
/// NOTHING HERE IS NEW MATHS. Tax is `TaxEngine`, the percentiles are
/// `PercentileEngine` and `CohortEngine`, and staying is
/// `GrowthEngine.baselineTrack`, so this file can only disagree with another
/// screen by asking a different question, never by computing the same one
/// differently. `tools/offer_probe` sweeps it to make sure.
enum OfferComparison {

    // MARK: Inputs

    /// One side of the comparison, resolved to what the engines take.
    struct Job: Equatable {
        /// Gross per payment.
        let grossMonthly: Double
        /// 12 or 14.
        let months: Double
        /// Meal allowance and ajudas de custo, a month, paid twelve times a
        /// year, as the profile keeps them. No IRS, no Social Security.
        let ajudasMonthly: Double
        let taxRegion: TaxEngine.TaxRegion
        /// NUTS II, for the regional cohort. nil when the place is unknown.
        let region: PTRegion?
        let sector: Sector?
    }

    /// The person. An offer never changes any of this.
    struct Person: Equatable {
        let marital: MaritalSituation
        let dependents: Int
        let jovemExemption: Double
        let ageBand: AgeBand?
        let education: EducationLevel?
    }

    // MARK: Output

    /// A year of one job, with the IRS that is actually owed rather than the
    /// monthly advance on it. For the same yearly gross, twelve and fourteen
    /// payments withhold differently and settle identically, so a year read off
    /// the withholding would show a schedule difference posing as a tax one.
    struct Year {
        let gross: Double
        let socialSecurity: Double
        let irs: Double
        let allowance: Double
        let employerCost: Double

        init(_ b: SalaryBreakdown) {
            gross = b.grossYearly
            socialSecurity = b.employeeSSMonthly * b.months
            irs = b.annualIRSSettled
            allowance = b.ajudasYearly
            employerCost = b.employerCostYearly
        }

        /// Gross less Social Security less settled IRS. The allowance is not in
        /// it, because it was never taxed to begin with.
        var afterTax: Double { gross - socialSecurity - irs }

        /// The year as the offer screen prints it: whole euros that add up,
        /// on the same footing as Tax's waterfall (`WaterfallRows`). Rounded one
        /// by one, gross less Social Security less IRS missed "after tax" by a
        /// euro for about a quarter of salaries. Gross and after tax are rounded
        /// on their own; Social Security and IRS share the difference.
        /// `tools/offer_probe` checks that the rows add up.
        var shown: Shown {
            let g = WaterfallRows.whole(gross)
            let after = WaterfallRows.whole(afterTax)
            let (ss, tax) = WaterfallRows.split(socialSecurity, irs, into: g - after)
            return Shown(gross: g, socialSecurity: ss, irs: tax, afterTax: after,
                         employerCost: WaterfallRows.whole(employerCost))
        }

        struct Shown {
            let gross, socialSecurity, irs, afterTax, employerCost: Double
        }
    }

    /// Where a salary sits in one cohort, now and with the offer. Either side can
    /// be missing on its own: an island has no regional cell, and a reader who
    /// never gave a sector has no sector to be placed in.
    struct Standing {
        let now: CohortResult?
        let offer: CohortResult?
        var thin: Bool { now?.thin == true || offer?.thin == true }
    }

    /// Staying at the current employer, against taking the offer.
    struct Staying {
        struct Row: Identifiable {
            let years: Int
            /// What staying pays then, gross per payment.
            let stayingGross: Double
            /// The offer's total minus staying's, gross, every year from the
            /// first to `years` added up, each side on its own payments. Year 0
            /// is today and is not counted, as in Grow.
            let totalDelta: Double
            var id: Int { years }
        }

        let rows: [Row]
        let todayGross: Double
        let nowMonths: Double
        let offerGross: Double
        let offerMonths: Double
        /// The offer pays more over a year than the reader earns now.
        let offerAhead: Bool
        /// The first year in which staying pays at least as much as the offer
        /// over a year. nil when the offer is not ahead to begin with, or when
        /// staying does not get there within the last row.
        let catchUpYear: Int?
        /// The year this path reaches the last band, 20 years at the company,
        /// when that happens early enough for two rows to repeat the same
        /// figure. The screen owes the reader the reason for the repeat.
        let flatFrom: Int?
        /// The path itself goes down somewhere, which ten sectors' tables do.
        let falls: Bool
        let sector: Sector
        let startTenure: Int
    }

    struct Result {
        let nowJob: Job
        let offerJob: Job
        let now: SalaryBreakdown
        let offer: SalaryBreakdown
        /// Of each extra euro of gross a year, the share left once Social
        /// Security and the settled IRS are paid. nil when the gross differs by
        /// less than €10 a month, where the ratio is noise, and when the two
        /// jobs are taxed on different tables, where it would mix a raise with
        /// a move and could even come out above one.
        let keepRate: Double?
        let national: (now: Double, offer: Double)
        /// Each salary in its own sector, against everybody in it whatever
        /// their time at the company. NOT the tenure band: at a new job your
        /// time there starts at zero, and the under-one-year band is mostly first
        /// jobs, so it would flatter every offer.
        let sector: Standing?
        /// Each salary in its own NUTS II region.
        let region: Standing?
        /// The reader's own age band and education, which do not move.
        let age: Standing?
        let education: Standing?
        let staying: Staying?

        var nowYear: Year { Year(now) }
        var offerYear: Year { Year(offer) }
        var sameTaxTable: Bool { nowJob.taxRegion == offerJob.taxRegion }
        var schedulesDiffer: Bool { nowJob.months != offerJob.months }
    }

    // MARK: The comparison

    /// The horizons staying is read at. Grow's own, read from there rather than
    /// restated, so the two screens look ahead over the same spans. Five is the
    /// shortest that always shows something: no band below twenty is wider than
    /// five years, so five more years crosses a band for anybody under twenty.
    static let horizons = GrowthEngine.Scenario.horizons

    /// Below this, a yearly gross difference is noise for the keep rate.
    static let keepRateFloor: Double = 120

    static func compare(now: Job,
                        offer: Job,
                        person: Person,
                        staying ctx: GrowthEngine.Context?) -> Result {
        let nowB = breakdown(now, person)
        let offerB = breakdown(offer, person)
        let nowYear = Year(nowB)
        let offerYear = Year(offerB)

        let grossDelta = offerYear.gross - nowYear.gross
        let keep: Double? = (now.taxRegion == offer.taxRegion && abs(grossDelta) >= keepRateFloor)
            ? (offerYear.afterTax - nowYear.afterTax) / grossDelta
            : nil

        return Result(
            nowJob: now,
            offerJob: offer,
            now: nowB,
            offer: offerB,
            keepRate: keep,
            national: (PercentileEngine.percentile(grossMonthly: now.grossMonthly),
                       PercentileEngine.percentile(grossMonthly: offer.grossMonthly)),
            sector: standing(now.grossMonthly, now.sector.map { SalaryDataset.sectorCell($0, tenure: nil) },
                             offer.grossMonthly, offer.sector.map { SalaryDataset.sectorCell($0, tenure: nil) }),
            region: standing(now.grossMonthly, now.region?.cohort,
                             offer.grossMonthly, offer.region?.cohort),
            age: person.ageBand?.cohort.flatMap { cell in
                standing(now.grossMonthly, cell, offer.grossMonthly, cell)
            },
            education: person.education?.cohort.flatMap { cell in
                standing(now.grossMonthly, cell, offer.grossMonthly, cell)
            },
            staying: ctx.flatMap { staying(ctx: $0, offer: offer) }
        )
    }

    static func breakdown(_ job: Job, _ person: Person) -> SalaryBreakdown {
        TaxEngine.breakdown(
            grossMonthly: job.grossMonthly,
            months: job.months,
            ajudasMonthly: job.ajudasMonthly,
            marital: person.marital,
            dependents: person.dependents,
            jovemExemption: person.jovemExemption,
            region: job.taxRegion
        )
    }

    private static func standing(_ nowGross: Double, _ nowCell: CohortCell?,
                                 _ offerGross: Double, _ offerCell: CohortCell?) -> Standing? {
        guard nowCell != nil || offerCell != nil else { return nil }
        return Standing(
            now: nowCell.map { CohortEngine.result(grossMonthly: nowGross, cell: $0) },
            offer: offerCell.map { CohortEngine.result(grossMonthly: offerGross, cell: $0) }
        )
    }

    // MARK: Staying

    /// Staying is Grow's baseline, every lever off, read at each horizon. The
    /// offer is a flat line at its own gross, and that is not a simplification
    /// made here: it is Grow's v0.11.1 rule, that a mover's pay changes when
    /// they negotiate and at no other time. Any other shape for the offer would
    /// let this screen contradict Grow about the same move.
    static func staying(ctx: GrowthEngine.Context, offer: Job) -> Staying? {
        guard ctx.isUsable, GrowthEngine.means(ctx.sector) != nil,
              let last = horizons.max(), last > 0 else { return nil }
        let track = GrowthEngine.baselineTrack(ctx: ctx, scenario: GrowthEngine.Scenario(horizon: last))
        guard track.points.count == last + 1 else { return nil }

        func stayingYear(_ y: Int) -> Double { (track.point(year: y)?.gross ?? 0) * ctx.months }
        let offerYear = offer.grossMonthly * offer.months
        // A euro a year, so the identical offer is "not ahead" rather than
        // ahead by a rounding error.
        let ahead = offerYear - ctx.grossToday * ctx.months > 1

        let rows: [Staying.Row] = horizons.compactMap { h in
            guard let point = track.point(year: h) else { return nil }
            let total = (1...h).reduce(0.0) { $0 + offerYear - stayingYear($1) }
            return Staying.Row(years: h, stayingGross: point.gross, totalDelta: total)
        }

        let catchUp = ahead ? (1...last).first { stayingYear($0) >= offerYear } : nil

        // Two rows repeat a figure only when the last band is reached at or
        // before the second-to-last horizon.
        let top = GrowthEngine.bandStarts.last ?? 20
        let reachesTop = max(0, Int((top - ctx.startTenure).rounded(.up)))
        let secondToLast = horizons.count >= 2 ? horizons[horizons.count - 2] : last
        let flatFrom = reachesTop <= secondToLast ? reachesTop : nil

        let falls = (1...last).contains { y in
            (track.point(year: y)?.gross ?? 0) < (track.point(year: y - 1)?.gross ?? 0) - 0.005
        }

        return Staying(
            rows: rows,
            todayGross: ctx.grossToday,
            nowMonths: ctx.months,
            offerGross: offer.grossMonthly,
            offerMonths: offer.months,
            offerAhead: ahead,
            catchUpYear: catchUp,
            flatFrom: flatFrom,
            falls: falls,
            sector: ctx.sector,
            startTenure: Int(ctx.startTenure)
        )
    }
}
