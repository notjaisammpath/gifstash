import Foundation

/// Giphy API v1. https://developers.giphy.com/docs/api/endpoint
public struct GiphyProvider: GifProvider {
    public let id = "giphy"
    public let displayName = "GIPHY"
    public let attribution = "Powered by GIPHY"

    private let apiKey: String?

    public init(apiKey: String?) {
        let trimmed = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    public var isConfigured: Bool { apiKey != nil }

    /// GIPHY rejects an offset past these, so paging has to stop there even
    /// when total_count claims there is more.
    private static let searchMaxOffset = 4999
    private static let trendingMaxOffset = 499
    /// q is capped at 50 characters.
    private static let maxQueryLength = 50

    public func search(query: String, rating: GifRating, page: GifPage) async throws -> GifResults {
        let trimmed = String(query.prefix(Self.maxQueryLength))
        return try await fetch(
            path: "search",
            maxOffset: Self.searchMaxOffset,
            rating: rating,
            page: page,
            extra: [URLQueryItem(name: "q", value: trimmed)]
        )
    }

    public func trending(rating: GifRating, page: GifPage) async throws -> GifResults {
        try await fetch(
            path: "trending",
            maxOffset: Self.trendingMaxOffset,
            rating: rating,
            page: page,
            extra: []
        )
    }

    private func fetch(
        path: String,
        maxOffset: Int,
        rating: GifRating,
        page: GifPage,
        extra: [URLQueryItem]
    ) async throws -> GifResults {
        guard let apiKey else { throw GifProviderError.missingAPIKey(provider: displayName) }

        var components = URLComponents(string: "https://api.giphy.com/v1/gifs/" + path)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "limit", value: String(page.limit)),
            URLQueryItem(name: "offset", value: page.cursor ?? "0"),
            URLQueryItem(name: "rating", value: rating.giphyValue),
            // Giphy bundle tuned for messaging: drops video clips, trims renditions.
            URLQueryItem(name: "bundle", value: "messaging_non_clips"),
        ] + extra

        let payload = try await GifHTTP.get(Response.self, url: components.url!)
        let items = payload.data.compactMap(Self.item(from:))

        let offset = Int(page.cursor ?? "0") ?? 0
        let returned = payload.data.count
        let next = offset + returned
        let reachedTotal = payload.pagination?.totalCount.map { next >= $0 } ?? false
        let exhausted = returned == 0 || reachedTotal || next > maxOffset

        return GifResults(items: items, nextCursor: exhausted ? nil : String(next))
    }

    // Preview and send renditions, best first. Which keys exist depends on the
    // bundle, so each is a fallback chain rather than a single lookup.
    private static let previewOrder = [
        "fixed_width_small",
        "fixed_width_downsampled",
        "fixed_height_downsampled",
        "fixed_width",
        "downsized",
        "original",
    ]

    private static let sendOrder = [
        "downsized_medium",
        "downsized",
        "original",
        "fixed_width",
        "fixed_height",
    ]

    private static func item(from gif: GIF) -> GifItem? {
        guard let preview = pick(from: gif.images, order: previewOrder),
              let send = pick(from: gif.images, order: sendOrder)
        else { return nil }

        return GifItem(
            id: gif.id,
            providerID: "giphy",
            title: gif.title?.trimmingCharacters(in: .whitespaces) ?? "",
            previewURL: preview.url,
            fullURL: send.url,
            width: send.width,
            height: send.height,
            sourceURL: gif.url.flatMap(URL.init(string:))
        )
    }

    private static func pick(
        from images: [String: Rendition],
        order: [String]
    ) -> (url: URL, width: Int, height: Int)? {
        for key in order {
            guard let rendition = images[key],
                  let raw = rendition.url,
                  let url = URL(string: raw)
            else { continue }
            let width = Int(rendition.width ?? "") ?? 0
            let height = Int(rendition.height ?? "") ?? 0
            return (url, width, height)
        }
        return nil
    }

    // MARK: - Wire format

    private struct Response: Decodable {
        let data: [GIF]
        let pagination: Pagination?
    }

    private struct Pagination: Decodable {
        let totalCount: Int?

        enum CodingKeys: String, CodingKey {
            case totalCount = "total_count"
        }
    }

    private struct GIF: Decodable {
        let id: String
        let title: String?
        let url: String?
        let images: [String: Rendition]
    }

    /// Giphy returns every numeric field as a string.
    private struct Rendition: Decodable {
        let url: String?
        let width: String?
        let height: String?
    }
}
