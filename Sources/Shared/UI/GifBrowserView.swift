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
    /// Opens on Saved; focusing the search field switches to Search.
    @State private var tab: Tab = .bookmarks
    @State private var showingSettings = false
    @FocusState private var searchFocused: Bool
    @Namespace private var tabNamespace

    private var catalog: GifCatalog { .shared }
    private var store: BookmarkStore { .shared }

    public var body: some View {
        VStack(spacing: 8) {
            header
            searchField

            if tab == .browse {
                browseContent
            } else {
                bookmarksContent
            }

            footer
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .tint(Color("AccentColor"))
        .sensoryFeedback(.selection, trigger: tab)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            store.reload()
            if model.items.isEmpty { model.reload() }
        }
        .onChange(of: searchFocused) { _, focused in
            guard focused else { return }
            onNeedsRoom()
            if tab != .browse {
                withAnimation(.snappy(duration: 0.28)) { tab = .browse }
            }
        }
        .onChange(of: catalog.selectedID) { _, _ in model.reload() }
        .onChange(of: catalog.rating) { _, _ in model.reload() }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(Tab.allCases, id: \.self) { value in
                    tabButton(value)
                }
            }
            .padding(3)
            .background(Color.surface, in: Capsule())

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(Color.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Settings")
        }
    }

    private func tabButton(_ value: Tab) -> some View {
        let selected = tab == value
        return Button {
            withAnimation(.snappy(duration: 0.28)) { tab = value }
        } label: {
            Label(value.label, systemImage: value.icon)
                .symbolVariant(selected ? .fill : .none)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .background {
                    if selected {
                        Capsule()
                            .fill(.tint)
                            .matchedGeometryEffect(id: "selectedTab", in: tabNamespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(searchFocused ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))

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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.tint.opacity(searchFocused ? 0.8 : 0), lineWidth: 1.5)
        }
        .animation(.easeOut(duration: 0.15), value: searchFocused)
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
        if !catalog.hasAnyKey {
            missingKeyState
        } else if let message = model.errorMessage {
            errorState(message)
        } else if model.isLoading && model.items.isEmpty {
            skeleton
        } else if model.isEmptyResult {
            if model.query.isEmpty {
                ContentUnavailableView("Nothing trending", systemImage: "flame")
            } else {
                ContentUnavailableView.search(text: model.query)
            }
        } else {
            grid(items: model.items, paginates: true, title: browseTitle)
        }
    }

    private var browseTitle: (String, String) {
        model.query.isEmpty ? ("Trending", "flame.fill") : ("Results", "sparkle.magnifyingglass")
    }

    // MARK: - Bookmarks

    @ViewBuilder
    private var bookmarksContent: some View {
        if store.bookmarks.isEmpty {
            ContentUnavailableView(
                "No saved GIFs",
                systemImage: "bookmark",
                description: Text("Search above, then tap the bookmark on any GIF to keep it here.")
            )
        } else {
            grid(items: store.bookmarks.map(\.item), paginates: false, title: nil)
        }
    }

    // MARK: - Grid

    private func columnCount(for width: CGFloat) -> Int {
        max(2, Int(width / 118))
    }

    private func grid(items: [GifItem], paginates: Bool, title: (String, String)?) -> some View {
        GeometryReader { geometry in
            ScrollView {
                if let title {
                    Label(title.0, systemImage: title.1)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                        .padding(.bottom, 2)
                }

                WaterfallGrid(
                    items: items,
                    columns: columnCount(for: geometry.size.width),
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

                if paginates && model.isLoadingMore {
                    ProgressView().padding(.vertical, 8)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    /// Placeholder cells shown on first load, shaped like a real page of GIFs.
    private var skeleton: some View {
        GeometryReader { geometry in
            WaterfallGrid(
                items: SkeletonCell.page,
                columns: columnCount(for: geometry.size.width),
                spacing: 6,
                heightRatio: { $0.heightRatio }
            ) { cell in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.surface)
                    .aspectRatio(1 / cell.heightRatio, contentMode: .fit)
                    .shimmer()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityLabel("Loading")
    }

    // MARK: - States

    private var missingKeyState: some View {
        ContentUnavailableView {
            Label("No API key", systemImage: "key")
        } description: {
            Text("Add a GIPHY key to Config/Secrets.xcconfig, then rebuild.")
        } actions: {
            Button("Settings") { showingSettings = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") { model.reload() }
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct SkeletonCell: Identifiable {
    let id: Int
    let heightRatio: Double

    static let page: [SkeletonCell] = [0.75, 1.0, 0.56, 1.3, 0.8, 0.6, 1.1, 0.7, 0.9, 1.25, 0.56, 0.85]
        .enumerated()
        .map { SkeletonCell(id: $0.offset, heightRatio: $0.element) }
}
