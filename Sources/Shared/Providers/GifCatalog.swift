import Foundation
import Observation

/// Every provider the build knows about, plus which one is active.
@MainActor
@Observable
public final class GifCatalog {
    public static let shared = GifCatalog()

    public let providers: [any GifProvider]
    public private(set) var selectedID: String
    public private(set) var rating: GifRating

    private let preferences: Preferences

    init(preferences: Preferences = .shared) {
        self.preferences = preferences
        self.providers = [
            GiphyProvider(apiKey: AppConfig.giphyAPIKey),
            TenorProvider(apiKey: AppConfig.tenorAPIKey),
        ]
        self.rating = preferences.rating

        let saved = preferences.selectedProviderID
        // Fall back to any provider that actually has a key before giving up.
        if let match = providers.first(where: { $0.id == saved }), match.isConfigured {
            self.selectedID = saved
        } else if let configured = providers.first(where: { $0.isConfigured }) {
            self.selectedID = configured.id
        } else {
            self.selectedID = saved
        }
    }

    public var selected: any GifProvider {
        providers.first { $0.id == selectedID } ?? providers[0]
    }

    public var hasAnyKey: Bool {
        providers.contains { $0.isConfigured }
    }

    public func select(_ id: String) {
        guard providers.contains(where: { $0.id == id }) else { return }
        selectedID = id
        preferences.selectedProviderID = id
    }

    public func setRating(_ value: GifRating) {
        rating = value
        preferences.rating = value
    }
}
