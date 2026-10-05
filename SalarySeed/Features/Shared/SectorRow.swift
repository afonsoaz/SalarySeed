import SwiftUI

/// Which sector a sector-wide screen is showing. Tapping it opens the same sheet
/// compareSeed uses, so the screens can never disagree.
///
/// It was MapView's own row while Portugal and Europe shared one screen. Those
/// two halves are about to become two screens with the same row at the top of
/// each, and a row that exists twice gets fixed in one of the copies (rule 33),
/// so it is one component before it is two call sites.
struct SectorRow: View {
    // Read for the copy, and so the accent icon redraws when the colour changes.
    @EnvironmentObject private var store: SalaryStore

    let action: () -> Void

    private var s: Strings { store.s }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "building.2")
                    .appFont(15)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.sector?.label(pt: s.pt) ?? s.mapAllSectors)
                        .appFont(15, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                    Text(store.sector == nil ? s.mapPickSector : s.mapSectorHint)
                        .appFont(10.5)
                        .foregroundStyle(store.sector == nil ? Theme.accent : Theme.textFaint)
                }
                .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .appFont(11)
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(13)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
