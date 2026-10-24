import Foundation

/// One page of results. Cursors are provider-defined opaque strings
/// (Giphy uses a numeric offset, Tenor a `pos` token).
public struct GifPage: Sendable {
    public let cursor: String?
    public let limit: Int

    public init(cursor: String? = nil, limit: Int = 30) {
        self.cursor = cursor
        self.limit = limit
    }

    public static let first = GifPage()
}

public struct GifResults: Sendable {
    public let items: [GifItem]
    /// `nil` means there is nothing more to fetch.
    public let nextCursor: String?

    public init(items: [GifItem], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }

    public static let empty = GifResults(items: [], nextCursor: nil)
}

public enum GifRating: String, CaseIterable, Sendable {
    case g, pg, pg13, r

    /// Giphy spells this one with a dash.
    var giphyValue: String { self == .pg13 ? "pg-13" : rawValue }
    /// Tenor's content filter has four coarse levels.
    var tenorValue: String {
        switch self {
        case .g: return "high"
        case .pg: return "medium"
        case .pg13: return "low"
        case .r: return "off"
        }
    }

    public var label: String {
        switch self {
        case .g: return "G"
        case .pg: return "PG"
        case .pg13: return "PG-13"
        case .r: return "R"
        }
    }
}

public protocol GifProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    /// Shown in the UI — both providers require visible attribution.
    var attribution: String { get }
    /// False when the API key is missing, so the UI can say so instead of failing silently.
    var isConfigured: Bool { get }

    func search(query: String, rating: GifRating, page: GifPage) async throws -> GifResults
    func trending(rating: GifRating, page: GifPage) async throws -> GifResults
}

public enum GifProviderError: LocalizedError, Equatable {
    case missingAPIKey(provider: String)
    case rateLimited
    case http(Int)
    case badResponse

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "No \(provider) API key. Add one to Config/Secrets.xcconfig and rebuild."
        case .rateLimited:
            return "Rate limited by the provider. Try again in a moment."
        case .http(let code):
            return "Request failed (HTTP \(code))."
        case .badResponse:
            return "Couldn't read the provider's response."
        }
    }
}

// MARK: - Shared transport

enum GifHTTP {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 4 << 20, diskCapacity: 32 << 20, directory: nil)
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    static func get<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200..<300: break
            case 429: throw GifProviderError.rateLimited
            default: throw GifProviderError.http(http.statusCode)
            }
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw GifProviderError.badResponse
        }
    }
}
