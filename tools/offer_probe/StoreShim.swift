// A stand-in for `SalaryStore`, so `CohortEngine.swift` compiles unmodified.
//
// That file carries Compare's row descriptors (`CompareDimension`) next to the
// engine, and their closures read and write the real store. The real store
// cannot be built here: it pulls in `Theme`, which needs UIKit. Nothing in the
// probe calls those descriptors. What it tests in that file is
// `CohortEngine.result` and the cohort cells, and those are the shipping code.
//
// If `CompareDimension` ever reads another property, this stops compiling,
// which is loud, rather than quietly testing something else.

final class SalaryStore {
    var ageBand: AgeBand?
    var region: PTRegion?
    var concelhoID: String?
    var education: EducationLevel?
}
