import SwiftUI

struct HostRootView: View {
    @State private var selection = 0
    @State private var detail: GifItem?

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                GifBrowserView(onSelect: { detail = $0 })
                    .navigationTitle("GifStash")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Browse", systemImage: "square.grid.2x2") }
            .tag(0)

            HowToUseView()
                .tabItem { Label("Setup", systemImage: "questionmark.circle") }
                .tag(1)
        }
        .sheet(item: $detail) { item in
            GifDetailSheet(item: item)
        }
    }
}

/// Tapping a GIF in the host app cannot insert it anywhere, so it opens a
/// preview with the normal share sheet instead.
struct GifDetailSheet: View {
    let item: GifItem

    @Environment(\.dismiss) private var dismiss
    @State private var data: Data?
    @State private var fileURL: URL?

    private var store: BookmarkStore { .shared }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.quaternary)
                    if let data {
                        AnimatedGifView(key: item.id, data: data, contentMode: .scaleAspectFit)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        ProgressView()
                    }
                }
                .aspectRatio(item.aspectRatio, contentMode: .fit)
                .frame(maxHeight: 420)

                if !item.title.isEmpty {
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button {
                        store.toggle(item)
                    } label: {
                        Label(
                            store.contains(item) ? "Saved" : "Save",
                            systemImage: store.contains(item) ? "bookmark.fill" : "bookmark"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if let fileURL {
                        ShareLink(item: fileURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle(item.providerID == "giphy" ? "GIPHY" : "Tenor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: item.id) {
                data = try? await GifLoader.shared.data(for: item.fullURL)
                fileURL = try? await GifLoader.shared.fileURL(for: item)
            }
        }
    }
}
