import Foundation

/// Build-time configuration. Values arrive from Config/Secrets.xcconfig via
/// the Info.plist of whichever target is running, so the app and the extension
/// both read the same keys without hardcoding anything into source.
public enum AppConfig {
    public static var giphyAPIKey: String? { string("GiphyAPIKey") }
    public static var tenorAPIKey: String? { string("TenorAPIKey") }

    /// Shared container for bookmarks. Must match both .entitlements files.
    public static var appGroupID: String {
        string("AppGroupID") ?? "group.com.gifstash.shared"
    }

    private static func string(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unset xcconfig variable expands to an empty string, not a missing key.
        return trimmed.isEmpty ? nil : trimmed
    }
}
