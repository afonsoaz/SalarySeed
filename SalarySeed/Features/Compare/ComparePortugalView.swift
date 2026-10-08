import SwiftUI

/// Compare in Portugal: where your pay sits in this country, as one story.
///
/// Phase two (agreed with Afonso) made it read top to bottom, in the order the
/// questions come: against everybody (the headline, with the country's pay
/// drawn under it), against people like you (one line per group), and what
/// your sector pays across the districts (the map). It was two views behind a
/// People / Districts switch, which gave the screen two titles, hid half of
/// it, and was louder than anything it switched between.
///
/// The European half of the old map is a screen of its own, because it is a
/// different survey of a different population in a different year, and the
/// two never shared a figure.
///
/// Every source is named once, at the foot. Each card used to carry its own
/// source line, the same one four times.
struct ComparePortugalView: View {
    @EnvironmentObject private var store: SalaryStore

    private var s: Strings { store.s }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                NationalStanding()
                    .padding(.top, 28)
                PeopleLikeYou()
                    .padding(.top, 36)
                DistrictMapView()
                    .padding(.top, 36)
                sources
                    .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("compareSeed")
                .appFont(12)
                .foregroundStyle(Theme.accent)
            Text(s.compareTitle)
                .appFont(22, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(s.compareSourceNote)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.districtSourceLine)
                .appFont(9.5)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.mapGeoCredit)
                .appFont(9.5)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
