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

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.quaternary)

            if let data {
                AnimatedGifView(key: item.id, data: data)
            } else if failed {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ProgressView()
                    .controlSize(.small)
            }

            bookmarkButton
        }
        .aspectRatio(item.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title.isEmpty ? "GIF" : item.title)
        .accessibilityHint("Double tap to send")
        .task(id: item.previewURL) { await load() }
    }

    private var bookmarkButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: onBookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark")
            }
        }
        .padding(5)
    }

    private func load() async {
        data = nil
        failed = false
        do {
            data = try await GifLoader.shared.data(for: item.previewURL)
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
