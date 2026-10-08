import Foundation

/// v1.5: a job offer as the reader entered it, kept the way the store keeps the
/// salary. The amount is per paid month whatever way it was typed, gross or
/// net, and `inputYearly` only remembers how it was entered so the form reopens
/// the same way.
///
/// KEPT ON THE PHONE, AND THAT WAS A DECISION. Grow's scenario is never saved,
/// under "recording is not exploring": a hypothetical that outlived a relaunch
/// would start behaving like a fact about the reader. An offer is a different
/// kind of thing. It IS a fact, one the reader holds (a company offered this),
/// and it can take days to weigh. So the last one is kept until it is removed
/// or replaced. What stays true from the old rule is the part that mattered:
/// it is never mixed into the reader's own answers. Home, Tax, Compare in
/// Portugal and Europe, and Grow go on describing the job they have, and only
/// the offer screen reads this.
///
/// Its place and sector are stored as the concrete município and sector, not as
/// "same as mine". They are facts about the job, and an offer in Porto does not
/// move to Faro because its reader later did.
struct OfferTerms: Equatable {
    /// Per paid month, like `SalaryStore.amount`.
    var amount: Double
    var kind: AmountKind
    var schedule: PaySchedule
    var inputYearly: Bool
    /// Meal allowance and ajudas de custo, a month, the profile's own bucket.
    var ajudasMonthly: Double
    var sector: Sector?
    var concelhoID: String?
    /// Shown, never counted, as the profile treats `variableAnnual`.
    var bonusAnnual: Double?

    var concelho: Concelho? { ConcelhoCatalog.concelho(concelhoID) }
    var region: PTRegion? { concelho?.region }
    /// No município means Continente, the same safe-direction assumption the
    /// store makes for the reader, and the screen says so.
    var taxRegion: TaxEngine.TaxRegion { region?.taxRegion ?? .continente }
    var taxRegionAssumed: Bool { concelho == nil }
}

extension SalaryStore {

    /// The person an offer is weighed by. Everything here is the reader's own
    /// and identical on both sides.
    var offerPerson: OfferComparison.Person {
        OfferComparison.Person(
            marital: maritalSituation,
            dependents: dependents,
            jovemExemption: irsJovemExemption,
            ageBand: ageBand,
            education: education
        )
    }

    /// The job the reader has, read off the same `breakdown` Home draws, so the
    /// offer screen's "now" is Home's figure and not a recomputation of it.
    var currentJob: OfferComparison.Job {
        let b = breakdown
        return OfferComparison.Job(
            grossMonthly: b.grossMonthly,
            months: b.months,
            ajudasMonthly: b.ajudasMonthly,
            taxRegion: taxRegion,
            region: region,
            sector: sector
        )
    }

    /// An offer resolved to a gross per payment. A net offer is turned into
    /// gross on every read with the reader's household and the offer's own
    /// table, exactly as a net salary is.
    func offerJob(_ terms: OfferTerms) -> OfferComparison.Job {
        let months = terms.schedule.months
        let gross: Double
        switch terms.kind {
        case .gross:
            gross = terms.amount
        case .net:
            gross = TaxEngine.grossFromNet(
                terms.amount,
                marital: maritalSituation,
                dependents: dependents,
                jovemExemption: irsJovemExemption,
                months: months,
                region: terms.taxRegion
            )
        }
        return OfferComparison.Job(
            grossMonthly: gross,
            months: months,
            ajudasMonthly: terms.ajudasMonthly,
            taxRegion: terms.taxRegion,
            region: terms.region,
            sector: terms.sector
        )
    }

    /// Recomputed on every read and never stored. Only the terms are kept.
    func offerComparison(_ terms: OfferTerms) -> OfferComparison.Result {
        OfferComparison.compare(
            now: currentJob,
            offer: offerJob(terms),
            person: offerPerson,
            staying: growthContext
        )
    }
}
