// Turning a clean page into something a phone camera might have produced.
//
// The app has no camera of its own: images arrive through `PhotosPicker`, so
// the real input is a photo taken with the Camera app, typically 12 megapixels,
// which `PayslipOCR.image(from:)` then decodes DOWN to 3200px. Down is the
// direction that matters, and `PayslipOCR.recognitionLongEdge`'s own comment
// says so: its sweep scaled both test images UP, and it names the scale-down
// half as untested and as "the half every real camera will use".
//
// A clean 3200px raster of a PDF would therefore flatter the recogniser and
// test almost nothing. Everything below exists to stop that.
//
// WHAT THIS IS NOT: a phone photo. An iPhone does its own sharpening, tone
// mapping and JPEG, and Vision was trained on the output of pipelines like it.
// Simulated blur plus noise is a lower bound on realism, not a substitute, and
// the only thing that closes the gap is photographing a printed page. Crumple
// and paper texture are deliberately absent rather than badly faked.

import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Deterministic noise. NOT `CIRandomGenerator`, which cannot be seeded: with
/// it, running the same profile twice would produce different files and the
/// corpus would stop being a corpus.
struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    /// -1.0 ..< 1.0
    mutating func signed() -> Double {
        Double(next() >> 11) / Double(1 << 53) * 2 - 1
    }
}

struct Degradation {
    var name: String
    /// Long edge the page is rasterised at: the camera's sensor, not the
    /// reader's resample. 4032 and 3024 are the scale-down half.
    var captureLongEdge: Int
    var rotationDegrees: Double = 0
    /// Corner pull as a fraction of width. The axis deskew structurally cannot
    /// fix, because one median line angle cannot straighten a trapezoid.
    var perspective: Double = 0
    var gaussianBlur: Double = 0
    var noiseSigma: Double = 0
    var brightness: Double = 0
    var contrast: Double = 1
    /// A shadow falling across the page, 0 to 1. Uneven light hurts far more
    /// than uniform brightness, which a modern recogniser barely notices.
    var shadow: Double = 0
    var jpegQuality: Double = 0.95
    var seed: UInt64 = 0x5A1A21
}

let profiles: [Degradation] = [
    // A PDF we rasterised ourselves. Not a photo at all, and the honest
    // baseline for an emailed payslip.
    Degradation(name: "clean", captureLongEdge: 3200, jpegQuality: 0.98),

    Degradation(name: "scan300", captureLongEdge: 3508, rotationDegrees: 0.4,
                noiseSigma: 0.01, jpegQuality: 0.9),

    // A careful photo: flat on a desk, good light, held straight.
    Degradation(name: "photoGood", captureLongEdge: 4032, rotationDegrees: 1.2,
                perspective: 0.015, gaussianBlur: 0.6, noiseSigma: 0.015,
                brightness: 0.02, contrast: 1.02, shadow: 0.08, jpegQuality: 0.85),

    // The ordinary case: held in one hand, indoor light, slightly angled.
    Degradation(name: "photoTypical", captureLongEdge: 3024, rotationDegrees: 3.5,
                perspective: 0.045, gaussianBlur: 1.3, noiseSigma: 0.03,
                brightness: -0.04, contrast: 0.94, shadow: 0.22, jpegQuality: 0.7),

    // Poor light, a real angle, a lower-resolution capture.
    Degradation(name: "photoPoor", captureLongEdge: 2268, rotationDegrees: 7,
                perspective: 0.08, gaussianBlur: 2.2, noiseSigma: 0.055,
                brightness: -0.1, contrast: 0.85, shadow: 0.4, jpegQuality: 0.5),

    // Past what anyone should expect to work. Here to find where it breaks,
    // and a failure at this level is information rather than a defect.
    Degradation(name: "photoAwful", captureLongEdge: 1400, rotationDegrees: 13,
                perspective: 0.12, gaussianBlur: 3.5, noiseSigma: 0.09,
                brightness: -0.16, contrast: 0.78, shadow: 0.6, jpegQuality: 0.35),
]

let ciContext = CIContext(options: [.useSoftwareRenderer: false])

func degrade(_ image: CGImage, with d: Degradation) -> CGImage? {
    var ci = CIImage(cgImage: image)
    let start = ci.extent

    // Perspective first, in the page's own frame: one corner pulled in, which
    // is what holding a piece of paper at an angle actually does.
    if d.perspective > 0 {
        let pull = d.perspective * start.width
        guard let f = CIFilter(name: "CIPerspectiveTransform") else { return nil }
        f.setValue(ci, forKey: kCIInputImageKey)
        // A KEYSTONE, not a shear. Tilting a sheet away from the camera makes
        // the far edge narrower and slightly shorter, and rows stay rows.
        //
        // The first version of this pulled the top-left and bottom-right
        // corners in, which is a different distortion entirely: it slid the
        // left of the page vertically against the right, so on a wide payslip
        // every amount on the right drifted a whole row against its label on
        // the left, and the reader paired each value with the line above it. A
        // perspective that is really a shear measures the wrong thing, and it
        // made a gentle profile score worse than a rough one.
        f.setValue(CIVector(x: start.minX + pull, y: start.maxY - pull * 0.15),
                   forKey: "inputTopLeft")
        f.setValue(CIVector(x: start.maxX - pull, y: start.maxY - pull * 0.15),
                   forKey: "inputTopRight")
        f.setValue(CIVector(x: start.minX, y: start.minY), forKey: "inputBottomLeft")
        f.setValue(CIVector(x: start.maxX, y: start.minY), forKey: "inputBottomRight")
        ci = f.outputImage ?? ci
    }

    if d.rotationDegrees != 0 {
        let radians = d.rotationDegrees * .pi / 180
        ci = ci.transformed(by: CGAffineTransform(rotationAngle: radians))
    }

    if d.brightness != 0 || d.contrast != 1 {
        guard let f = CIFilter(name: "CIColorControls") else { return nil }
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(d.brightness, forKey: kCIInputBrightnessKey)
        f.setValue(d.contrast, forKey: kCIInputContrastKey)
        ci = f.outputImage ?? ci
    }

    // A gradient across the page, multiplied in. Uneven light, not a dimmer.
    if d.shadow > 0 {
        let e = ci.extent
        guard let gradient = CIFilter(name: "CILinearGradient") else { return nil }
        gradient.setValue(CIVector(x: e.minX, y: e.midY), forKey: "inputPoint0")
        gradient.setValue(CIVector(x: e.maxX, y: e.midY), forKey: "inputPoint1")
        let dark = 1 - d.shadow
        gradient.setValue(CIColor(red: dark, green: dark, blue: dark), forKey: "inputColor0")
        gradient.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor1")
        if let ramp = gradient.outputImage?.cropped(to: e),
           let multiply = CIFilter(name: "CIMultiplyBlendMode") {
            multiply.setValue(ramp, forKey: kCIInputImageKey)
            multiply.setValue(ci, forKey: kCIInputBackgroundImageKey)
            ci = multiply.outputImage ?? ci
        }
    }

    if d.gaussianBlur > 0 {
        guard let f = CIFilter(name: "CIGaussianBlur") else { return nil }
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(d.gaussianBlur, forKey: kCIInputRadiusKey)
        // Blur grows the extent; crop back so the page keeps its size.
        ci = (f.outputImage ?? ci).cropped(to: ci.extent)
    }

    // Everything above left transparent corners where the page was rotated or
    // skewed. A photograph has a background, not a hole.
    let extent = ci.extent.integral
    guard extent.width > 0, extent.height > 0,
          let white = CIFilter(name: "CIConstantColorGenerator") else { return nil }
    white.setValue(CIColor(red: 0.96, green: 0.96, blue: 0.95), forKey: "inputColor")
    if let ground = white.outputImage?.cropped(to: extent),
       let over = CIFilter(name: "CISourceOverCompositing") {
        over.setValue(ci, forKey: kCIInputImageKey)
        over.setValue(ground, forKey: kCIInputBackgroundImageKey)
        ci = over.outputImage ?? ci
    }

    guard var out = ciContext.createCGImage(ci, from: extent) else { return nil }
    if d.noiseSigma > 0 { out = addNoise(out, sigma: d.noiseSigma, seed: d.seed) ?? out }
    return out
}

/// Sensor noise, added in pixel space so it is exactly reproducible.
func addNoise(_ image: CGImage, sigma: Double, seed: UInt64) -> CGImage? {
    let width = image.width, height = image.height
    guard let context = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let raw = context.data else { return nil }
    let pixels = raw.bindMemory(to: UInt8.self, capacity: width * height * 4)

    var rng = SplitMix64(state: seed)
    let amplitude = sigma * 255
    for i in stride(from: 0, to: width * height * 4, by: 4) {
        let shift = rng.signed() * amplitude
        for channel in 0..<3 {
            let value = Double(pixels[i + channel]) + shift
            pixels[i + channel] = UInt8(Swift.max(0, Swift.min(255, value)))
        }
    }
    return context.makeImage()
}

func writeJPEG(_ image: CGImage, to url: URL, quality: Double) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(destination, image, [
        kCGImageDestinationLossyCompressionQuality: quality,
    ] as CFDictionary)
    return CGImageDestinationFinalize(destination)
}
