import SwiftUI

/// v1.5: offerSeed, pushed onto Home's navigation stack from "What if…". Since
/// the hub it is Home's "Check job offer" row (`HubRoute.offer`).
///
/// One screen in two states: the form, when there is no offer yet or the
/// reader is changing it, and the comparison otherwise. A push and not a sheet,
/// for the reason Profile is one: the form opens a picker of its own, and a
/// sheet on a sheet is a stack of cards.
///
/// THIS IS THE ONLY PLACE IN `Features/Offer/` THAT WRITES TO THE STORE, and the
/// only thing it writes is `store.offer`. The form hands back a value and the
/// comparison hands back a request to remove it; neither touches the store, so
/// nothing about an offer can reach the reader's own salary, sector or place.
struct OfferView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var editing = false

    var body: some View {
        Group {
            if let terms = store.offer, !editing {
                OfferResultView(
                    terms: terms,
                    onEdit: { editing = true },
                    onRemove: { store.offer = nil }
                )
            } else {
                OfferFormView(
                    starting: store.offer,
                    onCompare: { terms in
                        store.offer = terms
                        editing = false
                    },
                    // Only an offer that already exists has somewhere to go back
                    // to. A new one leaves by the back chevron, like Profile.
                    onCancel: store.offer == nil ? nil : { editing = false }
                )
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}
