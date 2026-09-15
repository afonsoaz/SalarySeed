import Foundation

/// v1.0: what build this is, read from the bundle rather than typed anywhere.
///
/// A version number written into a string literal is a version number that
/// disagrees with itself. The profile footer said "SalarySeed v0.9.4" through six
/// releases, including the one that added a Version row four lines above it
/// saying something else, and nothing could have caught that except somebody
/// reading the screen. Both now read this.
enum AppConfig {

    /// `1.0.0`.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    /// `1.0.0 (1)`. What the profile shows and what someone reporting a problem
    /// can read out.
    static var versionLine: String { "\(version) (\(build))" }

    // MARK: Monetisation (v1.3)

    enum Monetisation {
        /// Everything in the app is free. StoreKit is never called.
        case free
        /// The €4.99 supporter unlock is on, and Grow, the European map and
        /// the accents sit behind it.
        case supporter
    }

    /// V1.3 SHIPS FREE, AND THE PAYMENT IS SWITCHED OFF RATHER THAN DELETED.
    ///
    /// Changing this one word to `.supporter` brings the whole thing back: the
    /// sell card at the top of Profile, the two `SupportLock` gates over Grow and
    /// the European grid, the padlock on the accent swatches, and the purchase,
    /// the restore and the refund listener in `SupporterStore`. Nothing else has
    /// to change, because all five gates read one boolean and that boolean reads
    /// this.
    ///
    /// WHY A CONSTANT AND NOT A BRANCH. This repo already ran that experiment.
    /// `pool-backend` was parked at v1.0 and is now two releases and about two
    /// hundred files behind master, because nothing compiles a branch nobody
    /// checks out. Both halves of this go through the compiler on every build, so
    /// the paid version cannot quietly stop building while it waits.
    ///
    /// The paid path is otherwise untouched, including the product id, which must
    /// never change: everyone who paid €2.99 or €4.99 is entitled through it.
    static let monetisation: Monetisation = .free
}
