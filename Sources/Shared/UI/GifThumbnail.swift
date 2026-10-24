import SwiftUI

/// One grid cell: loads its own preview bytes, plays them, and exposes
/// tap-to-send plus a bookmark toggle.
struct GifThumbnail: View {
    let item: GifItem
    let isBookmarked: Bool
    let onTap: () -> Void
    let onBookmark: () -> Void

    @State private var data: Data?
    @State private var failed = false
    @State private var taps = 0

    private let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        Button {
            taps += 1
            onTap()
        } label: {
            ZStack {
                Rectangle()
                    .fill(Color.surface)

                if let data {
                    AnimatedGifView(key: item.id, data: data)
                        .transition(.opacity)
                } else if failed {
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundStyle(.tertiary)
                        .font(.callout)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .shimmer()
                }
            }
            .aspectRatio(item.aspectRatio, contentMode: .fit)
            .clipShape(shape)
            .contentShape(shape)
        }
        .buttonStyle(PressableButtonStyle())
        .overlay(alignment: .bottomTrailing) { bookmarkButton }
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .accessibilityLabel(item.title.isEmpty ? "GIF" : item.title)
        .accessibilityHint("Double tap to send")
        .task(id: item.previewURL) { await load() }
    }

    private var bookmarkButton: some View {
        Button(action: onBookmark) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isBookmarked ? AnyShapeStyle(.tint) : AnyShapeStyle(.white))
                .symbolEffect(.bounce, value: isBookmarked)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: Circle())
                .environment(\.colorScheme, .dark)
        }
        .buttonStyle(.plain)
        .padding(6)
        .sensoryFeedback(.impact(weight: .medium), trigger: isBookmarked)
        .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark")
    }

    private func load() async {
        data = nil
        failed = false
        do {
            let loaded = try await GifLoader.shared.data(for: item.previewURL)
            withAnimation(.easeOut(duration: 0.25)) { data = loaded }
        } catch {
            // Scrolling cancels in-flight loads. URLSession reports that as
            // URLError.cancelled rather than CancellationError, and neither is
            // a failure worth showing the user.
            guard !Task.isCancelled else { return }
            if (error as? URLError)?.code != .cancelled {
                failed = true
            }
        }
    }
}
