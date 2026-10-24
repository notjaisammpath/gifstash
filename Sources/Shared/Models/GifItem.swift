import Foundation

/// A single GIF, normalized across providers.
public struct GifItem: Identifiable, Hashable, Codable, Sendable {
    /// Stable within a provider; prefixed with the provider id to stay unique across them.
    public let id: String
    public let providerID: String
    public let title: String
    /// Small animated rendition, sized for a grid cell.
    public let previewURL: URL
    /// Full animated rendition — this is what actually gets sent into the conversation.
    public let fullURL: URL
    public let width: Int
    public let height: Int
    /// Permalink on the provider's site, for attribution.
    public let sourceURL: URL?

    public init(
        id: String,
        providerID: String,
        title: String,
        previewURL: URL,
        fullURL: URL,
        width: Int,
        height: Int,
        sourceURL: URL? = nil
    ) {
        self.id = "\(providerID):\(id)"
        self.providerID = providerID
        self.title = title
        self.previewURL = previewURL
        self.fullURL = fullURL
        self.width = width
        self.height = height
        self.sourceURL = sourceURL
    }

    public var aspectRatio: Double {
        guard width > 0, height > 0 else { return 1 }
        return Double(width) / Double(height)
    }

    /// Filesystem-safe name used when handing the GIF to Messages as an attachment.
    public var filename: String {
        let base = title.isEmpty ? "gif" : title
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = base.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: .whitespaces)
        return String(cleaned.isEmpty ? "gif" : cleaned.prefix(60)) + ".gif"
    }
}
