import Foundation
import Vision
import CoreGraphics
import ImageIO

/// v1.1: recognising a photographed payslip, on the device, and never anywhere
/// else.
///
/// Every number in the doc comments below was measured on this project's real
/// payslips rather than assumed, and three of them are the reason this file
/// does not do the obvious thing:
///
///  - **The document API is not used.** iOS 26's `RecognizeDocumentsRequest`
///    returns real tables, which is exactly what a payslip is, and it is worse.
///    On a real payslip it read 301,60 as 301,50 and invented a 187,60 beside a
///    correct 187,90; on a second real payslip it found no tables at all. Plain
///    text recognition read every one of those correctly. So the text comes
///    from here and the geometry is done in `PayslipLayout`.
///  - **Confidence is recorded and never branched on.** With language
///    correction on, Vision reports 1.000 for lines the raw recogniser scored
///    0.30. It is a language model's certainty about plausible Portuguese, not
///    a statement about the digits. Nothing here or downstream may read it to
///    decide whether a figure is right; the arithmetic does that.
///  - **The revision is pinned.** An OS update that changed the default
///    revision would silently invalidate every measurement behind this feature,
///    with no error and no crash.
enum PayslipOCR {

    /// The long edge every image is brought to before recognition, up or down.
    ///
    /// This began as a baseline plus a multiplier, and that was wrong twice
    /// over. A baseline is a maximum, so a small screenshot reached the
    /// recogniser at 3150px while a phone photo would have reached it at
    /// 6000px: not one setting but two. And the multiplier appeared to matter
    /// only because its 1x case skipped the resample entirely.
    ///
    /// Measured by sweeping this number against a payslip whose figures are
    /// known and comparing every one of them by position:
    ///
    ///     target   1400  2000  2600  3200  3800  4400  5000
    ///     exact     3/3   3/3   3/3   3/3   2/3   3/3   3/3
    ///
    /// So the size barely matters and **the resample is what helps.** Handing
    /// Vision the same picture redrawn at a normalised size with
    /// `.high` interpolation reads digits it otherwise misses, at 1400px as
    /// well as at 5000px. Recognition time is flat across that whole range
    /// (0.35s to 0.43s on this Mac), so the number is chosen for memory and
    /// for how little it throws away from a real photograph rather than for
    /// accuracy.
    ///
    /// What this measurement does NOT cover: both test images are smaller than
    /// this and were scaled UP to reach it. A genuinely high-resolution
    /// photograph being scaled DOWN has not been tested, which is the other
    /// half of the range and the half every real camera will use. 3200 is
    /// deliberately high enough that a 12 megapixel photo loses little on the
    /// way in.
    static let recognitionLongEdge = 3200

    /// Vision has no European Portuguese. Brazilian is the closest it offers
    /// and the recogniser is character level with a language model on top, so
    /// the orthography differences barely touch the words and do not touch the
    /// digits at all. Deliberate; not to be "fixed" to pt-PT, which silently
    /// falls back to English.
    static let recognitionLanguages = ["pt-BR"]

    /// Below this the page is treated as level. Above it, the median line angle
    /// is rotated out before rows are grouped.
    static let minimumDeskewDegrees = 0.3
    static let maximumDeskewDegrees = 15.0

    // MARK: Decoding

    /// An upright `CGImage` at the baseline size.
    ///
    /// ImageIO applies the EXIF orientation and does the downscale in the same
    /// pass, so there is never a moment where some coordinates are in the
    /// camera's frame and others are in the picture's. A photograph taken in
    /// portrait and stored as landscape-with-a-flag is the ordinary case here,
    /// not an edge case.
    static func image(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        // Capped at the recognition size, so a 48 megapixel photo is never
        // fully decoded. Smaller images come back untouched and are scaled up
        // in `fragments(in:)`.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: recognitionLongEdge,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // MARK: Recognition

    /// `longEdge` is a parameter only so the verification sweep can vary it.
    /// Nothing in the app passes anything but the default.
    static func fragments(in image: CGImage,
                          longEdge: Int = recognitionLongEdge) throws -> [PayslipFragment] {
        let enlarged = scaled(image, toLongEdge: longEdge) ?? image
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = recognitionLanguages
        request.usesLanguageCorrection = true
        request.revision = VNRecognizeTextRequestRevision3

        try VNImageRequestHandler(cgImage: enlarged, options: [:]).perform([request])
        let observations = request.results ?? []
        guard !observations.isEmpty else { return [] }

        let aspect = Double(enlarged.width) / Double(max(enlarged.height, 1))
        let words = observations.flatMap { split($0) }
        return deskewed(words, byMedianOf: observations, aspect: aspect)
    }

    /// Brings the image to the recognition size.
    private static func scaled(_ image: CGImage, toLongEdge target: Int) -> CGImage? {
        let current = max(image.width, image.height)
        guard current > 0, current != target else { return image }
        let factor = Double(target) / Double(current)
        let width = Int((Double(image.width) * factor).rounded())
        let height = Int((Double(image.height) * factor).rounded())
        guard width > 0, height > 0 else { return image }
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// One observation into one fragment per word, each with its own extent.
    ///
    /// `boundingBox(for:)` on the recognised text is what replaces the document
    /// API: real per-word x extents, which is all the column detection in
    /// `PayslipLayout` needs, without the document API's damage to the digits.
    private static func split(_ observation: VNRecognizedTextObservation) -> [PayslipFragment] {
        guard let candidate = observation.topCandidates(1).first else { return [] }
        let text = candidate.string
        var out: [PayslipFragment] = []
        var start = text.startIndex

        while start < text.endIndex {
            let end = text[start...].firstIndex(of: " ") ?? text.endIndex
            let word = String(text[start..<end])
            if !word.isEmpty {
                // The whole observation's box is the fallback: a word we cannot
                // place is still a word we read, and dropping it would lose an
                // amount rather than merely misplace it.
                let box = (try? candidate.boundingBox(for: start..<end))?.boundingBox
                    ?? observation.boundingBox
                out.append(PayslipFragment(
                    text: word,
                    x0: Double(box.minX), x1: Double(box.maxX),
                    // Vision's origin is bottom left and y grows up.
                    // PayslipFragment's is top left and y grows down.
                    y0: 1 - Double(box.maxY), y1: 1 - Double(box.minY)))
            }
            start = end < text.endIndex ? text.index(after: end) : text.endIndex
        }
        return out
    }

    // MARK: Deskew

    /// Rotates the median line angle out of a hand-held photograph.
    ///
    /// Row grouping tolerates a little slope and then stops: past about a
    /// degree, a line that starts in one row ends in the next one across the
    /// width of a page. The angle comes from the recogniser's own corner points,
    /// so this costs one pass over data Vision already returned.
    ///
    /// Rotation happens in an aspect-corrected space. Normalised coordinates
    /// squash a page into a unit square, and rotating in that square turns a
    /// 1.4 degree tilt into something else entirely on A4.
    static func deskewed(_ fragments: [PayslipFragment],
                         byMedianOf observations: [VNRecognizedTextObservation],
                         aspect: Double) -> [PayslipFragment] {
        var angles: [Double] = []
        for observation in observations {
            let left = observation.topLeft, right = observation.topRight
            let dx = Double(right.x - left.x) * aspect
            let dy = Double(right.y - left.y)
            guard abs(dx) > 1e-6 else { continue }
            angles.append(atan2(dy, dx) * 180 / .pi)
        }
        guard !angles.isEmpty else { return fragments }
        angles.sort()
        let median = angles[angles.count / 2]
        guard abs(median) >= minimumDeskewDegrees, abs(median) <= maximumDeskewDegrees else {
            return fragments
        }

        // Vision measures the angle with y growing up; fragments have y growing
        // down, which flips the direction the correction has to turn.
        let radians = median * .pi / 180
        let cosine = cos(radians), sine = sin(radians)

        return fragments.map { fragment in
            let x = fragment.xMid * aspect - 0.5 * aspect
            let y = fragment.yMid - 0.5
            let rx = (x * cosine - y * sine + 0.5 * aspect) / aspect
            let ry = x * sine + y * cosine + 0.5
            let halfWidth = fragment.width / 2, halfHeight = fragment.height / 2
            return PayslipFragment(text: fragment.text,
                                   x0: rx - halfWidth, x1: rx + halfWidth,
                                   y0: ry - halfHeight, y1: ry + halfHeight)
        }
    }
}
