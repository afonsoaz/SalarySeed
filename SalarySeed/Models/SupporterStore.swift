import Foundation
import StoreKit

/// v0.16: the one purchase in the app.
///
/// v1.3 SWITCHED IT OFF. `AppConfig.monetisation` is `.free`, so everything below
/// this line is code that compiles, is still correct, and never runs. Nothing
/// here was deleted or weakened for the free build: the entitlement is forced
/// true in `init`, `start` returns before touching StoreKit, and the rest waits.
/// Read the rest of this comment as a description of the paid build.
///
/// A €4.99 NON-CONSUMABLE (€2.99 until v1.0.1). Not a donation, and the
/// distinction is not pedantry:
/// Apple does not allow a pure "support the developer" payment through IAP, so
/// the purchase has to unlock something. The accent colours are what make this a
/// legitimate unlock rather than a tip.
///
/// STOREKIT IS THE SOURCE OF TRUTH, NOT `UserDefaults`. There is a cached mirror
/// below, and it exists only so the first frame after launch does not flicker
/// from "not a supporter" to "supporter" while the entitlement check runs. The
/// cache is never trusted for longer than that: `refresh()` overwrites it from
/// `Transaction.currentEntitlements` on every launch, and `listenForUpdates()`
/// overwrites it again the moment Apple says anything. A cached paid flag that
/// outlives the payment is the kind of bug that gets an app pulled.
///
/// THREE THINGS THAT ARE NOT OPTIONAL and are easy to leave out:
/// 1. **Restore.** App Review rejects a non-consumable with no restore path.
///    `AppStore.sync()` plus a re-read of the entitlements.
/// 2. **The updates listener.** A refund or a family-sharing revocation arrives
///    asynchronously, long after any screen asked. Without it the colours stay
///    unlocked forever after a chargeback.
/// 3. **`finish()`.** An unfinished transaction is redelivered on every launch.
///
/// TESTING WITHOUT AN APPLE DEVELOPER ACCOUNT: the `SalarySeed.storekit`
/// configuration file in the repo root drives the whole flow in the simulator,
/// including cancellation and refunds, with no App Store Connect and no
/// enrolment. Shipping still needs the paid programme; building does not.
@MainActor
final class SupporterStore: ObservableObject {

    /// Must match the product identifier in `SalarySeed.storekit` and, later, in
    /// App Store Connect. Changing it strands everyone who already paid.
    static let productID = "com.afonsoazevedo.salaryseed.supporter"

    private static let cacheKey = "supporter.entitled"

    /// True when the user owns the unlock. Starts from the cache, then gets
    /// corrected by StoreKit within a moment of launch.
    @Published private(set) var isSupporter: Bool
    /// nil until the App Store answers. The price is read from here rather than
    /// hardcoded, so a currency or a price change never leaves stale copy on a
    /// button.
    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    /// Set when a purchase fails for a reason worth showing. Cancellation is not
    /// one: someone who backs out has not hit an error and should not be told so.
    @Published var lastError: String?

    /// What the button should say. Falls back to nothing rather than to a
    /// hardcoded "€2.99", because a wrong price is worse than a spinner.
    var displayPrice: String? { product?.displayPrice }

    private var updatesTask: Task<Void, Never>?

    init() {
        // A free build is entitled to everything from the first frame, and the
        // cache is deliberately NOT consulted and NOT written. See `start`.
        isSupporter = AppConfig.monetisation == .free
            ? true
            : UserDefaults.standard.bool(forKey: Self.cacheKey)
    }

    deinit { updatesTask?.cancel() }

    // MARK: Lifecycle

    /// Called once from the app entry point.
    ///
    /// v1.3: IN A FREE BUILD THIS MAKES NO STOREKIT CALL AT ALL. Not a call that
    /// fails, not a product that comes back nil: none. The app then has no code
    /// path that reaches the network, which is a stronger sentence than the one
    /// v1.0 could write and is what `PRIVACY.md` now says.
    ///
    /// THE CACHE IS NOT WRITTEN HERE, and reaching for `apply(true, to:)` is the
    /// obvious shortcut that gets this wrong. It would leave `true` sitting in
    /// `UserDefaults`, and the day `AppConfig.monetisation` goes back to
    /// `.supporter` that stale flag would show a non-payer the paid screens for a
    /// frame and then take them away. A v1.2 payer's own cached `true` is left
    /// alone for the same reason, in the other direction: it is still theirs.
    func start(applyingTo store: SalaryStore) {
        guard AppConfig.monetisation == .supporter else {
            // The one thing `apply` did that still has to happen: the home-screen
            // icon follows the stored accent on every launch.
            AppIcon.apply(store.accent)
            return
        }
        listenForUpdates(applyingTo: store)
        Task { await loadProduct() }
        Task { await refresh(applyingTo: store) }
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            // Not surfaced. A missing product means the sheet shows no price and
            // no buy button, which is the honest state, and an error banner on a
            // screen nobody asked for is noise.
            product = nil
        }
    }

    /// Read the entitlements and make the rest of the app agree with them.
    func refresh(applyingTo store: SalaryStore) async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                entitled = true
            }
        }
        apply(entitled, to: store)
    }

    /// A refund can land at any time, so this runs for the life of the process.
    private func listenForUpdates(applyingTo store: SalaryStore) {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self.refresh(applyingTo: store)
            }
        }
    }

    // MARK: Buying

    func purchase(applyingTo store: SalaryStore) async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    // Unverified means the signature did not check out. Treat it
                    // as no purchase rather than as a purchase, always.
                    lastError = "verification"
                    return
                }
                await transaction.finish()
                await refresh(applyingTo: store)
            case .userCancelled:
                // Deliberately silent. Backing out is not an error.
                break
            case .pending:
                // Ask to Buy and similar. It may be approved later, and the
                // updates listener is what will notice.
                lastError = "pending"
            @unknown default:
                break
            }
        } catch {
            lastError = "failed"
        }
    }

    /// Restore. `AppStore.sync()` prompts for the Apple ID password, so it must
    /// only ever run from an explicit tap, never on launch.
    func restore(applyingTo store: SalaryStore) async {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refresh(applyingTo: store)
            if !isSupporter { lastError = "nothingToRestore" }
        } catch {
            lastError = "failed"
        }
    }

    // MARK: Applying

    private func apply(_ entitled: Bool, to store: SalaryStore) {
        isSupporter = entitled
        UserDefaults.standard.set(entitled, forKey: Self.cacheKey)
        // The colour goes back with the entitlement. See the note on
        // `SalaryStore.enforceAccentEntitlement`.
        store.enforceAccentEntitlement(isSupporter: entitled)
        // And the home-screen icon follows the colour, in both directions: it
        // turns the moment a purchase lands, and it goes back to green when a
        // refund takes the entitlement away. `AppIcon.apply` no-ops when the
        // icon is already right, so this running on every launch is free and
        // shows no alert.
        AppIcon.apply(store.accent)
    }
}
