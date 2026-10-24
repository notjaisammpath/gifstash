import Foundation
import Observation

/// Drives search, trending, and paging for whichever provider is selected.
@MainActor
@Observable
public final class GifBrowserModel {
    public var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch()
        }
    }

    public private(set) var items: [GifItem] = []
    public private(set) var isLoading = false
    public private(set) var isLoadingMore = false
    public private(set) var errorMessage: String?

    private var cursor: String?
    private var hasMore = true
    /// Bumped on every reload so a superseded load cannot write back.
    private var generation = 0
    private var pendingSearch: Task<Void, Never>?
    private var activeLoad: Task<Void, Never>?

    private let catalog: GifCatalog

    public init(catalog: GifCatalog = .shared) {
        self.catalog = catalog
    }

    public var provider: any GifProvider { catalog.selected }

    /// True once we have finished a load and genuinely found nothing.
    public var isEmptyResult: Bool {
        !isLoading && errorMessage == nil && items.isEmpty
    }

    // MARK: - Loading

    public func reload() {
        pendingSearch?.cancel()
        activeLoad?.cancel()
        generation &+= 1
        cursor = nil
        hasMore = true
        errorMessage = nil
        items = []

        activeLoad = Task { await fetch(replacing: true) }
    }

    public func loadMore() {
        guard hasMore, !isLoading, !isLoadingMore, cursor != nil else { return }
        activeLoad = Task { await fetch(replacing: false) }
    }

    private func scheduleSearch() {
        pendingSearch?.cancel()
        pendingSearch = Task {
            // Debounce so typing does not fire a request per keystroke.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            // Clear first: reload() cancels pendingSearch, which is this task.
            pendingSearch = nil
            reload()
        }
    }

    private func fetch(replacing: Bool) async {
        let myGeneration = generation
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard provider.isConfigured else {
            errorMessage = GifProviderError
                .missingAPIKey(provider: provider.displayName)
                .localizedDescription
            return
        }

        if replacing { isLoading = true } else { isLoadingMore = true }
        defer {
            // Only the newest load owns these flags.
            if generation == myGeneration {
                isLoading = false
                isLoadingMore = false
            }
        }

        let page = GifPage(cursor: replacing ? nil : cursor, limit: 30)

        do {
            let results = trimmed.isEmpty
                ? try await provider.trending(rating: catalog.rating, page: page)
                : try await provider.search(query: trimmed, rating: catalog.rating, page: page)

            guard !Task.isCancelled, generation == myGeneration else { return }

            if replacing {
                items = results.items
            } else {
                // Providers occasionally repeat an item across pages.
                let known = Set(items.map(\.id))
                items.append(contentsOf: results.items.filter { !known.contains($0.id) })
            }
            cursor = results.nextCursor
            hasMore = results.nextCursor != nil
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == myGeneration else { return }
            errorMessage = error.localizedDescription
            hasMore = false
        }
    }
}
