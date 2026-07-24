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
    @Published var region: PTRegion? { didSet { save() } }
    @Published var education: EducationLevel? { didSet { save() } }
    // v0.8.3: sector (GEP CAE) replaces the old occupation group; tenure years in
    // that sector cross with it for the sector×tenure percentile.
    @Published var sector: Sector? { didSet { save() } }
    @Published var tenureYears: Int? { didSet { save() } }

    // v0.3: language. Follows the device by default, can be changed in the profile tab.
    @Published var language: AppLanguage { didSet { save() } }

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
        region = PTRegion(rawValue: defaults.string(forKey: "profile.region") ?? "")
        education = EducationLevel(rawValue: defaults.string(forKey: "profile.education") ?? "")
        sector = Sector(rawValue: defaults.string(forKey: "profile.sector") ?? "")
        let ty = defaults.object(forKey: "profile.tenureYears") as? Int
        tenureYears = ty
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .auto
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
        setOptional(region?.rawValue, forKey: "profile.region")
        setOptional(education?.rawValue, forKey: "profile.education")
        setOptional(sector?.rawValue, forKey: "profile.sector")
        if let tenureYears { defaults.set(tenureYears, forKey: "profile.tenureYears") }
        else { defaults.removeObject(forKey: "profile.tenureYears") }
    }

    private func setOptional(_ value: String?, forKey key: String) {
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

    /// How many of the four profile signals are filled (0 to 4).
    var profileFilledCount: Int {
        [ageBand != nil, region != nil, education != nil, sector != nil]
            .filter { $0 }.count
    }

    /// The tenure band derived from the entered years (nil until years are set).
    var tenureBand: TenureBand? {
        tenureYears.map { TenureBand.from(years: $0) }
    }

    /// The cohort cell for the user's sector, crossed with tenure when known.
    var sectorCell: CohortCell? {
        sector.map { SalaryDataset.sectorCell($0, tenure: tenureBand) }
    }

    /// Sprout growth stage 0 to 5: the salary plants the seed (1);
    /// each profile signal grows it one stage. Drives SproutView everywhere.
    var sproutStage: Int { 1 + profileFilledCount }

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
            months: schedule.months
        )
        }
        return TaxEngine.breakdown(
            grossMonthly: grossMonthly,
            months: schedule.months,
            ajudasMonthly: ajudasMonthly,
            marital: maritalSituation,
            dependents: dependents,
            jovemExemption: irsJovemExemption
        )
    }

    /// National percentile for the current gross salary.
    /// Ajudas de custo are deliberately NOT included: published distributions
    /// are gross-salary based, and the UI says so wherever this number shows.
    var percentile: Double {
        PercentileEngine.percentile(grossMonthly: breakdown.grossMonthly)
    }
}
