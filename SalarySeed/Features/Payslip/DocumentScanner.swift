import SwiftUI
import VisionKit
import AVFoundation
import UIKit

/// What the reader handed over, on its way to `PayslipCheckModel`.
///
/// `Identifiable` so `fullScreenCover(item:)` can present the check the moment
/// there is something to check, which is what keeps a picker and the cover from
/// being two presentations racing each other.
struct PayslipInput: Identifiable {
    enum Kind {
        case file(URL)
        case image(Data)
    }
    let id = UUID()
    let kind: Kind
}

/// Camera access, as the three states it actually has.
///
/// Rule 21: "we could not use the camera" is not one boolean. Never asked,
/// asked and refused, and no camera on this device are three different things,
/// and the screen has to be able to say which.
///
/// Pre-flighted rather than left to VisionKit, because a refusal discovered
/// INSIDE the scanner is a black screen with a Cancel button and no reason on
/// it. Asked here, the reader has already read a sentence in the app's own
/// language saying what the camera is for.
enum CameraAccess {
    case ready
    case needsAsking
    case refused
    /// No usable camera, which includes every simulator.
    case unavailable

    static var current: CameraAccess {
        guard VNDocumentCameraViewController.isSupported else { return .unavailable }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .ready
        case .notDetermined: return .needsAsking
        case .denied, .restricted: return .refused
        @unknown default: return .refused
        }
    }
}

/// v1.4: Apple's document scanner, wrapped. The first
/// `UIViewControllerRepresentable` in this app.
///
/// WHY THE SCANNER AND NOT A PLAIN CAMERA. It finds the page edges, corrects the
/// perspective and raises the contrast before it hands anything back, and every
/// one of those is something the reader downstream would otherwise have to
/// survive: `PayslipOCR.deskewed` gives up past fifteen degrees, and column
/// detection in `PayslipLayout` assumes the page is a rectangle. A hand-held
/// snapshot of a payslip is the input this feature reads worst.
///
/// iOS 13, so no availability guard, and the app's record of having none
/// survives. `VNDocumentCameraViewController.isSupported` is what decides
/// whether the row is drawn at all; see `CameraAccess`.
///
/// NONE of the three delegate methods dismisses anything. VisionKit leaves the
/// controller on screen and expects its presenter to take it down, so every
/// closure here has to clear the state that presented it.
struct DocumentScanner: UIViewControllerRepresentable {
    /// Page one, JPEG encoded, ready for `PayslipCheckModel.load(imageData:)`.
    let onScan: (Data) -> Void
    let onCancel: () -> Void
    /// The scanner itself failed. Distinct from a cancel, because "you closed
    /// it" and "it broke" are two reasons and rule 21 says they get two states.
    let onFailure: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    /// Nothing to update: the controller owns its own capture session and this
    /// view passes it no state.
    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            // JPEG, and at 0.95, for two reasons that both matter.
            //
            // `PayslipOCR.image(from:)` is `CGImageSourceCreateWithData`, so it
            // needs an encoded container rather than raw pixels. And it passes
            // `kCGImageSourceCreateThumbnailWithTransform`, which applies the
            // EXIF orientation: `UIImage.jpegData` writes that orientation into
            // the file, so the page arrives upright through code that is already
            // tested. Hand a bare CGImage down a new path instead and the
            // orientation is dropped, and a sideways scan reads as zero
            // fragments with no error anywhere.
            //
            // Everything is capped at `PayslipOCR.recognitionLongEdge` on the
            // way in, so 0.95 keeps the compression artefacts below the
            // resample rather than compounding with it.
            //
            // A nil here is a FAILURE and not a cancellation: the reader did
            // take a picture. Rule 21.
            guard scan.pageCount > 0,
                  let data = scan.imageOfPage(at: 0).jpegData(compressionQuality: 0.95)
            else { parent.onFailure(); return }
            parent.onScan(data)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            // The error is not shown. VisionKit's errors are about its own
            // capture session, and none of them says anything a reader holding
            // a payslip can act on. The screen offers the two routes that work.
            parent.onFailure()
        }
    }
}
