import SwiftUI

/// Compare in Europe: your sector across the EU, on a screen of its own.
///
/// It was the second half of the Map tab. It became its own screen when the
/// map split, because it is a separate survey from the Portuguese half and the
/// two never shared a figure, and because it is the half that sits behind the
/// support gate in a paid build while Portugal never does.
struct EuropeView: View {
    @EnvironmentObject private var store: SalaryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                EuropeSection()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("mapSeed")
                .appFont(12)
                .foregroundStyle(Theme.accent)
            Text(store.s.euroTitle)
                .appFont(22, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }
}
