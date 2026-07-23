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
    @Published var employment: EmploymentType { didSet { save() } }
    @Published var hasOnboarded: Bool { didSet { save() } }

    // v0.2: name (welcome screen) + progressive profile signals.
    // Stored as stable raw-value IDs; these are the future growthSeed inputs too.
    @Published var name: String { didSet { save() } }
    @Published var ageBand: AgeBand? { didSet { save() } }
    @Published var region: PTRegion? { didSet { save() } }
    @Published var education: EducationLevel? { didSet { save() } }
    @Published var occupation: OccupationGroup? { didSet { save() } }

    // v0.3: language. Follows the device by default, can be changed in the profile tab.
    @Published var language: AppLanguage { didSet { save() } }

    private let defaults = UserDefaults.standard

    init() {
        amount = defaults.double(forKey: "amount") == 0 ? 1500 : defaults.double(forKey: "amount")
        kind = AmountKind(rawValue: defaults.string(forKey: "kind") ?? "") ?? .gross
        schedule = PaySchedule(rawValue: defaults.string(forKey: "schedule") ?? "") ?? .fourteen
        employment = EmploymentType(rawValue: defaults.string(forKey: "employment") ?? "") ?? .employee
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")
        name = defaults.string(forKey: "name") ?? ""
        ageBand = AgeBand(rawValue: defaults.string(forKey: "profile.ageBand") ?? "")
        region = PTRegion(rawValue: defaults.string(forKey: "profile.region") ?? "")
        education = EducationLevel(rawValue: defaults.string(forKey: "profile.education") ?? "")
        occupation = OccupationGroup(rawValue: defaults.string(forKey: "profile.occupation") ?? "")
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .auto
    }

    private func save() {
        defaults.set(amount, forKey: "amount")
        defaults.set(kind.rawValue, forKey: "kind")
        defaults.set(schedule.rawValue, forKey: "schedule")
        defaults.set(employment.rawValue, forKey: "employment")
        defaults.set(hasOnboarded, forKey: "hasOnboarded")
        defaults.set(name, forKey: "name")
        defaults.set(language.rawValue, forKey: "language")
        setOptional(ageBand?.rawValue, forKey: "profile.ageBand")
        setOptional(region?.rawValue, forKey: "profile.region")
        setOptional(education?.rawValue, forKey: "profile.education")
        setOptional(occupation?.rawValue, forKey: "profile.occupation")
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
        [ageBand != nil, region != nil, education != nil, occupation != nil]
            .filter { $0 }.count
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
        case .net: grossMonthly = TaxEngine.grossFromNet(amount)
        }
        return TaxEngine.breakdown(grossMonthly: grossMonthly, months: schedule.months)
    }

    /// National percentile for the current gross (placeholder data).
    var percentile: Double {
        PercentileEngine.percentile(grossMonthly: breakdown.grossMonthly)
    }
}
