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
//     .build/payslip_probe <file.pdf|file.png> [--json] [--review]
//         [--region R] [--months N] [--marital M] [--dependents N] [--jovem F]
//         [--path auto|lines|bounds|raster] [--long-edge PX] [--raster-long-edge PX]
//
// `--json` prints the same information as one machine-readable object, for
// `tools/score_payslip_corpus.py` to read. It was advertised in this comment
// for a whole release before anything implemented it, which is its own small
// lesson: a documented flag that silently does nothing is worse than an
// undocumented one, because the caller believes it worked.

import Foundation
import CoreGraphics
import CryptoKit
import ImageIO
import PDFKit

// MARK: Formatting

func euros(_ cents: Int?) -> String {
    guard let cents else { return "-" }
    let sign = cents < 0 ? "-" : ""
    let a = abs(cents)
    return "\(sign)\(a / 100),\(String(format: "%02d", a % 100))"
}

/// A section rule padded to the width every other header in this dump uses, so
/// the VERDICT line can name the context it ran with and still line up.
func rule(_ title: String) -> String {
    let prefix = "---- \(title) "
    return prefix + String(repeating: "-", count: Swift.max(0, 70 - prefix.count))
}

/// 14 rather than 14.0, because months is a Double the reader never sees as one.
func monthsText(_ m: Double) -> String {
    m == m.rounded() ? String(Int(m)) : String(m)
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

extension PayslipSource {
    /// `PayslipSource` has no raw value, and the text dump has always relied on
    /// the compiler's own case name via interpolation. JSON needs the same
    /// string deliberately rather than incidentally.
    var name: String {
        switch self {
        case .pdfLines: return "pdfLines"
        case .pdfBounds: return "pdfBounds"
        case .ocr: return "ocr"
        }
    }
}

// MARK: Reading a file

/// Why a file produced no fragments. Two different failures, kept apart: the
/// PDF reader has its own reason enum, and an undecodable image has none.
enum ProbeReadFailure: Error {
    case unreadable(PayslipUnreadable)
    case couldNotDecode

    var reason: String {
        switch self {
        case .unreadable(let why): return why.rawValue
        case .couldNotDecode: return "couldNotDecode"
        }
    }
}

/// Which way to get fragments out of a PDF.
///
/// `auto` is `PayslipPDF.read`, exactly as the app calls it, and is the
/// default so the committed baseline never moves. The other three force one
/// path so all of them can be compared on ONE byte-identical file, which is
/// the only way to see what the reader's own strategy is choosing between.
/// `.pdfLines` builds its x coordinates from character offsets within the
/// extracted line, so its "columns" are a fact about label lengths rather than
/// about the page; `raster` throws the text layer away and hands Vision real
/// per-word extents instead. Which of those reads a given payslip better is an
/// open question and not a foregone conclusion.
enum ExtractionPath: String {
    case auto, lines, bounds, raster
}

/// A settable-size sibling of `PayslipPDF.raster`, which fixes its own output
/// at `rasterLongEdge`.
///
/// This is the CAMERA and not the reader. The app's rasteriser is only ever
/// asked for one size and should stay that way; the point of varying it here is
/// to find out what the recogniser does with a page that reached it bigger or
/// smaller than the app would have made it, which is the half of the range
/// `PayslipOCR.recognitionLongEdge`'s own measurement says was never tested.
/// Kept a faithful copy of the original otherwise: same white ground, same
/// mediaBox translation, same interpolation defaults.
func probeRaster(_ page: PDFPage, longEdge: Int) -> CGImage? {
    let box = page.bounds(for: .mediaBox)
    guard box.width > 0, box.height > 0 else { return nil }
    let scale = Double(longEdge) / Double(max(box.width, box.height))
    let width = Int((Double(box.width) * scale).rounded())
    let height = Int((Double(box.height) * scale).rounded())
    guard width > 0, height > 0,
          let context = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { return nil }
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    context.translateBy(x: -box.minX, y: -box.minY)
    page.draw(with: .mediaBox, to: context)
    return context.makeImage()
}

struct ProbeExtraction {
    let frags: [PayslipFragment]
    let source: PayslipSource
}

func fragments(of path: String, using route: ExtractionPath,
               longEdge: Int, rasterLongEdge: Int) -> Result<ProbeExtraction, ProbeReadFailure> {
    let url = URL(fileURLWithPath: path)
    if path.lowercased().hasSuffix(".pdf") {
        if route != .auto {
            guard let document = PDFDocument(url: url) else { return .failure(.unreadable(.unsupportedFile)) }
            if document.isEncrypted && document.isLocked { return .failure(.unreadable(.encryptedPDF)) }
            let pages = (0..<min(document.pageCount, PayslipPDF.maximumPages))
                .compactMap { document.page(at: $0) }
            guard !pages.isEmpty else { return .failure(.unreadable(.noTextFound)) }
            switch route {
            case .lines:
                return .success(ProbeExtraction(
                    frags: PayslipPDF.fragments(fromLinesOf: pages), source: .pdfLines))
            case .bounds:
                return .success(ProbeExtraction(
                    frags: PayslipPDF.fragments(fromBoundsOf: pages), source: .pdfBounds))
            case .raster:
                var all: [PayslipFragment] = []
                for page in pages {
                    guard let image = probeRaster(page, longEdge: rasterLongEdge) else { continue }
                    all += (try? PayslipOCR.fragments(in: image, longEdge: longEdge)) ?? []
                }
                return .success(ProbeExtraction(frags: all, source: .ocr))
            case .auto:
                break
            }
        }
        switch PayslipPDF.read(url: url) {
        case .success(.text(let frags, let source)):
            return .success(ProbeExtraction(frags: frags, source: source))
        case .success(.needsRecognition(let images)):
            FileHandle.standardError.write("  (no text layer, rasterised \(images.count) page(s) to Vision)\n".data(using: .utf8)!)
            var all: [PayslipFragment] = []
            for image in images {
                all += (try? PayslipOCR.fragments(in: image, longEdge: longEdge)) ?? []
            }
            return .success(ProbeExtraction(frags: all, source: .ocr))
        case .failure(let why):
            return .failure(.unreadable(why))
        }
    }
    guard let data = try? Data(contentsOf: url), let image = PayslipOCR.image(from: data) else {
        return .failure(.couldNotDecode)
    }
    return .success(ProbeExtraction(
        frags: (try? PayslipOCR.fragments(in: image, longEdge: longEdge)) ?? [], source: .ocr))
}

// MARK: JSON

/// `JSONSerialization` cannot take a Swift `nil`, so every optional becomes an
/// explicit null. Omitting the key instead would make "we did not find an IRS
/// figure" and "this build does not emit that key" the same observation, and
/// the scorer has to tell those apart.
func orNull(_ value: Any?) -> Any { value ?? NSNull() }

func factJSON(_ f: PayslipFact?) -> Any {
    guard let f else { return NSNull() }
    return ["cents": f.cents,
            "provenance": f.provenance.rawValue,
            "confidence": f.confidence.name,
            "lineIndexes": f.lineIndexes]
}

func evidenceJSON(_ e: PayslipEvidence) -> Any {
    switch e {
    case .none: return NSNull()
    case .region(let r): return ["kind": "region", "region": r.rawValue]
    case .rate(let hundredths): return ["kind": "rate", "hundredths": hundredths]
    }
}

func factsJSON(_ facts: PayslipFacts, reading: PayslipReading) -> [String: Any] {
    [
        "totalEarnings": factJSON(facts.totalEarnings),
        "totalDeductions": factJSON(facts.totalDeductions),
        "netPay": factJSON(facts.netPay),
        "ssBase": factJSON(facts.ssBase),
        "ssContribution": factJSON(facts.ssContribution),
        "irs": factJSON(facts.fact(.irs)),
        "confirmedByNetIdentity": facts.confirmedByNetIdentity,
        "earningsRun": facts.earningsRun,
        "earningsGap": orNull(facts.earningsGap),
        "deductionsRun": facts.deductionsRun,
        "deductionsGap": orNull(facts.deductionsGap),
        "disputed": facts.disputed.map(\.lineIndex),
        "isEmpty": facts.isEmpty,
        "lines": facts.lines.map { line -> [String: Any] in
            let raw = reading.lines.first { $0.index == line.lineIndex }
            return ["index": line.lineIndex,
                    "rawLabel": line.rawLabel,
                    "label": raw?.label ?? "",
                    "cents": orNull(line.cents),
                    "concept": orNull(line.concept?.rawValue),
                    "provenance": line.provenance.rawValue,
                    "confidence": line.confidence.name,
                    "alternative": orNull(line.alternative?.rawValue),
                    "statedRate": orNull(line.statedRate),
                    "baseCents": orNull(line.baseCents),
                    "repaired": line.repaired]
        },
    ]
}

func verdictJSON(_ verdict: PayslipVerdict) -> [String: Any] {
    [
        "wrong": verdict.wrong.count,
        "mentions": verdict.mentions.count,
        "correct": verdict.correct.count,
        "notCheckedCount": verdict.notChecked.count,
        "findings": verdict.findings
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { f -> [String: Any] in
                ["check": f.id.rawValue,
                 "tier": f.tier.rawValue,
                 "confidence": f.confidence.name,
                 "expectedCents": orNull(f.expectedCents),
                 "actualCents": orNull(f.actualCents),
                 "deltaCents": orNull(f.deltaCents),
                 "baseCents": orNull(f.baseCents),
                 "basis": f.basis.map(\.rawValue),
                 "evidence": evidenceJSON(f.evidence)]
            },
        "notChecked": verdict.notChecked
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { ["check": $0.check.rawValue, "reason": $0.reason.rawValue] },
    ]
}

func contextJSON(_ c: PayslipContext) -> [String: Any] {
    ["region": c.region.rawValue,
     "months": c.months,
     "marital": c.marital.rawValue,
     "dependents": c.dependents,
     "jovemExemption": c.jovemExemption]
}

func sha256(ofFileAt path: String) -> Any {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return NSNull() }
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

/// Sorted keys so two runs diff cleanly, per the rule that earned itself when
/// `JSONEncoder` ignored a custom `encode(to:)`'s key order and shipped a
/// silent re-upload on every launch.
func emit(_ object: [String: Any]) {
    guard let data = try? JSONSerialization.data(
        withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
        FileHandle.standardError.write("could not serialise\n".data(using: .utf8)!)
        exit(3)
    }
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write("\n".data(using: .utf8)!)
}

/// In `--json` mode a failure is an outcome and not a crash, so it exits 0 with
/// the reason in the object. Otherwise the scorer cannot tell a correct
/// rejection of a phone bill, which is the right answer for a negative
/// fixture, from the tool falling over.
func emitFailure(_ base: [String: Any], outcome: String, reason: String) -> Never {
    var out = base
    out["outcome"] = outcome
    out["reason"] = reason
    emit(out)
    exit(0)
}

// MARK: Main

func usage(_ complaint: String? = nil) -> Never {
    if let complaint {
        FileHandle.standardError.write("payslip_probe: \(complaint)\n".data(using: .utf8)!)
    }
    print("""
    usage: payslip_probe <file.pdf|file.png> [options]

      --json                 one machine-readable object instead of the dump
      --review               replay an untouched review and print what moved

      --region <r>           continente | acores | madeira   (default continente)
      --months <n>           paid months a year               (default 14)
      --marital <m>          single | marriedTwo | marriedOne (default single)
      --dependents <n>                                        (default 0)
      --jovem <f>            IRS Jovem exempt fraction        (default 0)

      --path <p>             auto | lines | bounds | raster   (default auto)
      --long-edge <px>       size the image reaches Vision at (default 3200)
      --raster-long-edge <px> size a PDF page is rasterised to (default 3200)
    """)
    exit(2)
}

/// Flags are validated rather than tolerated, and an unrecognised or malformed
/// one exits 2 instead of being skipped.
///
/// This is the house rule about not defaulting a parameter whose absence is a
/// silent wrong answer, pointed at the harness itself: a typo in `--region`
/// that quietly fell back to Continente would score a whole corpus against the
/// wrong tax tables and every number in the report would be wrong with nothing
/// on screen to say so.
let noValueFlags: Set<String> = ["--json", "--review"]
let valueFlags: Set<String> = ["--region", "--months", "--marital", "--dependents",
                               "--jovem", "--path", "--long-edge", "--raster-long-edge"]

var positional: [String] = []
var flags: [String: String] = [:]
var switches: Set<String> = []
do {
    let raw = Array(CommandLine.arguments.dropFirst())
    var i = 0
    while i < raw.count {
        let arg = raw[i]
        if arg.hasPrefix("--") {
            if noValueFlags.contains(arg) {
                switches.insert(arg)
                i += 1
            } else if valueFlags.contains(arg) {
                guard i + 1 < raw.count else { usage("\(arg) needs a value") }
                flags[arg] = raw[i + 1]
                i += 2
            } else {
                usage("unknown flag \(arg)")
            }
        } else {
            positional.append(arg)
            i += 1
        }
    }
}

guard let path = positional.first else { usage("no file given") }
if positional.count > 1 { usage("one file at a time, got \(positional.count)") }

let wantsJSON = switches.contains("--json")
let wantsReview = switches.contains("--review")

func stringFlag<T: RawRepresentable>(_ flag: String, _ fallback: T) -> T where T.RawValue == String {
    guard let given = flags[flag] else { return fallback }
    guard let value = T(rawValue: given) else { usage("bad value for \(flag): \(given)") }
    return value
}

func intFlag(_ flag: String, _ fallback: Int, min: Int = 1) -> Int {
    guard let given = flags[flag] else { return fallback }
    guard let value = Int(given), value >= min else { usage("bad value for \(flag): \(given)") }
    return value
}

func doubleFlag(_ flag: String, _ fallback: Double, min: Double, max: Double) -> Double {
    guard let given = flags[flag] else { return fallback }
    guard let value = Double(given), value >= min, value <= max else {
        usage("bad value for \(flag): \(given)")
    }
    return value
}

let route: ExtractionPath = stringFlag("--path", .auto)
let ocrLongEdge = intFlag("--long-edge", PayslipOCR.recognitionLongEdge)
let rasterLongEdge = intFlag("--raster-long-edge", PayslipPDF.rasterLongEdge)

let jsonBase: [String: Any] = [
    "file": URL(fileURLWithPath: path).lastPathComponent,
    "sha256": sha256(ofFileAt: path),
]

if !wantsJSON {
    print("======================================================================")
    print("FILE  \(URL(fileURLWithPath: path).lastPathComponent)")
    print("======================================================================")
}

let read = fragments(of: path, using: route,
                     longEdge: ocrLongEdge, rasterLongEdge: rasterLongEdge)
guard case .success(let extracted) = read else {
    guard case .failure(let failure) = read else { exit(1) }
    if wantsJSON {
        emitFailure(jsonBase, outcome: "unreadable", reason: failure.reason)
    }
    switch failure {
    case .unreadable(let why): print("unreadable: \(why.rawValue)")
    case .couldNotDecode: print("unreadable: could not decode \(path)")
    }
    exit(1)
}
let frags = extracted.frags
let source = extracted.source

if !wantsJSON {
    print("SOURCE          \(source) (exact text: \(source.isExactText))")
    print("FRAGMENTS       \(frags.count)")
}

let readingResult = PayslipReading.read(fragments: frags, source: source)
guard case .success(let reading0) = readingResult else {
    guard case .failure(let why) = readingResult else { exit(1) }
    if wantsJSON {
        var out = jsonBase
        out["source"] = source.name
        out["isExactText"] = source.isExactText
        out["fragments"] = frags.count
        emitFailure(out, outcome: "readingFailed", reason: why.rawValue)
    }
    print("READING FAILED  \(why.rawValue)")
    exit(1)
}

let facts0 = PayslipClassifier.classify(reading0)

if !wantsJSON {
    print("MONEY COLUMNS   \(reading0.moneyColumns.map { String(format: "%.3f", $0) }.joined(separator: "  "))")
    print("UNREADABLE      \(reading0.unreadableTokens.count) token(s) \(reading0.unreadableTokens.prefix(8))")
    print("LINES           \(reading0.lines.count), amounts \(reading0.amounts.count)")

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
}

func showFact(_ name: String, _ f: PayslipFact?) {
    guard let f else { print("  \(pad(name, 20)) -"); return }
    print("  \(pad(name, 20)) \(pad(euros(f.cents), 12)) \(pad(f.provenance.rawValue, 20)) \(f.confidence.name)  lines \(f.lineIndexes)")
}

func showFactsBlock(_ facts: PayslipFacts) {
    showFact("totalEarnings", facts.totalEarnings)
    showFact("totalDeductions", facts.totalDeductions)
    showFact("netPay", facts.netPay)
    showFact("ssBase", facts.ssBase)
    showFact("ssContribution", facts.ssContribution)
    showFact("irs", facts.fact(.irs))
}

if !wantsJSON {
    print("")
    print("---- FACTS -----------------------------------------------------------")
    showFactsBlock(facts0)
    print("  \(pad("confirmedByNetIdentity", 20)) \(facts0.confirmedByNetIdentity)")
    print("  \(pad("earningsRun", 20)) \(facts0.earningsRun)   gap \(euros(facts0.earningsGap))")
    print("  \(pad("deductionsRun", 20)) \(facts0.deductionsRun)   gap \(euros(facts0.deductionsGap))")
    print("  \(pad("disputed", 20)) \(facts0.disputed.map(\.lineIndex))")
    print("  \(pad("isEmpty", 20)) \(facts0.isEmpty)")
    showProposal(facts0)
}

// MARK: The salary this payslip would propose

/// What `PayslipSalary` would hand the app, printed so it can be diffed like
/// everything else. A judgement about a page cannot be checked by restating it
/// in Python, and this one decides the number every other number in the app is
/// derived from, so it belongs in the probe.
func showProposal(_ facts: PayslipFacts) {
    print("")
    print(rule("PROPOSAL"))
    switch PayslipSalary.propose(facts) {
    case .cannot(let why):
        print("  cannot propose a salary: \(why.rawValue)")
    case .proposal(let p):
        let corroboration: String
        switch p.corroboration {
        case .agreed(let total): corroboration = "agreed with total earnings \(euros(total))"
        case .notAvailable: corroboration = "no earnings total to cross-check against"
        }
        print("  \(pad("monthly gross", 20)) \(pad(euros(p.monthlyGrossCents), 12)) \(p.confidence.name)")
        print("  \(pad("ajudas + meal", 20)) \(euros(p.ajudasMonthlyCents))")
        print("  \(pad("corroboration", 20)) \(corroboration)")
        print("  \(pad("from lines", 20)) \(p.lineIndexes)")
        print("  \(pad("assumptions", 20)) \(p.assumptions.map(\.rawValue).joined(separator: ", "))")
    }
}

func proposalJSON(_ facts: PayslipFacts) -> [String: Any] {
    switch PayslipSalary.propose(facts) {
    case .cannot(let why):
        return ["outcome": "cannot", "refusal": why.rawValue]
    case .proposal(let p):
        var out: [String: Any] = [
            "outcome": "proposal",
            "monthlyGrossCents": p.monthlyGrossCents,
            "ajudasMonthlyCents": orNull(p.ajudasMonthlyCents),
            "confidence": p.confidence.name,
            "lineIndexes": p.lineIndexes,
            "assumptions": p.assumptions.map(\.rawValue),
        ]
        switch p.corroboration {
        case .agreed(let total):
            out["corroboration"] = "agreed"
            out["corroboratedAgainstCents"] = total
        case .notAvailable:
            out["corroboration"] = "notAvailable"
        }
        return out
    }
}

let context = PayslipContext(
    region: stringFlag("--region", TaxEngine.TaxRegion.continente),
    months: doubleFlag("--months", 14, min: 1, max: 14),
    marital: stringFlag("--marital", MaritalSituation.single),
    dependents: intFlag("--dependents", 0, min: 0),
    jovemExemption: doubleFlag("--jovem", 0, min: 0, max: 1))

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
var reviewEdits = 0
if wantsReview {
    var edits: [Int: Int?] = [:]
    for line in facts0.lines where line.concept != nil && line.cents != nil {
        // Exactly what PayslipReviewStep does: format the figure, then parse
        // the formatted string back.
        edits[line.lineIndex] = PayslipNumber.cents(from: PayslipNumber.format(cents: line.cents!))
    }
    reviewEdits = edits.count
    reading = reading.applying(edits)
    facts = PayslipClassifier.classify(reading)
    if !wantsJSON {
        print("")
        print("---- REPLAYING AN UNTOUCHED REVIEW (\(edits.count) identity edits) ----")
        showFactsBlock(facts)
        print("  \(pad("earningsRun", 20)) \(facts.earningsRun)   gap \(euros(facts.earningsGap))")
        print("  \(pad("deductionsRun", 20)) \(facts.deductionsRun)   gap \(euros(facts.deductionsGap))")
    }
}

let verdict = PayslipReconciler.check(facts, context: context)

if wantsJSON {
    var out = jsonBase
    out["outcome"] = "ok"
    out["source"] = source.name
    out["isExactText"] = source.isExactText
    out["fragments"] = frags.count
    out["moneyColumns"] = reading0.moneyColumns.map { (($0 * 1_000_000).rounded() / 1_000_000) }
    out["unreadableTokens"] = reading0.unreadableTokens
    out["lineCount"] = reading0.lines.count
    out["amountCount"] = reading0.amounts.count
    out["facts"] = factsJSON(facts0, reading: reading0)
    out["verdict"] = verdictJSON(verdict)
    out["context"] = contextJSON(context)
    out["needsReview"] = reading0.needsReview(facts: facts0)
    out["proposal"] = proposalJSON(facts0)
    out["extractionPath"] = route.rawValue
    out["ocrLongEdge"] = ocrLongEdge
    out["rasterLongEdge"] = rasterLongEdge
    out["reviewReplayed"] = wantsReview
    if wantsReview {
        out["reviewEdits"] = reviewEdits
        out["reviewFacts"] = factsJSON(facts, reading: reading)
    }
    emit(out)
    exit(0)
}

print("")
print(rule("VERDICT (\(context.region.rawValue), \(monthsText(context.months)) months, "
           + "\(context.marital.rawValue), \(context.dependents) dependants)"))
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
