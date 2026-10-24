import Foundation
import Observation

public struct Bookmark: Identifiable, Hashable, Codable, Sendable {
    public let item: GifItem
    public let savedAt: Date

    public var id: String { item.id }

    public init(item: GifItem, savedAt: Date = .now) {
        self.item = item
        self.savedAt = savedAt
    }
}

/// Bookmarks live in the App Group so the host app and the iMessage extension
/// see the same list. Writes from one process are not observable in the other,
/// so callers reload when they become active (see `MessagesViewController`).
@MainActor
@Observable
public final class BookmarkStore {
    public static let shared = BookmarkStore()

    public private(set) var bookmarks: [Bookmark] = []

    private let defaults: UserDefaults
    private let key = "bookmarks.v1"

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: AppConfig.appGroupID)
            ?? .standard
        reload()
    }

    /// Re-read the shared container. Cheap; safe to call on every activation.
    public func reload() {
        guard let data = defaults.data(forKey: key) else {
            bookmarks = []
            return
        }
        bookmarks = (try? JSONDecoder().decode([Bookmark].self, from: data)) ?? []
    }

    public func contains(_ item: GifItem) -> Bool {
        bookmarks.contains { $0.id == item.id }
    }

    public func toggle(_ item: GifItem) {
        if contains(item) {
            remove(item)
        } else {
            add(item)
        }
    }

    public func add(_ item: GifItem) {
        guard !contains(item) else { return }
        bookmarks.insert(Bookmark(item: item), at: 0)
        persist()
    }

    public func remove(_ item: GifItem) {
        bookmarks.removeAll { $0.id == item.id }
        persist()
    }

    public func remove(atOffsets offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        persist()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        bookmarks.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    public func removeAll() {
        bookmarks = []
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        defaults.set(data, forKey: key)
    }
}
