import Foundation

/// v0.13: the one row that would ever leave the phone.
///
/// Design and reasoning: `app-concept.md` §14. The short version is that the app
/// knows far more than it should send, so this type is defined by SUBTRACTION.
/// Every field has to earn its place by being able to change an aggregate. A
/// field that cannot is not neutral, it is a fingerprint bit and nothing else.
///
/// NOTHING IS SENT TODAY. There is no endpoint (`ContributionService.endpoint`
/// is nil) and no backend exists. This type is here so that the shape, the
/// coarsening and the copy that describes them are all decided and verifiable
/// before there is anywhere to send it, rather than after.
///
/// THE ONE FIELD THAT MATTERS MOST BY ITS ABSENCE is the concelho. It is the
/// app's best geographic input and the field most likely to make a row unique:
/// 278 municípios against roughly 4.9 million employed people means a 55-year-old
/// woman with a masters running finance in Bragança is one person, recognisable
/// by anyone who knows her. The concelho stays on the phone and the NUTS II
/// region goes instead. The full list of what is left out, and why, is the
/// comment at the bottom of the property list.
struct Contribution: Equatable {

    /// Bumped whenever a field is added, removed or re-coarsened. The batch job
    /// will eventually be reading rows collected under several different question
    /// sets and has to know which is which rather than inferring it from which
    /// fields happen to be null.
    static let schemaVersion = 1

    let schema: Int
    /// The pseudonymous token. See `ContributionToken`.
    let token: String
    /// Calendar year of the contribution. Together with the token this is the
    /// upsert key, so one person produces at most one row per year by
    /// construction rather than by policy.
    let year: Int

    // MARK: Pay

    /// Exact, rounded to the nearest €10. Exact because a trimmed median built
    /// on bands is not a median of anything; rounded because €2.347,63 is close
    /// to unique and €2.350 is not.
    let grossMonthly: Int
    let paySchedule: Int
    /// Whether the user typed a gross or a net figure. Rows that came in as net
    /// went through `TaxEngine.grossFromNet` and carry that model's error, so the
    /// batch job needs to be able to tell them apart.
    let kindEntered: String
    /// The net figure the user actually typed, and ONLY when they typed one.
    /// When they entered gross, the net is our own deterministic arithmetic, so
    /// sending it would be sending our answer back to ourselves. When they
    /// entered net, the pair is two genuine observations, and it is also what
    /// makes the TaxEngine consistency check possible on the way in.
    let netEntered: Int?
    let ajudasBand: String?
    let variableBand: String?

    // MARK: Job

    let sector: String?
    /// The finest-grained signal in the app and the one no published Portuguese
    /// source has. Also, in combination with everything else here, the most
    /// identifying. That tension is deliberately NOT resolved on the device,
    /// which cannot know which combinations are rare; it is resolved when the
    /// cube is built, by publishing only cells above the k threshold.
    let jobTitleID: String?
    /// Band, never exact years. The cube uses bands anyway, and a band falling
    /// back to "under 1" is enough to detect a change of employer.
    let tenureBand: String?
    let employerKind: String?
    let workSchedule: String?
    let hoursBand: String?

    // MARK: Person

    /// NUTS II, derived from the concelho on the phone. Never the concelho.
    let region: String?
    let ageBand: String?
    let education: String?
    /// Kept because measuring the pay gap is the entire point of the EU pay
    /// transparency rules, and "prefer not to say" is a real answer rather than
    /// a missing one.
    let gender: String?

    // WHAT THE APP KNOWS AND THIS TYPE DELIBERATELY DOES NOT CARRY. Written down
    // rather than left implicit, because the reason each one is missing is not
    // obvious from its absence, and the next person to add a field needs to be
    // able to tell an oversight from a decision.
    //
    // - name: asked on the welcome screen precisely because it never leaves.
    // - concelho: the largest re-identification lever in the whole profile.
    // - maritalSituation, dependents: they move net, not gross, and the cube is
    //   about gross. Pure identification with zero analytic return.
    // - irsJovemExemption: tax-side only, and a sharp age proxy sitting on top of
    //   the age band that is already here.
    // - exact tenure years, exact ajudas, exact variable pay: entropy without
    //   aggregate value.
    // - device model, OS version, locale, IP, precise timestamp: none of them can
    //   change a salary aggregate and all of them narrow a crowd. The IP is the
    //   one that gets included by accident, at the server rather than here. See
    //   ContributionService.
}

// MARK: - Coarsening

extension Contribution {

    /// Nearest €10. The whole of the rounding policy, in one place, so the
    /// Python port has exactly one thing to agree with.
    static func rounded10(_ value: Double) -> Int {
        Int((value / 10).rounded()) * 10
    }

    /// Monthly ajudas de custo and meal allowance. Zero is a real answer and gets
    /// its own bucket rather than being folded in with "a little".
    static func ajudasBand(_ monthly: Double) -> String {
        switch monthly {
        case ..<0.5: return "0"
        case ..<100.5: return "1-100"
        case ..<200.5: return "101-200"
        case ..<400.5: return "201-400"
        default: return "400+"
        }
    }

    /// Bonus and commission over a year. nil means the question was never
    /// answered, which is different from answering that there is none.
    static func variableBand(_ annual: Double?) -> String? {
        guard let annual else { return nil }
        switch annual {
        case ..<0.5: return "none"
        case ..<1_000.5: return "1-1000"
        case ..<3_000.5: return "1001-3000"
        case ..<6_000.5: return "3001-6000"
        case ..<12_000.5: return "6001-12000"
        default: return "12000+"
        }
    }

    /// Contracted hours a week. Only meaningful for normalising part-time pay,
    /// which is the only reason it is here at all.
    static func hoursBand(_ hours: Int?) -> String? {
        guard let hours else { return nil }
        switch hours {
        case ..<20: return "lt20"
        case ..<30: return "20-29"
        case ..<35: return "30-34"
        default: return "35+"
        }
    }
}

// MARK: - Wire format

/// The shape is FIXED. Every key is written on every row, with an explicit null
/// where there is no answer, rather than letting Swift's synthesised encoder omit
/// the ones that happen to be nil. Two reasons: a fixed-column ingest does not
/// have to guess, and a payload whose key SET varies with how much of the profile
/// is filled in is a slightly different payload for every kind of user.
///
/// Key order matches `app-concept.md` §14.4, so the preview sheet can be read
/// straight against the document.
extension Contribution: Encodable {
    enum CodingKeys: String, CodingKey {
        case schema
        case token
        case year
        case grossMonthly = "gross_monthly"
        case paySchedule = "pay_schedule"
        case kindEntered = "kind_entered"
        case netEntered = "net_entered"
        case ajudasBand = "ajudas_band"
        case variableBand = "variable_band"
        case sector
        case jobTitleID = "job_title_id"
        case tenureBand = "tenure_band"
        case employerKind = "employer_kind"
        case workSchedule = "work_schedule"
        case hoursBand = "hours_band"
        case region
        case ageBand = "age_band"
        case education
        case gender
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schema, forKey: .schema)
        try c.encode(token, forKey: .token)
        try c.encode(year, forKey: .year)
        try c.encode(grossMonthly, forKey: .grossMonthly)
        try c.encode(paySchedule, forKey: .paySchedule)
        try c.encode(kindEntered, forKey: .kindEntered)
        try c.encode(netEntered, forKey: .netEntered)
        try c.encode(ajudasBand, forKey: .ajudasBand)
        try c.encode(variableBand, forKey: .variableBand)
        try c.encode(sector, forKey: .sector)
        try c.encode(jobTitleID, forKey: .jobTitleID)
        try c.encode(tenureBand, forKey: .tenureBand)
        try c.encode(employerKind, forKey: .employerKind)
        try c.encode(workSchedule, forKey: .workSchedule)
        try c.encode(hoursBand, forKey: .hoursBand)
        try c.encode(region, forKey: .region)
        try c.encode(ageBand, forKey: .ageBand)
        try c.encode(education, forKey: .education)
        try c.encode(gender, forKey: .gender)
    }

    /// The bytes that would go on the wire.
    func jsonData() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    /// The same row, formatted to be read by a person. This is what the preview
    /// sheet shows, and showing it is the point: a consent screen that describes
    /// the data in a paragraph asks to be trusted, one that can show you your own
    /// row does not have to.
    func prettyJSON() -> String {
        let encoder = JSONEncoder()
        // NOT .sortedKeys: the custom encoder above already fixes the order, and
        // sorting would scramble it away from the order the document uses.
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}
