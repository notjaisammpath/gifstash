import SwiftUI

struct HostRootView: View {
    @State private var selection = 0
    @State private var detail: GifItem?

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                GifBrowserView(onSelect: { detail = $0 })
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) { BrandMark() }
                    }
            }
            .tabItem { Label("Browse", systemImage: "square.grid.2x2") }
            .tag(0)

            HowToUseView()
                .tabItem { Label("Guide", systemImage: "sparkles") }
                .tag(1)
        }
        .sheet(item: $detail) { item in
            GifDetailSheet(item: item)
        }
    }
}

/// The app name with a small gradient badge, used in the navigation bar.
struct BrandMark: View {
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(BrandGradient(), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text("GifStash")
                .font(.system(.headline, design: .rounded, weight: .bold))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Matches the app icon's violet-to-magenta background.
struct BrandGradient: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.42, green: 0.22, blue: 0.95), Color(red: 0.93, green: 0.25, blue: 0.62)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                    if let data {
                        AnimatedGifView(key: item.id, data: data, contentMode: .scaleAspectFit)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .transition(.opacity)
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
                    .controlSize(.large)
                    .sensoryFeedback(.impact(weight: .medium), trigger: store.contains(item))

                    if let fileURL {
                        ShareLink(item: fileURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
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
                if let source = item.sourceURL {
                    ToolbarItem(placement: .primaryAction) {
                        Link(destination: source) {
                            Image(systemName: "safari")
                        }
                        .accessibilityLabel("Open on " + (item.providerID == "giphy" ? "GIPHY" : "Tenor"))
                    }
                }
            }
            .task(id: item.id) {
                let loaded = try? await GifLoader.shared.data(for: item.fullURL)
                withAnimation(.easeOut(duration: 0.25)) { data = loaded }
                fileURL = try? await GifLoader.shared.fileURL(for: item)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
