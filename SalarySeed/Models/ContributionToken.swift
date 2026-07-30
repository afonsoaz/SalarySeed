import Foundation
import Security

/// v0.13: the pseudonymous token, and the only durable consequence of saying yes.
///
/// A random UUID, generated the first time consent is given, derived from nothing
/// about the person or the device. Reasoning in `app-concept.md` §14.3.
///
/// IT EXISTS FOR ERASURE FIRST. Without it, "podes apagar tudo o que enviaste"
/// could only ever mean "stop sending new ones", and the consent screen would be
/// promising something the app cannot do. Its second use, letting a later
/// contribution be recognised as the same person's, costs nothing to preserve and
/// is the only thing that would turn a future second reading into a time series
/// rather than two unrelated snapshots. Nothing in this app will ever produce one:
/// there is no timer, no scheduled question and no promise about the future.
///
/// WHY THE KEYCHAIN AND NOT `UserDefaults`. Keychain items survive the app being
/// deleted, and here that is the point rather than a quirk to work around. If the
/// token vanished with the app, so would the ability to exercise erasure, and a
/// deletion right that a user can destroy by accident is not much of a right. The
/// remaining gap is a wiped or replaced phone, which is why the profile shows the
/// token as a copyable code: someone with no device left can still ask.
///
/// `ThisDeviceOnly` and never synced. An iCloud-synced token would follow the
/// person across their devices, which would dedupe better, but it would also put
/// the identifier into iCloud backups, and this is the one value in the app whose
/// whole job is to be nowhere else.
enum ContributionToken {

    private static let service = "com.afonsoazevedo.salaryseed.contribution"
    private static let account = "token"

    /// The stored token, or nil when consent has never been given.
    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8),
              !text.isEmpty else { return nil }
        return text
    }

    /// The token, creating one if there is not one already. Idempotent, so
    /// granting consent twice cannot orphan a first set of contributions behind
    /// a token nobody holds any more.
    @discardableResult
    static func ensure() -> String? {
        if let existing = load() { return existing }
        let token = UUID().uuidString
        guard let data = token.data(using: .utf8) else { return nil }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        // A duplicate means another path created it between `load` and here.
        // Read it back rather than overwriting, which would strand rows.
        if status == errSecDuplicateItem { return load() }
        return status == errSecSuccess ? token : nil
    }

    /// Only ever called after contributions have actually been deleted. Clearing
    /// this first would leave rows on a server with nothing left that can name
    /// them, which is the exact situation the token exists to prevent.
    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        _ = SecItemDelete(query as CFDictionary)
    }

    /// Short form for the profile, so the row does not show a 36-character UUID
    /// while still showing enough to tell two codes apart. The full value is what
    /// gets copied.
    static func short(_ token: String) -> String {
        String(token.prefix(8)).uppercased()
    }
}
