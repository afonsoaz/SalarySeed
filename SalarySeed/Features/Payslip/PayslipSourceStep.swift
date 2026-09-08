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
    let onFile: (URL) -> Void
    let onImage: (Data) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var importing = false
    @State private var photo: PhotosPickerItem?

    private var s: Strings { store.s }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
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
