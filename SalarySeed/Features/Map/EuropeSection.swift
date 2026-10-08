import SwiftUI

/// Your sector across the EU: the sector row, then the European comparison,
/// behind the support gate in a paid build.
///
/// v0.11 built it as the second half of mapSeed, from Eurostat SES 2022. The
/// two halves shared a screen, a sector and a colour ramp, and NOTHING else:
/// separate surveys of separate populations in separate years, so no figure
/// from one is ever placed beside a figure from the other. What crosses is a
/// ratio computed inside Eurostat and applied to the user's own salary. See
/// EuroComparison. It is a view of its own because Compare in Europe
/// (`EuropeView`) is a screen of its own.
struct EuropeSection: View {
    @EnvironmentObject private var store: SalaryStore
    @EnvironmentObject private var supporter: SupporterStore

    @State private var selectedCountry: Country?
    @State private var purchasingPower = false
    @State private var showSectorSheet = false

    private var s: Strings { store.s }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // The sector row stays OUTSIDE the lock, so it is sharp and can be
            // tapped by somebody who has not paid.
            SectorRow { showSectorSheet = true }
            gated
        }
        .sheet(isPresented: $showSectorSheet) { SectorTenureSheet() }
    }

    // v1.0.1: the European half is behind the support payment; Portugal is not,
    // and that split is the whole point. The app's own country stays free
    // because that is what it is for, and the comparison against 26 others is
    // the extra. In the free build `isSupporter` is forced true and the lock
    // never draws.
    @ViewBuilder
    private var gated: some View {
        if supporter.isSupporter {
            content
        } else {
            // v1.0.1a: the grid itself, blurred, rather than a page about it.
            // Twenty-seven tiles are recognisable out of focus, which says more
            // about what is behind the payment than a bullet list did.
            //
            // A minimum height, because the lock sits inside a ScrollView rather
            // than filling a screen: without it the lock would be as tall as the
            // grid happens to be, and the card would sit wherever that left it.
            // The offset is a crop onto the tiles; see `SupportLock`.
            SupportLock(title: s.lockEuroTitle, blurb: s.lockEuroBlurb,
                        contentHeight: 540, contentOffsetY: -170) {
                content
            }
        }
    }

    /// Drawn identically whether or not it is behind the lock, so the blur can
    /// never drift from what is actually being sold.
    private var content: some View {
        EuropeScopeView(sector: store.sector,
                        yourGross: store.breakdown.grossMonthly,
                        purchasingPower: $purchasingPower,
                        selected: $selectedCountry,
                        onPickSector: { showSectorSheet = true })
    }
}
