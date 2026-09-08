import Foundation
import SwiftUI
import CoreGraphics

/// v1.1: the payslip flow's state, and the only thing in the feature that holds
/// a picture.
///
/// It is an `ObservableObject` created by `PayslipCheckFlow` and destroyed with
/// it, which is the whole of the storage design: there is no history, nothing
/// reaches `SalaryStore`, and nothing reaches `UserDefaults`. `discard()` runs
/// on the way out so the image goes at dismissal rather than whenever the
/// object happens to be collected.
///
/// This is a stricter version of the `growScenario` precedent. That lives on
/// the store without a `didSet` so a hypothetical survives a tab swipe but not
/// a relaunch. Nothing here needs to survive anything, because the flow is a
/// full-screen cover, so it is plain view-owned state and the reading dies with
/// the screen.
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

    @Published private(set) var phase: Phase = .source
    /// Corrections made on the review screen, keyed by line index. Cleared with
    /// everything else on the way out.
    @Published var edits: [Int: Int?] = [:]

    /// The read in flight, held only so leaving can cancel it. See `discard`.
    private var reading: Task<Void, Never>?

    // MARK: Loading

    func load(url: URL, context: PayslipContext) {
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

    func load(imageData data: Data, context: PayslipContext) {
        phase = .reading
        reading?.cancel()
        reading = Task { await recogniseData(data, context: context) }
    }

    private func recogniseData(_ data: Data, context: PayslipContext) async {
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

    private func recognise(_ images: [CGImage], context: PayslipContext) async {
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

    private func finish(fragments: [PayslipFragment], source: PayslipSource, context: PayslipContext) {
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
    /// A PDF that carried its own text, read cleanly and agreed with itself has
    /// nothing to confirm: every figure came from the file rather than from a
    /// recogniser's opinion of it, and asking the reader to check figures the
    /// file supplied is ceremony. Anything recognised from pixels, anything we
    /// could not read, and anything whose label fought its arithmetic does stop
    /// here, because those are the cases where a wrong figure would otherwise
    /// become a wrong accusation.
    func needsReview(_ workings: Workings) -> Bool {
        if workings.reading.source == .ocr { return true }
        if !workings.reading.unreadableTokens.isEmpty { return true }
        if !workings.facts.disputed.isEmpty { return true }
        return false
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

    func confirmReview(context: PayslipContext) {
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
        phase = .source
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
        phase = .source
    }
}
