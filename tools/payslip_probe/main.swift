// v1.1: the compiled probe. Item 7 of the payslip reader's plan.
//
// `tools/verify_payslip_reader.py` checks everything that can be checked by
// reimplementing a rule in Python and comparing: the money parser, the
// homoglyph table, the tolerance ordering. Four files resisted that entirely.
// `PayslipLayout`, `PayslipDocument`, `PayslipClassifier` and
// `PayslipReconciler` do not restate a table, they make a judgement about a
// page, and the only way to check a judgement is to run it.
//
// So this compiles the shipping Engine sources, unmodified, into a command
// line tool and prints what they decide about a real file: every line with the
// concept, provenance and confidence it was given, the facts that came out,
// and the verdict. It is a dump rather than a pass/fail because there is no
// published answer key for a payslip. What it is for is the diff: capture the
// output, change the classifier, capture it again, and read what moved.
//
// The payslips themselves are somebody's actual pay and are gitignored, so a
// fresh clone can build this and has nothing to point it at. That is why the
// script and not this file is what runs before a release.
//
//     tools/payslip_probe/build.sh
//     .build/payslip_probe <file.pdf|file.png> [--json]

import Foundation
import CoreGraphics
import ImageIO
import PDFKit

// MARK: Formatting

func euros(_ cents: Int?) -> String {
    guard let cents else { return "-" }
    let sign = cents < 0 ? "-" : ""
    let a = abs(cents)
    return "\(sign)\(a / 100),\(String(format: "%02d", a % 100))"
}

func pad(_ s: String, _ n: Int) -> String {
    s.count >= n ? String(s.prefix(n)) : s + String(repeating: " ", count: n - s.count)
}

extension PayslipConfidence {
    var name: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }
}

extension PayslipTier {
    var name: String {
        switch self {
        case .wrong: return "WRONG"
        case .mention: return "mention"
        case .correct: return "correct"
        }
    }
}

// MARK: Reading a file

func fragments(of path: String) -> (frags: [PayslipFragment], source: PayslipSource)? {
    let url = URL(fileURLWithPath: path)
    if path.lowercased().hasSuffix(".pdf") {
        switch PayslipPDF.read(url: url) {
        case .success(.text(let frags, let source)):
            return (frags, source)
        case .success(.needsRecognition(let images)):
            FileHandle.standardError.write("  (no text layer, rasterised \(images.count) page(s) to Vision)\n".data(using: .utf8)!)
            var all: [PayslipFragment] = []
            for image in images {
                all += (try? PayslipOCR.fragments(in: image)) ?? []
            }
            return (all, .ocr)
        case .failure(let why):
            print("unreadable: \(why.rawValue)")
            return nil
        }
    }
    guard let data = try? Data(contentsOf: url), let image = PayslipOCR.image(from: data) else {
        print("unreadable: could not decode \(path)")
        return nil
    }
    return ((try? PayslipOCR.fragments(in: image)) ?? [], .ocr)
}

// MARK: Main

let args = Array(CommandLine.arguments.dropFirst())
guard let path = args.first(where: { !$0.hasPrefix("--") }) else {
    print("usage: payslip_probe <file.pdf|file.png>")
    exit(2)
}

print("======================================================================")
print("FILE  \(URL(fileURLWithPath: path).lastPathComponent)")
print("======================================================================")

guard let (frags, source) = fragments(of: path) else { exit(1) }
print("SOURCE          \(source) (exact text: \(source.isExactText))")
print("FRAGMENTS       \(frags.count)")

guard case .success(let reading0) = PayslipReading.read(fragments: frags, source: source) else {
    if case .failure(let why) = PayslipReading.read(fragments: frags, source: source) {
        print("READING FAILED  \(why.rawValue)")
    }
    exit(1)
}

print("MONEY COLUMNS   \(reading0.moneyColumns.map { String(format: "%.3f", $0) }.joined(separator: "  "))")
print("UNREADABLE      \(reading0.unreadableTokens.count) token(s) \(reading0.unreadableTokens.prefix(8))")
print("LINES           \(reading0.lines.count), amounts \(reading0.amounts.count)")

let facts0 = PayslipClassifier.classify(reading0)

print("")
print("---- LINES -----------------------------------------------------------")
print("  # \(pad("label (normalised)", 34)) \(pad("value", 11)) \(pad("concept", 18)) \(pad("prov", 20)) conf")
for line in facts0.lines {
    let raw = reading0.lines.first { $0.index == line.lineIndex }
    print(" \(pad(String(line.lineIndex), 2)) \(pad(raw?.label ?? "", 34)) \(pad(euros(line.cents), 11)) "
          + "\(pad(line.concept?.rawValue ?? "-", 18)) \(pad(line.provenance.rawValue, 20)) \(line.confidence.name)"
          + (line.alternative != nil ? "   alt=\(line.alternative!.rawValue)" : "")
          + (line.repaired ? "   [repaired]" : ""))
}

print("")
print("---- FACTS -----------------------------------------------------------")
func showFact(_ name: String, _ f: PayslipFact?) {
    guard let f else { print("  \(pad(name, 20)) -"); return }
    print("  \(pad(name, 20)) \(pad(euros(f.cents), 12)) \(pad(f.provenance.rawValue, 20)) \(f.confidence.name)  lines \(f.lineIndexes)")
}
showFact("totalEarnings", facts0.totalEarnings)
showFact("totalDeductions", facts0.totalDeductions)
showFact("netPay", facts0.netPay)
showFact("ssBase", facts0.ssBase)
showFact("ssContribution", facts0.ssContribution)
showFact("irs", facts0.fact(.irs))
print("  \(pad("confirmedByNetIdentity", 20)) \(facts0.confirmedByNetIdentity)")
print("  \(pad("earningsRun", 20)) \(facts0.earningsRun)   gap \(euros(facts0.earningsGap))")
print("  \(pad("deductionsRun", 20)) \(facts0.deductionsRun)   gap \(euros(facts0.deductionsGap))")
print("  \(pad("disputed", 20)) \(facts0.disputed.map(\.lineIndex))")
print("  \(pad("isEmpty", 20)) \(facts0.isEmpty)")

let context = PayslipContext(region: .continente, months: 14, marital: .single,
                             dependents: 0, jovemExemption: 0)

// `--review` replays confirming the review screen with every figure re-entered
// exactly as it was shown.
//
// Measured against the running app: `edits` is EMPTY when the reader touches
// nothing, because the TextField's setter only fires on a real edit, and
// `applying` short-circuits on an empty map. So this mode is not the default
// path, it is the "reader retyped the same number" path, and it should produce
// the same verdict as no review at all. If it ever stops doing that, the round
// trip through format and parse has broken.
var facts = facts0
var reading = reading0
if args.contains("--review") {
    var edits: [Int: Int?] = [:]
    for line in facts0.lines where line.concept != nil && line.cents != nil {
        // Exactly what PayslipReviewStep does: format the figure, then parse
        // the formatted string back.
        edits[line.lineIndex] = PayslipNumber.cents(from: PayslipNumber.format(cents: line.cents!))
    }
    print("")
    print("---- REPLAYING AN UNTOUCHED REVIEW (\(edits.count) identity edits) ----")
    reading = reading.applying(edits)
    facts = PayslipClassifier.classify(reading)
    showFact("totalEarnings", facts.totalEarnings)
    showFact("totalDeductions", facts.totalDeductions)
    showFact("netPay", facts.netPay)
    showFact("ssBase", facts.ssBase)
    showFact("ssContribution", facts.ssContribution)
    showFact("irs", facts.fact(.irs))
    print("  \(pad("earningsRun", 20)) \(facts.earningsRun)   gap \(euros(facts.earningsGap))")
    print("  \(pad("deductionsRun", 20)) \(facts.deductionsRun)   gap \(euros(facts.deductionsGap))")
}

let verdict = PayslipReconciler.check(facts, context: context)

print("")
print("---- VERDICT (continente, 14 months, single, 0 dependants) -----------")
for f in verdict.findings.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
    print("  \(pad(f.tier.name, 8)) \(pad(f.id.rawValue, 16)) conf=\(pad(f.confidence.name, 7))"
          + " expected=\(pad(euros(f.expectedCents), 11)) actual=\(pad(euros(f.actualCents), 11))"
          + " delta=\(euros(f.deltaCents))")
}
print("")
for s in verdict.notChecked.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
    print("  skipped  \(pad(s.id.rawValue, 16)) \(s.reason.rawValue)")
}
print("")
print("SUMMARY  wrong=\(verdict.wrong.count)  mentions=\(verdict.mentions.count)  correct=\(verdict.correct.count)  notChecked=\(verdict.notChecked.count)")
