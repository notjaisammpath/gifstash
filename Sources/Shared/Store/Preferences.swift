import Foundation

/// Small settings that both targets share through the App Group.
@MainActor
public final class Preferences {
    public static let shared = Preferences()

    private let defaults: UserDefaults

    private enum Key {
        static let provider = "selectedProviderID"
        static let rating = "contentRating"
    }

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: AppConfig.appGroupID)
            ?? .standard
    }

    public var selectedProviderID: String {
        get { defaults.string(forKey: Key.provider) ?? "giphy" }
        set { defaults.set(newValue, forKey: Key.provider) }
    }

    public var rating: GifRating {
        get {
            defaults.string(forKey: Key.rating).flatMap(GifRating.init(rawValue:)) ?? .pg13
        }
        set { defaults.set(newValue.rawValue, forKey: Key.rating) }
    }
}
