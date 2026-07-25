import Foundation

/// v0.9: the progressive enrichment queue.
///
/// WHY A QUEUE AND NOT MORE ONBOARDING STEPS. Onboarding is already nine screens.
/// Every extra step costs completions, and a person who abandons onboarding
/// contributes nothing at all, so piling the new questions in there would trade
/// away the very data the questions exist to collect. Instead exactly one
/// unanswered question is surfaced at a time, in context, after the user has
/// already seen something useful, and always with the reason attached.
///
/// It is also the right shape for later. A question the user chose to answer,
/// in context, with a stated purpose, is far better ground for consent than a
/// wall of fields at signup would ever be.
///
/// Only the v0.9 signals live here. Sector, tenure, age, region and education
/// already have their own locked rows in compareSeed, and asking twice on one
/// screen reads as nagging.
enum EnrichmentSignal: String, CaseIterable, Identifiable {
    case employerKind
    case workSchedule
    case jobTitle
    case variablePay
    case gender

    var id: String { rawValue }

    /// Ordered by how much the answer improves the data, most valuable first.
    /// Gender is deliberately last: it is the most personal question here and it
    /// should never be the first thing the app asks for.
    static var ordered: [EnrichmentSignal] { allCases }

    func answered(_ store: SalaryStore) -> Bool {
        switch self {
        case .employerKind: return store.employerKind != nil
        case .workSchedule: return store.workSchedule != nil
        case .jobTitle:     return store.jobTitleID != nil
        case .variablePay:  return store.variableAnnual != nil
        case .gender:       return store.gender != nil
        }
    }

    /// Answered inline on the card, or does it need a sheet?
    var needsSheet: Bool {
        switch self {
        case .jobTitle, .variablePay: return true
        case .employerKind, .workSchedule, .gender: return false
        }
    }

    var icon: String {
        switch self {
        case .employerKind: return "building.columns"
        case .workSchedule: return "clock"
        case .jobTitle:     return "person.text.rectangle"
        case .variablePay:  return "gift"
        case .gender:       return "person.2"
        }
    }
}

extension SalaryStore {
    /// The next question worth asking, or nil when there is nothing left.
    /// `snoozed` holds the ones the user waved away this session.
    func nextEnrichment(skipping snoozed: Set<String> = []) -> EnrichmentSignal? {
        EnrichmentSignal.ordered.first { !$0.answered(self) && !snoozed.contains($0.rawValue) }
    }

    /// How many of the enrichment questions are done, for the progress line.
    var enrichmentAnswered: Int {
        EnrichmentSignal.ordered.filter { $0.answered(self) }.count
    }
}
