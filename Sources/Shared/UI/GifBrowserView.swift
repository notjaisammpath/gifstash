import SwiftUI

/// The whole picker. Shared verbatim between the host app and the iMessage
/// extension; only the "what happens on tap" closure differs.
public struct GifBrowserView: View {
    public enum Tab: String, CaseIterable, Hashable {
        case browse, bookmarks

        var label: String {
            switch self {
            case .browse: return "Search"
            case .bookmarks: return "Saved"
            }
        }

        var icon: String {
            switch self {
            case .browse: return "magnifyingglass"
            case .bookmarks: return "bookmark"
            }
        }
    }

    /// Called when a GIF is chosen: insert into the conversation, or share.
    let onSelect: (GifItem) -> Void
    /// The extension uses this to grow out of compact presentation when the
    /// keyboard is about to be needed. The host app passes an empty closure.
    let onNeedsRoom: () -> Void

    public init(
        onSelect: @escaping (GifItem) -> Void,
        onNeedsRoom: @escaping () -> Void = {}
    ) {
        self.onSelect = onSelect
        self.onNeedsRoom = onNeedsRoom
    }

    @State private var model = GifBrowserModel()
    @State private var tab: Tab = .browse
    @State private var showingSettings = false
    @FocusState private var searchFocused: Bool

    private var catalog: GifCatalog { .shared }
    private var store: BookmarkStore { .shared }

    public var body: some View {
        VStack(spacing: 8) {
            header

            if tab == .browse {
                browseContent
            } else {
                bookmarksContent
            }

            footer
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            store.reload()
            if model.items.isEmpty { model.reload() }
        }
        .onChange(of: searchFocused) { _, focused in
            if focused { onNeedsRoom() }
        }
        .onChange(of: catalog.selectedID) { _, _ in model.reload() }
        .onChange(of: catalog.rating) { _, _ in model.reload() }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: 8) {
            Picker("View", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { value in
                    Text(value.label).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Settings")
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search " + model.provider.displayName, text: $model.query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($searchFocused)

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: Capsule())
    }

    private var footer: some View {
        HStack {
            Text(model.provider.attribution)
            Spacer()
            if tab == .bookmarks {
                Text(savedCountLabel)
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.bottom, 6)
    }

    private var savedCountLabel: String {
        String(store.bookmarks.count) + " saved"
    }

    // MARK: - Browse

    @ViewBuilder
    private var browseContent: some View {
        searchField

        if !catalog.hasAnyKey {
            missingKeyState
        } else if let message = model.errorMessage {
            errorState(message)
        } else if model.isLoading && model.items.isEmpty {
            centered { ProgressView() }
        } else if model.isEmptyResult {
            centered {
                emptyState(
                    icon: "magnifyingglass",
                    title: model.query.isEmpty ? "Nothing trending" : "No results",
                    detail: model.query.isEmpty ? nil : "Try a different search."
                )
            }
        } else {
            grid(items: model.items, paginates: true)
        }
    }

    // MARK: - Bookmarks

    @ViewBuilder
    private var bookmarksContent: some View {
        if store.bookmarks.isEmpty {
            centered {
                emptyState(
                    icon: "bookmark",
                    title: "No saved GIFs",
                    detail: "Tap the bookmark on any GIF to keep it here."
                )
            }
        } else {
            grid(items: store.bookmarks.map(\.item), paginates: false)
        }
    }

    // MARK: - Grid

    private func grid(items: [GifItem], paginates: Bool) -> some View {
        GeometryReader { geometry in
            let columns = max(2, Int(geometry.size.width / 118))

            ScrollView {
                WaterfallGrid(
                    items: items,
                    columns: columns,
                    spacing: 6,
                    heightRatio: { 1 / max(0.2, $0.aspectRatio) }
                ) { item in
                    GifThumbnail(
                        item: item,
                        isBookmarked: store.contains(item),
                        onTap: { onSelect(item) },
                        onBookmark: { store.toggle(item) }
                    )
                    .onAppear {
                        guard paginates, item.id == items.last?.id else { return }
                        model.loadMore()
                    }
                }
                .padding(.bottom, 8)

                if model.isLoadingMore {
                    ProgressView().padding(.vertical, 8)
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    // MARK: - States

    private var missingKeyState: some View {
        centered {
            VStack(spacing: 10) {
                emptyState(
                    icon: "key",
                    title: "No API key",
                    detail: "Add a GIPHY key to Config/Secrets.xcconfig, then rebuild."
                )
                Button("Settings") { showingSettings = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }

    private func errorState(_ message: String) -> some View {
        centered {
            VStack(spacing: 10) {
                emptyState(
                    icon: "exclamationmark.triangle",
                    title: "Something went wrong",
                    detail: message
                )
                Button("Try Again") { model.reload() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func emptyState(icon: String, title: String, detail: String?) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.subheadline.weight(.medium))
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack {
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}
