// tools/payslip_corpus: generates payslips whose true figures are known.
//
// The payslip reader has never been measured. It was built against two real
// payslips, both of which are gone from this machine by design, and its four
// judgement files have no automated coverage at all. Real payslips cannot fill
// that gap: they carry a name, an employer, a tax number and a salary, they are
// permanently gitignored, and they have no answer key even when you have one.
//
// So this generates them. Every figure comes from the app's own `TaxEngine`,
// which means the corpus has something real payslips never have: truth. What it
// costs is that the corpus cannot say whether the tax tables are right, only
// whether the right cents came off the page. That is the trade and it is a good
// one, because the tables already have a checker and the reader does not.
//
//     tools/payslip_corpus/build.sh
//     .build/payslip_corpus list
//     .build/payslip_corpus generate --out docs/fixtures/corpus

import Foundation
import CoreGraphics
import CryptoKit
import PDFKit

/// A settable-size rasteriser. This is the CAMERA and not the reader: the app's
/// own `PayslipPDF.raster` fixes its output at one size and should stay that
/// way, while the whole point here is to vary what the recogniser is handed.
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

let chromeDefault = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

func sha256Hex(_ url: URL) -> String {
    guard let data = try? Data(contentsOf: url) else { return "" }
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("payslip_corpus: \(message)\n".data(using: .utf8)!)
    exit(1)
}

func usage() -> Never {
    print("""
    usage: payslip_corpus <command> [options]

      list                       every fixture id and what it is for
      generate --out <dir>       write html, pdf and truth json
        --only <id>              just one fixture
        --no-pdf                 skip Chrome, write html and truth only
        --chrome <path>          override the Chrome binary

      photos --out <dir>         rasterise every pdf and degrade it into
                                 something a phone camera might have produced
        --only <id>              just one fixture
        --profiles a,b,c         default: every profile

    Every figure on every page comes from TaxEngine. Nothing here types a euro
    amount, which is why the corpus has an answer key and a real payslip cannot.
    """)
    exit(2)
}

// MARK: Arguments

let argv = Array(CommandLine.arguments.dropFirst())
guard let command = argv.first, !command.hasPrefix("--") else { usage() }

var options: [String: String] = [:]
var switches: Set<String> = []
do {
    let valueFlags: Set<String> = ["--out", "--only", "--chrome", "--profiles"]
    let noValue: Set<String> = ["--no-pdf"]
    var i = 1
    while i < argv.count {
        let arg = argv[i]
        guard arg.hasPrefix("--") else { usage() }
        if noValue.contains(arg) {
            switches.insert(arg); i += 1
        } else if valueFlags.contains(arg) {
            guard i + 1 < argv.count else { fail("\(arg) needs a value") }
            options[arg] = argv[i + 1]; i += 2
        } else {
            fail("unknown flag \(arg)")
        }
    }
}

// MARK: list

if command == "list" {
    let all = fixtures()
    print("\(all.count) fixture(s)\n")
    for f in all {
        let inject = f.injection.map { "  [injected \($0.concept.rawValue) \($0.deltaCents)c]" } ?? ""
        print("  \(f.id)")
        print("    family \(f.family), \(f.style.rawValue), \(f.region.rawValue), "
              + "\(monthsText(f.months)) months, gross \(printedMoney(f.monthlyGrossCents, f.style))\(inject)")
        if !f.expectedSkips.isEmpty {
            print("    expected skips: \(f.expectedSkips.sorted().joined(separator: ", "))")
        }
    }
    exit(0)
}

guard command == "generate" || command == "photos" else { usage() }
guard let outPath = options["--out"] else { fail("generate needs --out") }

let out = URL(fileURLWithPath: outPath, isDirectory: true)
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

var selected = fixtures()
if let only = options["--only"] {
    selected = selected.filter { $0.id == only }
    guard !selected.isEmpty else { fail("no fixture with id \(only)") }
}

// MARK: photos

if command == "photos" {
    let photosDir = out.appendingPathComponent("photos")
    try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

    var wanted = profiles
    if let names = options["--profiles"] {
        let set = Set(names.split(separator: ",").map(String.init))
        wanted = profiles.filter { set.contains($0.name) }
        guard !wanted.isEmpty else { fail("no profile named in \(names)") }
    }

    var written: [[String: Any]] = []
    for f in selected {
        let pdfURL = out.appendingPathComponent("\(f.id).pdf")
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            fail("no \(f.id).pdf. Run generate first.")
        }
        guard let document = PDFDocument(url: pdfURL), let page = document.page(at: 0) else {
            fail("could not open \(f.id).pdf")
        }
        for profile in wanted {
            guard let raster = probeRaster(page, longEdge: profile.captureLongEdge) else {
                fail("could not rasterise \(f.id) at \(profile.captureLongEdge)")
            }
            guard let degraded = degrade(raster, with: profile) else {
                fail("could not degrade \(f.id) with \(profile.name)")
            }
            let jpegURL = photosDir.appendingPathComponent("\(f.id).\(profile.name).jpg")
            guard writeJPEG(degraded, to: jpegURL, quality: profile.jpegQuality) else {
                fail("could not write \(jpegURL.lastPathComponent)")
            }
            written.append([
                "id": f.id, "profile": profile.name,
                "file": "photos/" + jpegURL.lastPathComponent,
                "truth": "\(f.id).truth.json",
                "captureLongEdge": profile.captureLongEdge,
                "sha256": sha256Hex(jpegURL),
            ])
        }
        print("  \(f.id)  \(wanted.count) profile(s)")
    }

    let photoManifest: [String: Any] = [
        "generated": written.count,
        "photos": written.sorted {
            (($0["id"] as! String) + ($0["profile"] as! String))
                < (($1["id"] as! String) + ($1["profile"] as! String))
        },
    ]
    if let data = try? JSONSerialization.data(withJSONObject: photoManifest,
                                              options: [.prettyPrinted, .sortedKeys]) {
        try? data.write(to: out.appendingPathComponent("photos.json"))
    }
    print("\nwrote \(written.count) image(s) to \(photosDir.path)")
    exit(0)
}

// MARK: The generator checks itself first

var complaints: [Complaint] = []
for f in selected { complaints += hardChecks(f) }
if !complaints.isEmpty {
    FileHandle.standardError.write("the generator disagrees with itself, nothing written:\n"
        .data(using: .utf8)!)
    for c in complaints {
        FileHandle.standardError.write("  \(c.fixture): \(c.detail)\n".data(using: .utf8)!)
    }
    exit(1)
}
print("self-checks pass: money round-trips, totals sum, net identity holds")

// MARK: What the lexicon does with the corpus's own words

let reports = selected.flatMap(labelReport)
// Deduplicated by label, not listed per fixture: the same vocabulary is reused
// across the corpus on purpose, and one line per distinct disagreement is the
// readable form. Labels the corpus deliberately put outside the lexicon (the
// `unknown` source, which is the whole point of the year-to-date trap) are not
// disagreements, they are the fixture working.
let disagreements = Array(
    Dictionary(grouping: reports.filter { $0.disagrees && $0.source != .unknown },
               by: { "\($0.label)|\($0.declared?.rawValue ?? "nil")" })
        .values.compactMap(\.first)
).sorted { $0.label < $1.label }
let borrowed = reports.filter(\.verbatimInFixtures).count
print("labels: \(reports.count) with a concept, \(borrowed) verbatim in "
      + "PayslipLexicon.matchFixtures, \(reports.count - borrowed) attested but not in it")
if !disagreements.isEmpty {
    print("")
    print("  the lexicon reads \(disagreements.count) distinct label(s) differently from the")
    print("  fixture that prints them.")
    print("  This is a finding about the reader, not a generator failure, so the corpus is")
    print("  still written. Look at it before trusting any concept-level score.")
    for r in disagreements {
        print("    '\(r.label)' declared \(r.declared?.rawValue ?? "nil"), "
              + "lexicon says \(r.lexiconSays?.rawValue ?? "nil")")
    }
}

// MARK: Writing

/// Chrome, with exactly the flags `docs/fixtures/README.md` already documents
/// and no others.
///
/// It is tempting to add `--user-data-dir` so a headless run cannot touch the
/// real browser profile. Measured: it HANGS. A fresh profile directory sends
/// Chrome 152 into first-run work it never comes out of in print-to-pdf mode,
/// and `--no-first-run --no-default-browser-check` does not rescue it; the
/// generator then waits for ever with no error and no output. The documented
/// command returns in about a second, with the user's own Chrome running at the
/// same time and undisturbed, so that is what this uses.
func printPDF(html: URL, to pdf: URL, chrome: String) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: chrome)
    process.arguments = [
        "--headless", "--no-pdf-header-footer",
        "--print-to-pdf=" + pdf.path,
        "file://" + html.path,
    ]
    // Chrome's output goes to a FILE and not to a Pipe. Headless Chrome writes
    // more than 64KB of noise to stderr, and a Pipe that is only drained after
    // waitUntilExit fills its buffer and deadlocks: Chrome blocks writing,
    // this blocks waiting, and the generator hangs for ever with no error.
    let logURL = out.appendingPathComponent(".chrome.log")
    FileManager.default.createFile(atPath: logURL.path, contents: nil)
    if let log = try? FileHandle(forWritingTo: logURL) {
        process.standardError = log
        process.standardOutput = log
    }
    do { try process.run() } catch { return false }
    process.waitUntilExit()
    return process.terminationStatus == 0
        && FileManager.default.fileExists(atPath: pdf.path)
}

let chrome = options["--chrome"] ?? chromeDefault
let wantsPDF = !switches.contains("--no-pdf")
if wantsPDF && !FileManager.default.isExecutableFile(atPath: chrome) {
    fail("no Chrome at \(chrome). Pass --chrome, or --no-pdf to write html and truth only.")
}

var manifest: [[String: Any]] = []
print("")
for f in selected {
    let htmlURL = out.appendingPathComponent("\(f.id).html")
    let pdfURL = out.appendingPathComponent("\(f.id).pdf")
    let truthURL = out.appendingPathComponent("\(f.id).truth.json")

    try? html(for: f).write(to: htmlURL, atomically: true, encoding: .utf8)

    var wrotePDF = false
    if wantsPDF { wrotePDF = printPDF(html: htmlURL, to: pdfURL, chrome: chrome) }
    if wantsPDF && !wrotePDF {
        let log = (try? String(contentsOf: out.appendingPathComponent(".chrome.log"),
                               encoding: .utf8)) ?? ""
        fail("Chrome could not print \(f.id)\n" + String(log.suffix(1200)))
    }

    // .sortedKeys so two runs diff cleanly, per the rule that earned itself
    // when JSONEncoder ignored a custom encode(to:)'s key order.
    if let data = try? JSONSerialization.data(withJSONObject: truthJSON(f),
                                              options: [.prettyPrinted, .sortedKeys]) {
        try? data.write(to: truthURL)
    }

    var entry: [String: Any] = [
        "id": f.id, "family": f.family,
        "html": htmlURL.lastPathComponent,
        "truth": truthURL.lastPathComponent,
        "htmlSHA256": sha256Hex(htmlURL),
    ]
    // The PDF's hash is deliberately NOT recorded. Chrome stamps a creation
    // date into every file it prints, so the same HTML gives a different PDF
    // every run, and a manifest field that cannot be reproduced is worse than
    // no field: it makes `git status` dirty on every regeneration and teaches
    // the reader to ignore a mismatch. The html and truth hashes pin the
    // content, and the PDF is a derived artefact of it.
    if wrotePDF { entry["pdf"] = pdfURL.lastPathComponent }
    manifest.append(entry)
    print("  \(f.id)\(wrotePDF ? "  pdf" : "  html only")")
}

let manifestObject: [String: Any] = [
    "generated": manifest.count,
    "fixtures": manifest.sorted { ($0["id"] as! String) < ($1["id"] as! String) },
]
if let data = try? JSONSerialization.data(withJSONObject: manifestObject,
                                          options: [.prettyPrinted, .sortedKeys]) {
    try? data.write(to: out.appendingPathComponent("manifest.json"))
}

// Chrome's chatter is not part of the corpus.
try? FileManager.default.removeItem(at: out.appendingPathComponent(".chrome.log"))

print("\nwrote \(manifest.count) fixture(s) to \(out.path)")
