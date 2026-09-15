import Foundation
import SwiftUI
import CoreGraphics

/// v1.1: the payslip flow's state, and the only thing in the feature that holds
/// a picture.
///
/// v1.2 CHANGED HOW LONG IT LIVES, and the change is worth stating exactly.
///
/// Until now the checker was a full-screen cover, this object was created and
/// destroyed with it, and the app told the reader "close this screen and it is
/// gone". A tab has no closing moment, so that sentence had to go, and what
/// replaced it is narrower and still true: nothing is ever written to the
/// phone, there is no history, and the reading is replaced when the reader
/// checks another payslip or gone when the app quits. What is genuinely weaker
/// is the window: a verdict now sits in memory for as long as the app is alive
/// rather than until a screen closes.
///
/// Everything else holds. Nothing here reaches `SalaryStore`, nothing reaches
/// `UserDefaults`, and `restart()` still drops the image, the lines, the facts
/// and the verdict the moment the reader starts again. The onboarding route is
/// still a cover, and there the object still dies with the screen.
///
/// v1.4 CHANGED NOTHING ABOUT THE LIFETIME. It added one way in, `init(opensReading:)`
/// plus `load(_:context:)`, for a cover that is handed a file before it is
/// presented, so the reader is not asked where the payslip comes from twice.
/// Nothing is written to the phone, there is still no history, and `discard()`
/// and `restart()` drop exactly what they dropped before.
@MainActor
final class PayslipCheckModel: ObservableObject {

    /// The reading and what we made of it, kept together because the review
    /// screen shows the first and the verdict rests on the second.
    struct Workings {
        let reading: PayslipReading
        let facts: PayslipFacts
    }

    enum Phase {
        case source
        case reading
        /// Shown only when something needs the reader. See `needsReview`.
        case review(Workings)
        case results(PayslipVerdict, Workings)
        case unreadable(PayslipUnreadable)
    }

    /// Whether the reader has answered "should this become your salary?".
    ///
    /// v1.2: only needed because the checker is a tab now. In a cover, both
    /// answers dismissed the screen and the question could not be asked twice.
    /// Here the verdict stays on screen afterwards, so the ask has to know it
    /// has been answered and get out of the way.
    enum SalaryAsk {
        case unanswered
        /// They kept the figure they already had. Nothing more to say.
        case kept
        /// They took the payslip's figure. Worth confirming, because the number
        /// it changed is on a different tab.
        case adopted
    }

    @Published private(set) var phase: Phase = .source
    @Published private(set) var salaryAsk: SalaryAsk = .unanswered
    /// Corrections made on the review screen, keyed by line index. Cleared with
    /// everything else on the way out.
    @Published var edits: [Int: Int?] = [:]

    /// The read in flight, held only so leaving can cancel it. See `discard`.
    private var reading: Task<Void, Never>?

    /// `opensReading` exists so a cover that was handed a file on the way in
    /// does not flash its own picker first.
    ///
    /// The phase is set HERE and not in a `.task`, because a task runs after
    /// the first render: with `.source` as the initial phase the reader watches
    /// a file picker slide up and vanish again.
    init(opensReading: Bool = false) {
        if opensReading { phase = .reading }
    }

    // MARK: Loading

    /// The one entry point for an input picked before the flow was presented.
    ///
    /// Dispatches to the two loaders below rather than adding a third path into
    /// recognition. Rule 22 was earned by the same photograph giving different
    /// figures through the file and the Photos routes; the camera adds a new
    /// SOURCE, not a new decode path.
    func load(_ input: PayslipInput, context: PayslipContext?) {
        switch input.kind {
        case .file(let url): load(url: url, context: context)
        case .image(let data): load(imageData: data, context: context)
        }
    }

    func load(url: URL, context: PayslipContext?) {
        phase = .reading
        reading?.cancel()
        reading = Task {
            let outcome = await Task.detached { PayslipPDF.read(url: url) }.value
            guard !Task.isCancelled else { return }
            switch outcome {
            case .failure(.unsupportedFile):
                // The file picker offers images as well as PDFs, and PDFKit
                // returns nil for a JPEG. Read its bytes and recognise it
                // rather than telling the reader their photograph is not a
                // file, which is what they would hear.
                if let data = readScoped(url) {
                    await recogniseData(data, context: context)
                } else {
                    phase = .unreadable(.unsupportedFile)
                }
            case .failure(let why):
                phase = .unreadable(why)
            case .success(.text(let fragments, let source)):
                finish(fragments: fragments, source: source, context: context)
            case .success(.needsRecognition(let images)):
                await recognise(images, context: context)
            }
        }
    }

    func load(imageData data: Data, context: PayslipContext?) {
        phase = .reading
        reading?.cancel()
        reading = Task { await recogniseData(data, context: context) }
    }

    private func recogniseData(_ data: Data, context: PayslipContext?) async {
        guard let image = await Task.detached(operation: { PayslipOCR.image(from: data) }).value
        else { phase = .unreadable(.unsupportedFile); return }
        guard !Task.isCancelled else { return }
        await recognise([image], context: context)
    }

    /// Reads a picked file's bytes, opening the security scope the picker
    /// handed us and closing it straight afterwards.
    private func readScoped(_ url: URL) -> Data? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }

    private func recognise(_ images: [CGImage], context: PayslipContext?) async {
        let fragments = await Task.detached {
            images.flatMap { (try? PayslipOCR.fragments(in: $0)) ?? [] }
        }.value
        // Recognition cannot be interrupted part way, so the cancellation is
        // checked on the way out instead. Without this the phase written below
        // lands on a model whose screen has already gone, and reopening the
        // checker shows the previous file's verdict.
        guard !Task.isCancelled else { return }
        guard !fragments.isEmpty else { phase = .unreadable(.noTextFound); return }
        finish(fragments: fragments, source: .ocr, context: context)
    }

    private func finish(fragments: [PayslipFragment], source: PayslipSource, context: PayslipContext?) {
        switch PayslipReading.read(fragments: fragments, source: source) {
        case .failure(let why):
            phase = .unreadable(why)
        case .success(let reading):
            let facts = PayslipClassifier.classify(reading)
            // v1.1a: a reading can clear the not-a-payslip gate and still have
            // nothing in it we could name. Every check then skips, the results
            // screen finds no findings, and it says "nothing on this payslip
            // contradicts itself" over a page we failed to read. That sentence
            // is true of an empty page and worthless, which makes it the most
            // dishonest thing the feature could say. `PayslipFacts.isEmpty` was
            // written for this and read by nothing.
            guard !facts.isEmpty else {
                phase = .unreadable(.notAPayslip)
                return
            }
            let workings = Workings(reading: reading, facts: facts)
            phase = needsReview(workings) ? .review(workings)
                : .results(PayslipReconciler.check(facts, context: context), workings)
        }
    }

    /// Whether to stop and ask before showing a verdict.
    ///
    /// The rule itself is `PayslipReading.needsReview(facts:)`, in the Engine,
    /// so the probe can report it. See that comment for why it decides what it
    /// decides; this is only the view model's way in.
    func needsReview(_ workings: Workings) -> Bool {
        workings.reading.needsReview(facts: workings.facts)
    }

    // MARK: Review

    /// Lines the reader is being asked about, in page order.
    func reviewable(_ workings: Workings) -> [PayslipClassifiedLine] {
        workings.facts.lines.filter { $0.concept != nil && $0.cents != nil }
    }

    /// True when this line is one we are unsure of and should let them correct.
    func isUncertain(_ line: PayslipClassifiedLine, in workings: Workings) -> Bool {
        line.repaired
            || line.provenance == .disputed
            || line.confidence == .low
    }

    func confirmReview(context: PayslipContext?) {
        guard case .review(let workings) = phase else { return }
        let corrected = workings.reading.applying(edits)
        let facts = PayslipClassifier.classify(corrected)
        let updated = Workings(reading: corrected, facts: facts)
        phase = .results(PayslipReconciler.check(facts, context: context), updated)
    }

    // MARK: Leaving

    func restart() {
        reading?.cancel()
        reading = nil
        edits = [:]
        salaryAsk = .unanswered
        phase = .source
    }

    /// The reader answered the ask. Recorded here rather than in the results
    /// view so it survives the view being rebuilt, which it is on every tab
    /// switch.
    func answerSalaryAsk(adopted: Bool) {
        salaryAsk = adopted ? .adopted : .kept
    }

    /// Called from `onDisappear`. Nothing here is written anywhere, so this is
    /// only about letting the memory go at the moment the screen closes.
    ///
    /// v1.1a: cancelling the reading is part of that. Recognition runs on a
    /// detached task holding the page images, so before this cancelled it, a
    /// reader who opened the checker and closed it again left a full Vision
    /// pass running over a 3200 pixel image and the images alive until it
    /// finished. Nothing was written and nothing leaked, but the promise in the
    /// line above was not kept while a read was in flight.
    func discard() {
        reading?.cancel()
        reading = nil
        edits = [:]
        salaryAsk = .unanswered
        phase = .source
    }
}
