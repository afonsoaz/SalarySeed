import Foundation

/// v0.13: the whole of the app's outbound surface, and it is currently inert.
///
/// THE APP SPEAKS AND NEVER LISTENS. There are two calls, both outbound, both
/// writes: contribute, and forget. There is no read path anywhere in this app, by
/// design, because a read path means a query log, and a log of which salary cells
/// a person looked up is a more sensitive dataset than the salaries themselves.
/// Crowd figures, when they exist, arrive as a precomputed file inside the app
/// bundle, exactly the way `SalaryDataset` and `EuroDataset` already do, so
/// k-anonymity is a property of a file built offline rather than a runtime check
/// that can be probed by walking the cells. See `app-concept.md` §14.2.
///
/// `endpoint` IS NIL AND EVERY CALL IS A NO-OP. No backend exists. Nothing has
/// ever been sent, from anyone. This file is here so the shape is settled and the
/// consent copy can describe something real, not because it is about to run.
///
/// WHEN THERE IS AN ENDPOINT, two things have to be true of it before it is
/// pointed at, and neither is visible from this side:
///
/// 1. **It must not log client IP addresses**, or must truncate them before they
///    are written anywhere. An IP is personal data and it re-links a pseudonymous
///    row to a person, which quietly undoes this entire design. Every managed
///    platform logs it by default. It has to be turned off deliberately and then
///    checked.
/// 2. **It must upsert on (token, year)**, so one person is one row per year by
///    construction. Appending would let a single contributor weight a thin cell.
///
/// The payload is also built fresh at the moment of sending rather than queued.
/// A row built today and sent in a year would be a year-old answer wearing a new
/// timestamp, and there is no version of that which is honest.
enum ContributionService {

    /// Deliberately nil. See above.
    static let endpoint: URL? = nil

    enum Outcome: Equatable {
        /// There is nowhere to send it, which is today's answer for everyone.
        case notConfigured
        /// Consent has not been given, or was withdrawn.
        case notConsented
        /// The profile has no salary, so there is nothing worth a row.
        case nothingToSend
        case sent
        case failed(String)
    }

    /// A stand-in used only by the preview, before consent has created a real
    /// one. Visibly not a UUID anybody generated, so a screenshot of the preview
    /// can never be mistaken for a screenshot of a real row.
    static let placeholderToken = "00000000-0000-0000-0000-000000000000"

    /// What would be sent for this store, right now, or nil when there is no
    /// usable salary. Pure: it reads, it does not send.
    ///
    /// The token is passed in rather than read here, so the preview can show a
    /// truthful row BEFORE consent exists. Being able to read your own row while
    /// deciding is most of the point of showing it at all.
    static func payload(for store: SalaryStore, year: Int, token: String) -> Contribution? {
        let gross = store.breakdown.grossMonthly
        guard gross > 0 else { return nil }
        return Contribution(
            schema: Contribution.schemaVersion,
            token: token,
            year: year,
            grossMonthly: Contribution.rounded10(gross),
            paySchedule: Int(store.schedule.months),
            kindEntered: store.kind.rawValue,
            // Only when they actually typed a net figure. See Contribution.
            netEntered: store.kind == .net ? Contribution.rounded10(store.amount) : nil,
            ajudasBand: Contribution.ajudasBand(store.ajudasMonthly),
            variableBand: Contribution.variableBand(store.variableAnnual),
            sector: store.sector?.rawValue,
            jobTitleID: store.jobTitleID,
            tenureBand: store.tenureBand?.rawValue,
            employerKind: store.employerKind?.rawValue,
            workSchedule: store.workSchedule?.rawValue,
            hoursBand: Contribution.hoursBand(store.weeklyHours),
            // The region, derived from the concelho. Never the concelho.
            region: store.region?.rawValue,
            ageBand: store.ageBand?.rawValue,
            education: store.education?.rawValue,
            gender: store.gender?.rawValue
        )
    }

    /// Send one row. Does nothing today.
    static func contribute(from store: SalaryStore, year: Int) -> Outcome {
        guard store.dataSharingConsent == true else { return .notConsented }
        guard let token = ContributionToken.load() else { return .notConsented }
        guard endpoint != nil else { return .notConfigured }
        guard payload(for: store, year: year, token: token) != nil else { return .nothingToSend }
        // Deliberately unimplemented. The transport, App Attest and retry belong
        // to the version that has somewhere to send to, and writing them now
        // would be writing code that cannot be run or tested against anything.
        return .notConfigured
    }

    /// Delete everything ever sent under this token. Does nothing today, and
    /// returning `.notConfigured` is the honest answer rather than a fake success:
    /// the caller uses it to decide whether it is safe to clear the token.
    static func forget(token: String) -> Outcome {
        guard endpoint != nil else { return .notConfigured }
        return .notConfigured
    }
}
