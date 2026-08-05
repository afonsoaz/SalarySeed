import Foundation
import Combine

enum AmountKind: String, CaseIterable, Identifiable {
    case gross, net
    var id: String { rawValue }
    func label(pt: Bool) -> String {
        switch self {
        case .gross: pt ? "Bruto" : "Gross"
        case .net: pt ? "Líquido" : "Net"
        }
    }
}

enum PaySchedule: String, CaseIterable, Identifiable {
    case fourteen = "14"
    case twelve = "12"
    var id: String { rawValue }
    var months: Double { self == .fourteen ? 14 : 12 }
    func label(pt: Bool) -> String { pt ? "\(rawValue) meses" : "\(rawValue) months" }
}

/// v0.8: how the salary editor reads the number the user types, monthly per
/// payment or the whole year. Stored amount is always per paid month; the yearly
/// figure is just monthly × the pay schedule.
enum SalaryInputPeriod: String, CaseIterable, Identifiable {
    case monthly, yearly
    var id: String { rawValue }
    func label(pt: Bool) -> String {
        switch self {
        case .monthly: pt ? "Mensal" : "Monthly"
        case .yearly: pt ? "Anual" : "Yearly"
        }
    }
}

/// v1 is employees only; self-employed (soloSeed) comes later.
enum EmploymentType: String, CaseIterable, Identifiable {
    case employee, selfEmployed
    var id: String { rawValue }
}

/// Single source of truth for the user's inputs. Persisted in UserDefaults (local-first).
///
/// v0.9 note on scope: everything here still lives only on this phone. The
/// signals are collected, not uploaded. The reason they are collected anyway is
/// that a job title or a contract type cannot be asked about retroactively.
///
/// v0.12 added the consent flow, which is the first of the three things pooling
/// needs. The other two, an account and a backend, do not exist, so App Privacy
/// stays "Data Not Collected" and nothing leaves the phone whatever the flag
/// says. Asking first and building second is the right order: consent obtained
/// after the fact is not consent.
final class SalaryStore: ObservableObject {
    @Published var amount: Double { didSet { save() } }
    @Published var kind: AmountKind { didSet { save() } }
    @Published var schedule: PaySchedule { didSet { save() } }
    /// v0.5: ajudas de custo (or other amounts paid straight to net), per month.
    /// Kept apart from the salary everywhere: no IRS, no SS, no percentiles.
    @Published var ajudasMonthly: Double { didSet { save() } }
    @Published var employment: EmploymentType { didSet { save() } }
    @Published var hasOnboarded: Bool { didSet { save() } }
    /// v0.8: remembers whether the editor last showed the salary as monthly or
    /// yearly, so it reopens the way the user prefers.
    @Published var inputYearly: Bool { didSet { save() } }

    // v0.6: real tax inputs. Marital situation and dependants are asked in
    // onboarding; the IRS Jovem exemption (1.0 = 100% ... 0 = off) lives in profileSeed.
    @Published var maritalSituation: MaritalSituation { didSet { save() } }
    @Published var dependents: Int { didSet { save() } }
    @Published var irsJovemExemption: Double { didSet { save() } }

    // v0.2: name (welcome screen) + progressive profile signals.
    // Stored as stable raw-value IDs; these are the future growthSeed inputs too.
    @Published var name: String { didSet { save() } }
    @Published var ageBand: AgeBand? { didSet { save() } }
    /// v0.9.1: the user picks a município; the district and the NUTS 2024 region
    /// are DERIVED from it, never stored and never asked for separately.
    /// See Concelhos.swift for why the district could not be the input.
    @Published var concelhoID: String? { didSet { save() } }
    @Published var education: EducationLevel? { didSet { save() } }
    // v0.8.3: sector (GEP CAE) replaces the old occupation group; tenure years
    // cross with it for the sector×tenure percentile.
    @Published var sector: Sector? { didSet { save() } }
    /// v0.9: years AT THE CURRENT EMPLOYER (GEP's antiguidade na empresa), not
    /// years in the sector. See the note on TenureBand.
    @Published var tenureYears: Int? { didSet { save() } }

    // MARK: v0.9 signals (collected, not yet compared against)

    /// Curated job title, a `JobTitleCatalog` id. The finest-grained signal in
    /// the app and the one no published Portuguese source offers.
    @Published var jobTitleID: String? { didSet { save() } }
    /// Private / função pública / state-owned. Decides whether the GEP
    /// comparison applies to this user at all.
    @Published var employerKind: EmployerKind? { didSet { save() } }
    /// Full-time or part-time.
    @Published var workSchedule: WorkSchedule? { didSet { save() } }
    /// Contracted hours a week. Only meaningful alongside `workSchedule`.
    @Published var weeklyHours: Int? { didSet { save() } }
    /// Optional, skippable. `.preferNot` is a real stored answer.
    @Published var gender: Gender? { didSet { save() } }
    /// Bonus, commission and prémios over a year, on top of the salary.
    /// nil means "not answered yet"; 0 means "answered, and there is none".
    /// Deliberately NOT fed into TaxEngine: withholding on non-monthly pay
    /// follows different rules and the engine's 2026 tables are verified for
    /// regular salary. Shown as a separate line, never folded into the estimate.
    @Published var variableAnnual: Double? { didSet { save() } }
    // v0.3: language. Follows the device by default, can be changed in the profile tab.
    @Published var language: AppLanguage { didSet { save() } }

    // MARK: v0.12 consent

    /// Whether the user agreed to their answers being pooled anonymously.
    ///
    /// THREE STATES, AND THE THIRD ONE MATTERS. `nil` is "never asked", `false`
    /// is "asked and declined", `true` is "asked and agreed". Collapsing nil and
    /// false into one Bool would make a decline indistinguishable from a fresh
    /// install, so the app would ask again on every launch, which is nagging, and
    /// nagging is one of the things that makes consent not freely given.
    ///
    /// Nothing leaves the phone today whatever this says: there is no backend and
    /// no network call anywhere in the app. The flag records a decision so that
    /// pooling can only ever start from a yes, never from a default.
    @Published var dataSharingConsent: Bool? { didSet { save() } }

    // MARK: v0.10 session state (deliberately not persisted)

    /// The Grow scenario. It has NO `didSet { save() }` and is absent from
    /// `save()` on purpose. Grow explores rather than records, in the v0.9.4
    /// sense, and a hypothetical that survived a relaunch would start behaving
    /// like a stored fact about the user. It does survive swiping between tabs,
    /// which is the whole reason it lives here instead of inside the view.
    @Published var growScenario = GrowthEngine.Scenario()

    /// Which tab is showing. The paged TabView and the custom bar both bind to
    /// this, so the selection has one source of truth rather than a private copy
    /// in the view that the bar can disagree with. It also leaves the door open
    /// for one screen to send the user to another; nothing does that today,
    /// since v0.10.1 took away the Home card that used to jump to Grow.
    @Published var selectedTab: Int = 0

    private let defaults = UserDefaults.standard

    init() {
        amount = defaults.double(forKey: "amount") == 0 ? 1500 : defaults.double(forKey: "amount")
        kind = AmountKind(rawValue: defaults.string(forKey: "kind") ?? "") ?? .gross
        schedule = PaySchedule(rawValue: defaults.string(forKey: "schedule") ?? "") ?? .fourteen
        ajudasMonthly = defaults.double(forKey: "ajudasMonthly")
        employment = EmploymentType(rawValue: defaults.string(forKey: "employment") ?? "") ?? .employee
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")
        inputYearly = defaults.bool(forKey: "inputYearly")
        maritalSituation = MaritalSituation(rawValue: defaults.string(forKey: "maritalSituation") ?? "") ?? .single
        dependents = defaults.integer(forKey: "dependents")
        irsJovemExemption = defaults.double(forKey: "irsJovemExemption")
        name = defaults.string(forKey: "name") ?? ""
        ageBand = AgeBand(rawValue: defaults.string(forKey: "profile.ageBand") ?? "")
        concelhoID = defaults.string(forKey: "profile.concelho")
        // v0.9.1 migration: the old NUTS II answer is dropped rather than guessed
        // backwards into a município. The question is simply asked again.
        defaults.removeObject(forKey: "profile.region")
        // v0.9.3: career-total tenure is no longer asked for. Only antiguidade na
        // empresa is, because that is the only one any published table crosses.
        defaults.removeObject(forKey: "profile.careerYears")
        education = EducationLevel(rawValue: defaults.string(forKey: "profile.education") ?? "")
        sector = Sector(rawValue: defaults.string(forKey: "profile.sector") ?? "")
        tenureYears = defaults.object(forKey: "profile.tenureYears") as? Int
        jobTitleID = defaults.string(forKey: "profile.jobTitle")
        employerKind = EmployerKind(rawValue: defaults.string(forKey: "profile.employerKind") ?? "")
        workSchedule = WorkSchedule(rawValue: defaults.string(forKey: "profile.workSchedule") ?? "")
        weeklyHours = defaults.object(forKey: "profile.weeklyHours") as? Int
        gender = Gender(rawValue: defaults.string(forKey: "profile.gender") ?? "")
        variableAnnual = defaults.object(forKey: "profile.variableAnnual") as? Double
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .auto
        // `object(forKey:)` rather than `bool(forKey:)`: a missing key has to come
        // back as nil, and `bool(forKey:)` turns it into false, which is a
        // recorded refusal. See the note on the property.
        dataSharingConsent = defaults.object(forKey: "consent.dataSharing") as? Bool
    }

    private func save() {
        defaults.set(amount, forKey: "amount")
        defaults.set(kind.rawValue, forKey: "kind")
        defaults.set(schedule.rawValue, forKey: "schedule")
        defaults.set(ajudasMonthly, forKey: "ajudasMonthly")
        defaults.set(employment.rawValue, forKey: "employment")
        defaults.set(hasOnboarded, forKey: "hasOnboarded")
        defaults.set(inputYearly, forKey: "inputYearly")
        defaults.set(maritalSituation.rawValue, forKey: "maritalSituation")
        defaults.set(dependents, forKey: "dependents")
        defaults.set(irsJovemExemption, forKey: "irsJovemExemption")
        defaults.set(name, forKey: "name")
        defaults.set(language.rawValue, forKey: "language")
        setOptional(ageBand?.rawValue, forKey: "profile.ageBand")
        setOptional(concelhoID, forKey: "profile.concelho")
        setOptional(education?.rawValue, forKey: "profile.education")
        setOptional(sector?.rawValue, forKey: "profile.sector")
        setOptional(jobTitleID, forKey: "profile.jobTitle")
        setOptional(employerKind?.rawValue, forKey: "profile.employerKind")
        setOptional(workSchedule?.rawValue, forKey: "profile.workSchedule")
        setOptional(gender?.rawValue, forKey: "profile.gender")
        setInt(tenureYears, forKey: "profile.tenureYears")
        setInt(weeklyHours, forKey: "profile.weeklyHours")
        if let variableAnnual { defaults.set(variableAnnual, forKey: "profile.variableAnnual") }
        else { defaults.removeObject(forKey: "profile.variableAnnual") }
        if let dataSharingConsent { defaults.set(dataSharingConsent, forKey: "consent.dataSharing") }
        else { defaults.removeObject(forKey: "consent.dataSharing") }
    }

    private func setOptional(_ value: String?, forKey key: String) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    private func setInt(_ value: Int?, forKey key: String) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    // MARK: Language

    var resolvedLanguage: ResolvedLanguage {
        switch language {
        case .english: .en
        case .portuguese: .pt
        case .auto: ResolvedLanguage.device
        }
    }

    /// The active string table. Views read all copy through this.
    var s: Strings { Strings(resolvedLanguage) }

    // MARK: Profile

    /// Trimmed name, or nil when empty. Used for greetings.
    var displayName: String? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? nil : n
    }

    /// The resolved job title, if one is picked and still in the catalogue.
    var jobTitle: JobTitle? { JobTitleCatalog.title(jobTitleID) }

    /// The resolved município, if one is picked and still in the catalogue.
    var concelho: Concelho? { ConcelhoCatalog.concelho(concelhoID) }

    /// Derived, exactly, from the município. Not yet used for any comparison;
    /// this is what the v0.9.2 map will be drawn from.
    var district: District? { concelho?.district }

    /// Derived, exactly, from the município. Every existing cohort comparison
    /// keys on this, so it stays a PTRegion and nothing downstream changes.
    var region: PTRegion? { concelho?.region }

    /// v0.15: where the user pays IRS, derived from the concelho like everything
    /// else geographic. Nobody is ever asked this directly.
    ///
    /// No concelho means Continente, and that is a real assumption rather than a
    /// neutral one. It is the safe direction to be wrong in, because the mainland
    /// rates are the higher ones, so an unplaced islander is overcharged on paper
    /// rather than undercharged. The tax screens say so rather than leaving it.
    var taxRegion: TaxEngine.TaxRegion {
        switch region {
        case .acores: return .acores
        case .madeira: return .madeira
        default: return .continente
        }
    }

    /// True when mainland tax is being shown to someone whose location the app
    /// does not know. Drives the one caveat that assumption earns.
    var taxRegionAssumed: Bool { concelho == nil }

    /// Every signal the seed counts. v0.9 grew this from 4 to 10, so the sprout
    /// maps the fraction filled onto its 5 drawn stages instead of counting
    /// signals one for one.
    var signalsFilled: [Bool] {
        [
            ageBand != nil,
            concelhoID != nil,
            education != nil,
            sector != nil,
            tenureYears != nil,
            jobTitleID != nil,
            employerKind != nil,
            workSchedule != nil,
            // v0.9.3: any answer counts as answered, including "prefer not to
            // say". `informative` still gates whether the value is usable as
            // data, but a deliberate refusal is a completed question, and
            // counting it otherwise made the finished state unreachable for
            // anyone who chose it.
            gender != nil,
            variableAnnual != nil,
        ]
    }

    var signalTotal: Int { signalsFilled.count }

    /// How many profile signals are filled.
    var profileFilledCount: Int { signalsFilled.filter { $0 }.count }

    /// The tenure band derived from the entered years (nil until years are set).
    var tenureBand: TenureBand? {
        tenureYears.map { TenureBand.from(years: $0) }
    }

    /// The cohort cell for the user's sector, crossed with tenure when known.
    var sectorCell: CohortCell? {
        sector.map { SalaryDataset.sectorCell($0, tenure: tenureBand) }
    }

    /// True when the user is on a public-function contract, a population the
    /// Quadros de Pessoal do not cover. Cohort cards carry a caveat in that case.
    var outsideGEPScope: Bool { employerKind?.outsideGEP == true }

    /// Sprout growth stage 1 to 5: the salary plants the seed, and the share of
    /// profile signals filled grows it the rest of the way.
    var sproutStage: Int { Self.sproutStage(filled: profileFilledCount, of: signalTotal) }

    /// Stage the sprout would reach with `extra` more signals answered. Used by
    /// the pickers to preview the reward before the user commits.
    func sproutStage(withExtra extra: Int) -> Int {
        Self.sproutStage(filled: min(signalTotal, profileFilledCount + extra), of: signalTotal)
    }

    static func sproutStage(filled: Int, of total: Int) -> Int {
        guard total > 0, filled > 0 else { return 1 }
        let grown = Int(ceil(4.0 * Double(filled) / Double(total)))
        return min(5, 1 + grown)
    }

    // MARK: Breakdown

    /// The full computed breakdown for the current inputs.
    var breakdown: SalaryBreakdown {
        let grossMonthly: Double
        switch kind {
        case .gross: grossMonthly = amount
        case .net: grossMonthly = TaxEngine.grossFromNet(
            amount,
            marital: maritalSituation,
            dependents: dependents,
            jovemExemption: irsJovemExemption,
            months: schedule.months,
            region: taxRegion
        )
        }
        return TaxEngine.breakdown(
            grossMonthly: grossMonthly,
            months: schedule.months,
            ajudasMonthly: ajudasMonthly,
            marital: maritalSituation,
            dependents: dependents,
            jovemExemption: irsJovemExemption,
            region: taxRegion
        )
    }

    /// National percentile for the current gross salary.
    /// Ajudas de custo are deliberately NOT included: published distributions
    /// are gross-salary based, and the UI says so wherever this number shows.
    /// Neither is variable pay: GEP's ganho is a monthly figure that does not
    /// carry annual bonuses, so folding them in would compare unlike with unlike.
    var percentile: Double {
        PercentileEngine.percentile(grossMonthly: breakdown.grossMonthly)
    }

    // MARK: Data sharing (v0.13)

    /// THREE ACTS, NOT TWO, and keeping them apart is the whole design.
    ///
    /// Granting creates the token. Revoking stops future sharing and deliberately
    /// KEEPS the token, because "stop sending" and "delete what you sent" are
    /// different intentions with different consequences, in exactly the sense
    /// v0.9.4 separated recording from exploring. Forgetting is the third act:
    /// it deletes, and only then clears the token.
    ///
    /// Getting that order wrong is the failure worth naming. Clearing the token
    /// first would leave rows on a server with nothing left that can name them,
    /// which is the precise situation the token exists to prevent.
    func grantDataSharing() {
        ContributionToken.ensure()
        dataSharingConsent = true
    }

    func revokeDataSharing() {
        dataSharingConsent = false
    }

    /// The token, when consent has ever been given. Shown in the profile so that
    /// someone who has lost the phone can still ask for their rows to go.
    var contributionToken: String? { ContributionToken.load() }

    /// Delete everything ever sent, then forget who we were. Returns false only
    /// when a server exists and refused, so the UI can avoid telling the user
    /// their data is gone when it is not.
    @discardableResult
    func forgetContributions() -> Bool {
        guard let token = contributionToken else {
            dataSharingConsent = false
            return true
        }
        switch ContributionService.forget(token: token) {
        case .notConfigured:
            // Nothing has ever been sent under this token, because there has
            // never been anywhere to send it. Clearing it locally IS the
            // deletion, completely, and saying so is not a convenient reading:
            // `ContributionService.endpoint` is nil, so no row can exist.
            ContributionToken.clear()
            dataSharingConsent = false
            return true
        case .sent:
            ContributionToken.clear()
            dataSharingConsent = false
            return true
        case .notConsented, .nothingToSend, .failed:
            return false
        }
    }

    /// The row that would leave the phone right now, for the preview sheet.
    /// Falls back to a placeholder code so the preview works before consent,
    /// which is exactly when someone most wants to look at it.
    func contributionPreview(year: Int) -> Contribution? {
        ContributionService.payload(for: self, year: year,
                                    token: contributionToken ?? ContributionService.placeholderToken)
    }
}
