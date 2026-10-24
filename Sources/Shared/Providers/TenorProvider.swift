import Foundation

/// Tenor API v2. https://developers.google.com/tenor/guides/endpoints
public struct TenorProvider: GifProvider {
    public let id = "tenor"
    public let displayName = "Tenor"
    public let attribution = "Powered by Tenor"

    private let apiKey: String?
    private let clientKey = "gifstash"

    public init(apiKey: String?) {
        let trimmed = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    public var isConfigured: Bool { apiKey != nil }

    public func search(query: String, rating: GifRating, page: GifPage) async throws -> GifResults {
        try await fetch(path: "search", rating: rating, page: page, extra: [
            URLQueryItem(name: "q", value: query)
        ])
    }

    public func trending(rating: GifRating, page: GifPage) async throws -> GifResults {
        try await fetch(path: "featured", rating: rating, page: page, extra: [])
    }

    private func fetch(
        path: String,
        rating: GifRating,
        page: GifPage,
        extra: [URLQueryItem]
    ) async throws -> GifResults {
        guard let apiKey else { throw GifProviderError.missingAPIKey(provider: displayName) }

        var components = URLComponents(string: "https://tenor.googleapis.com/v2/" + path)!
        var query = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "client_key", value: clientKey),
            URLQueryItem(name: "limit", value: String(page.limit)),
            URLQueryItem(name: "media_filter", value: "gif,tinygif"),
            URLQueryItem(name: "contentfilter", value: rating.tenorValue),
        ] + extra
        if let cursor = page.cursor, !cursor.isEmpty {
            query.append(URLQueryItem(name: "pos", value: cursor))
        }
        components.queryItems = query

        let payload = try await GifHTTP.get(Response.self, url: components.url!)
        let items = payload.results.compactMap(Self.item(from:))

        let next = payload.next
        let exhausted = payload.results.isEmpty || (next?.isEmpty ?? true)

        return GifResults(items: items, nextCursor: exhausted ? nil : next)
    }

    private static func item(from result: SearchResult) -> GifItem? {
        let formats = result.mediaFormats
        guard let send = formats["gif"] ?? formats["mediumgif"],
              let sendURL = send.url.flatMap(URL.init(string:))
        else { return nil }

        let preview = formats["tinygif"] ?? send
        guard let previewURL = preview.url.flatMap(URL.init(string:)) else { return nil }

        return GifItem(
            id: result.id,
            providerID: "tenor",
            title: result.contentDescription ?? "",
            previewURL: previewURL,
            fullURL: sendURL,
            width: send.dims?.first ?? 0,
            height: send.dims?.last ?? 0,
            sourceURL: result.itemurl.flatMap(URL.init(string:))
        )
    }

    // MARK: - Wire format

    private struct Response: Decodable {
        let results: [SearchResult]
        let next: String?
    }

    private struct SearchResult: Decodable {
        let id: String
        let contentDescription: String?
        let itemurl: String?
        let mediaFormats: [String: Format]

        enum CodingKeys: String, CodingKey {
            case id
            case contentDescription = "content_description"
            case itemurl
            case mediaFormats = "media_formats"
        }
    }

    private struct Format: Decodable {
        let url: String?
        /// Width then height.
        let dims: [Int]?
    }
}
