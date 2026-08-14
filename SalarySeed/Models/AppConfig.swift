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
}
