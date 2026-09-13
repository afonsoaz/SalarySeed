import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// v1.1: where a payslip comes from.
///
/// Both pickers run out of process, which is why this screen asks for no
/// permission and the app needs no camera or photo-library usage description.
/// `PhotosPicker` hands back only the picture the reader chose; the app never
/// sees the library. Deliberate, and the reason there is no in-app camera in
/// v1: `NSCameraUsageDescription` is shown by the system out of the bundle, and
/// this app keeps every string in `Strings` rather than in `.lproj` folders, so
/// a camera prompt could not be bilingual without breaking that.
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
                    choice(icon: "doc.text.fill", title: s.payslipPickFile, accented: true)
                }
                PhotosPicker(selection: $photo, matching: .images, photoLibrary: .shared()) {
                    choice(icon: "photo.fill", title: s.payslipPickPhoto, accented: false)
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
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    onImage(data)
                }
            }
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

    /// v1.1a: the icon's box scales with the icon.
    ///
    /// A fixed 26 point width held an 18 point symbol, and `appFont` takes that
    /// 18 to roughly three times the size at the largest settings, so the glyph
    /// was clipped by its own frame or shoved the title off the row. The two
    /// numbers describe the same thing and now move together.
    private func choice(icon: String, title: String, accented: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .appFont(18)
                .foregroundStyle(accented ? Theme.ink : Theme.accent)
                .frame(width: Theme.scaled(26, typeSize))
                .accessibilityHidden(true)
            Text(title)
                .appFont(15, weight: .semibold)
                .foregroundStyle(accented ? Theme.ink : Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accented ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.card),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(accented ? Color.clear : Theme.cardBorder, lineWidth: 1))
    }
}
