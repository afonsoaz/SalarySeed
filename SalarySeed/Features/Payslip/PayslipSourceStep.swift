import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import UIKit

/// v1.1: where a payslip comes from. v1.4: three places, not two.
///
/// The file and photo pickers run out of process, which is why neither needs a
/// usage description: `PhotosPicker` hands back only the picture the reader
/// chose and the app never sees the library.
///
/// THE CAMERA IS THE ONE PERMISSION THIS APP ASKS FOR, and until v1.4 the
/// comment here explained why it did not exist: `NSCameraUsageDescription` is
/// drawn by the system out of the bundle, and this app keeps every string in
/// `Strings` rather than in `.lproj` folders, so the prompt could not be
/// bilingual without breaking that.
///
/// The premise was right and the conclusion is now overruled. The prompt is
/// English only, deliberately, and the explanation was moved to where it can be
/// bilingual: `payslipPickCameraSub` is on screen, in the reader's language,
/// before the button is tapped, so the system alert confirms rather than
/// explains. Two `.lproj` files were the alternative and were rejected for
/// making the bundle genuinely localized for the first time, which would put
/// the app's whole PT/EN auto-detection at risk for the sake of one dialog.
struct PayslipSourceStep: View {
    // Held because this view draws with Theme.accent, which is a computed
    // static SwiftUI cannot observe. See SalarySeedApp.
    @EnvironmentObject private var store: SalaryStore
    /// v1.2: the tab's landing screen explains the checks before asking for a
    /// file; the onboarding cover does not. Onboarding is already nine steps
    /// long, and on that route the reader has no profile yet, so half the
    /// checks listed would not run on what they are about to hand over.
    var showsWhatWeCheck: Bool = false
    let onFile: (URL) -> Void
    let onImage: (Data) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var importing = false
    @State private var photo: PhotosPickerItem?
    @State private var scanning = false
    @State private var cameraRefused = false
    @State private var cameraFailed = false
    /// The scan, held for the length of one dismissal. See the cover below.
    @State private var scannedPage: Data?
    /// Read once, on appear, rather than on every redraw: it can only change
    /// while the app is in Settings, and coming back re-appears this view.
    @State private var camera: CameraAccess = .unavailable

    private var s: Strings { store.s }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if showsWhatWeCheck { hero }

                Text(s.payslipSourceIntro)
                    .appFont(14)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                Button { importing = true } label: {
                    PayslipSourceRow(icon: "doc.text.fill", title: s.payslipPickFile,
                                     subtitle: nil, accented: true)
                }
                // Not drawn at all where there is no usable camera, which
                // includes every simulator. A row that opens a black screen is
                // worse than a row that is not there.
                if camera != .unavailable {
                    Button(action: startScan) {
                        PayslipSourceRow(icon: "camera.fill", title: s.payslipPickCamera,
                                         subtitle: s.payslipPickCameraSub)
                    }
                }
                PhotosPicker(selection: $photo, matching: .images, photoLibrary: .shared()) {
                    PayslipSourceRow(icon: "photo.fill", title: s.payslipPickPhoto,
                                     subtitle: nil)
                }

                // Inline, never an alert. `PayslipUnreadableView` makes the same
                // call for the same reason: an alert that says "could not do it"
                // with an OK button is a dead end, and the two routes that do
                // work are on the screen behind it.
                if cameraRefused {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.payslipCameraRefused)
                            .appFont(11.5)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text(s.payslipCameraOpenSettings)
                                .appFont(11.5, weight: .semibold)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                } else if cameraFailed {
                    Text(s.payslipCameraFailed)
                        .appFont(11.5)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(s.payslipSourceHint)
                    .appFont(11)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                if showsWhatWeCheck { whatWeCheck.padding(.top, 10) }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.pdf, .image],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { onFile(url) }
        }
        .onAppear { camera = CameraAccess.current }
        // `fullScreenCover` and not a sheet: the scanner is a full-screen UIKit
        // controller with its own shutter, Retake, Keep Scan and Cancel, and a
        // sheet gives all of that a card, a grabber and a drag-to-dismiss that
        // fights it. It also sidesteps rule 26 entirely, since there are no
        // detents to declare.
        //
        // THE HANDOVER GOES THROUGH `onDismiss`, and that is not a stylistic
        // choice. `onImage` moves the flow to `.reading`, which replaces THIS
        // view, the one presenting the cover, so calling it from the delegate
        // callback tears down the presenter while its presentation is still
        // going down. Holding the JPEG for the length of the dismissal and
        // handing it over afterwards means nothing is mid-transition.
        .fullScreenCover(isPresented: $scanning, onDismiss: {
            if let page = scannedPage {
                scannedPage = nil
                onImage(page)
            }
        }) {
            DocumentScanner(
                onScan: { scannedPage = $0; scanning = false },
                onCancel: { scanning = false },
                onFailure: { scanning = false; cameraFailed = true })
                .ignoresSafeArea()
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    onImage(data)
                }
            }
        }
    }

    /// Ask, or say why we cannot. Three states, three outcomes. Rule 21.
    private func startScan() {
        cameraFailed = false
        switch CameraAccess.current {
        case .ready:
            cameraRefused = false
            scanning = true
        case .needsAsking:
            // The completion arrives on an arbitrary queue.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { cameraRefused = false; scanning = true }
                    else { cameraRefused = true }
                }
            }
        case .refused:
            cameraRefused = true
        case .unavailable:
            // The row is not drawn in this case, so this is unreachable. Here
            // so the switch cannot go stale if that ever changes.
            camera = .unavailable
        }
    }

    /// The same sprout the rest of the app uses to mean "this is SalarySeed
    /// doing something". A tab that opens on two buttons and a paragraph reads
    /// as a dialog somebody left open; this is what makes it a place.
    private var hero: some View {
        HStack {
            Spacer()
            SproutView(stage: 4, size: 62, animatesIn: true, sways: true)
                .accessibilityHidden(true)
            Spacer()
        }
        .padding(.bottom, 2)
    }

    /// What the checker actually does, said before it asks for a file.
    ///
    /// The last line is the third of the honesty rules and it is not a
    /// disclaimer: a reader who hands over a payslip and gets four checks back
    /// out of ten needs to have been told that can happen BEFORE they wonder
    /// whether the app just missed something.
    private var whatWeCheck: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(s.payslipWhatTitle)
                .appFont(11, weight: .medium)
                .foregroundStyle(Theme.textSecondary)
            ForEach(s.payslipWhatItems, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: "checkmark")
                        .appFont(10, weight: .bold)
                        .foregroundStyle(Theme.accent)
                        .frame(width: Theme.scaled(13, typeSize))
                        .accessibilityHidden(true)
                    Text(item)
                        .appFont(12.5)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            Text(s.payslipWhatHonesty)
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1))
    }

    // v1.4: `choice` moved to `Features/Shared/PayslipSourceRow.swift`, because
    // onboarding's first step now draws the same rows. See the note there for
    // why the ROW is shared and the screen is not.
}
