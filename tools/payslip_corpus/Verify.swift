// What the generator checks about itself before it writes anything.
//
// A wrong fixture measured carefully is worse than no fixture, so these run on
// every `generate` and a hard failure stops the whole run.
//
// The split matters. HARD checks are the ones where a failure means the
// generator is broken and nothing downstream can be trusted. REPORTED checks
// are observations about the reader, printed and never fatal, because a
// generator that refused to emit a page the lexicon reads oddly would be
// hiding exactly the finding the corpus exists to produce.

import Foundation

struct Complaint {
    let fixture: String
    let detail: String
}

func stripAccents(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "pt_PT"))
}

/// `PayslipLexicon.matchFixtures` parsed into label to concept, which is the
/// first thing in this project ever to read it. It has sat there since v1.1
/// with 33 rows off real payslips and no reader, so the mapping it describes
/// has never been checked by anything.
func lexiconFixtures() -> [(label: String, concept: PayslipConcept?)] {
    PayslipLexicon.matchFixtures.compactMap { row in
        let parts = row.components(separatedBy: " => ")
        guard parts.count == 2 else { return nil }
        let label = parts[0]
        let name = parts[1]
        if name == "nil" { return (label, nil) }
        return (label, PayslipConcept(rawValue: name))
    }
}

// MARK: Hard checks

/// 1. Every money string the generator prints must parse back, through the
///    reader's OWN parser, to the cents it meant.
///
/// This is the check that makes the corpus trustworthy at all: it means the
/// generator can never print a token shape the app disagrees with and then
/// blame the app for reading it differently. When it fails, the finding is
/// about `PayslipNumber`, not about the fixture, and the run stops so somebody
/// looks at it.
func checkMoneyRoundTrip(_ f: Fixture) -> [Complaint] {
    var out: [Complaint] = []
    for line in f.lines {
        for (what, value) in [("value", line.cents), ("base", line.baseCents),
                              ("accumulated", line.accumulatedCents)] {
            guard let value else { continue }
            let printed = printedMoney(value, f.style)
            let parsed = PayslipNumber.cents(from: printed)
            if parsed != value {
                out.append(Complaint(fixture: f.id, detail:
                    "\(what) on '\(line.label)' printed as '\(printed)' parses as "
                    + "\(parsed.map(String.init) ?? "nothing"), meant \(value)"))
            }
        }
    }
    return out
}

/// 2. Every printed total equals the sum of its own lines, in integer cents,
///    computed here rather than copied from the engine.
func checkTotals(_ f: Fixture) -> [Complaint] {
    guard f.isPayslip, f.injection == nil else { return [] }
    var out: [Complaint] = []

    func total(_ concept: PayslipConcept, side: PayslipConcept.Side, blocks: [Block]) {
        guard let printed = f.lines.first(where: { $0.concept == concept })?.cents else { return }
        let sum = f.lines
            .filter { blocks.contains($0.block) && $0.concept?.side == side }
            .compactMap(\.cents)
            .reduce(0, +)
        if sum != printed {
            out.append(Complaint(fixture: f.id, detail:
                "\(concept.rawValue) prints \(printed) but its own lines sum to \(sum)"))
        }
    }
    total(.totalEarnings, side: .earning, blocks: [.earnings])
    total(.totalDeductions, side: .deduction, blocks: [.deductions])
    return out
}

/// 3. Earnings minus deductions equals net, exactly.
func checkNetIdentity(_ f: Fixture) -> [Complaint] {
    guard f.isPayslip, f.injection == nil else { return [] }
    let t = f.truth
    guard let e = t[.totalEarnings], let d = t[.totalDeductions], let n = t[.netPay] else { return [] }
    guard e - d != n else { return [] }
    return [Complaint(fixture: f.id, detail: "\(e) - \(d) != \(n)")]
}

/// 4. An injected fixture differs from the engine in exactly one figure, by
///    exactly the stated delta. Without this the sensitivity curve would be
///    measuring an unknown perturbation.
func checkInjection(_ f: Fixture) -> [Complaint] {
    guard let injection = f.injection, injection.kind == .line else { return [] }
    let clean = build(seeds.first { $0.id == f.id }.map { seed -> Seed in
        var copy = seed
        copy.injection = nil
        return copy
    } ?? Seed(id: f.id, family: f.family))
    let differences = zip(clean.lines, f.lines).filter { $0.cents != $1.cents }
    if differences.count != 1 {
        return [Complaint(fixture: f.id, detail:
            "injection moved \(differences.count) figures, expected 1")]
    }
    let delta = (differences[0].1.cents ?? 0) - (differences[0].0.cents ?? 0)
    if delta != injection.deltaCents {
        return [Complaint(fixture: f.id, detail:
            "injection moved a figure by \(delta), expected \(injection.deltaCents)")]
    }
    return []
}

func hardChecks(_ f: Fixture) -> [Complaint] {
    checkMoneyRoundTrip(f) + checkTotals(f) + checkNetIdentity(f) + checkInjection(f)
}

// MARK: Reported checks

struct LabelReport {
    let fixture: String
    let label: String
    let declared: PayslipConcept?
    let lexiconSays: PayslipConcept?
    let source: LabelSource
    let verbatimInFixtures: Bool

    var disagrees: Bool { declared != lexiconSays }
}

/// What the lexicon actually does with each label the corpus prints.
///
/// Reported, never fatal. A disagreement here is a finding about
/// `PayslipLexicon`, and refusing to emit the page would bury it. This is also
/// the honest measure of how much of the corpus's vocabulary was borrowed from
/// the reader's own word list: a label the lexicon has never seen is the most
/// likely real failure, and a corpus built from `matchFixtures` cannot discover
/// one. Hence the `unknown` label source and the count below.
func labelReport(_ f: Fixture) -> [LabelReport] {
    let known = lexiconFixtures()
    return f.lines.compactMap { line in
        guard line.concept != nil || line.labelSource == .unknown else { return nil }
        let stripped = stripAccents(line.label)
        let verbatim = known.contains { stripAccents($0.label).caseInsensitiveCompare(stripped) == .orderedSame }
        return LabelReport(
            fixture: f.id, label: line.label, declared: line.concept,
            lexiconSays: PayslipLexicon.best(for: PayslipText.normalizeLabel(line.label)),
            source: line.labelSource, verbatimInFixtures: verbatim)
    }
}

// MARK: Truth, as JSON

func truthJSON(_ f: Fixture) -> [String: Any] {
    var concepts: [String: Int] = [:]
    for (concept, cents) in f.truth { concepts[concept.rawValue] = cents }

    return [
        "id": f.id,
        "family": f.family,
        "style": f.style.rawValue,
        "context": [
            "region": f.region.rawValue,
            "months": f.months,
            "marital": f.marital.rawValue,
            "dependents": f.dependents,
            "jovemExemption": f.jovem,
        ],
        "isPayslip": f.isPayslip,
        "concepts": concepts,
        // Stated separately from concepts.ssBase on purpose. On the ajudas
        // families they are different numbers, because ajudas de custo and the
        // meal allowance sit outside gross and go straight to net, and the one
        // figure onboarding needs is the gross.
        "onboarding": ["monthlyGrossCents": f.monthlyGrossCents,
                       "ajudasMonthlyCents": f.ajudasMonthlyCents],
        "expectedSkips": f.expectedSkips.sorted(),
        "injection": f.injection.map { i -> [String: Any] in
            ["kind": i.kind.rawValue, "concept": i.concept.rawValue,
             "deltaCents": i.deltaCents, "note": i.note]
        } ?? NSNull(),
        "lines": f.lines.map { line -> [String: Any] in
            [
                "label": line.label,
                "code": line.code ?? NSNull(),
                "block": line.block.rawValue,
                "concept": line.concept?.rawValue ?? NSNull(),
                "side": line.concept?.side.name ?? NSNull(),
                "cents": line.cents ?? NSNull(),
                "printed": line.cents.map { printedMoney($0, f.style) } ?? NSNull(),
                "labelSource": line.labelSource.rawValue,
                "quantity": line.quantity ?? NSNull(),
                "ratePermyriad": line.ratePermyriad ?? NSNull(),
                "baseCents": line.baseCents ?? NSNull(),
                "accumulatedCents": line.accumulatedCents ?? NSNull(),
            ]
        },
    ]
}
