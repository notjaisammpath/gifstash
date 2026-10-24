import SwiftUI
import UIKit
import ImageIO

/// Plays an animated GIF from in-memory data using ImageIO, so there is no
/// third-party dependency and no frame decoding on our side.
public struct AnimatedGifView: UIViewRepresentable {
    /// Cheap identity for the data, so we can tell "same GIF" from "new GIF"
    /// without comparing megabytes of bytes on every SwiftUI update.
    let key: String
    let data: Data?
    let contentMode: UIView.ContentMode

    public init(key: String, data: Data?, contentMode: UIView.ContentMode = .scaleAspectFill) {
        self.key = key
        self.data = data
        self.contentMode = contentMode
    }

    public func makeUIView(context: Context) -> GifPlayerView {
        let view = GifPlayerView()
        view.clipsToBounds = true
        view.contentMode = contentMode
        view.isUserInteractionEnabled = false
        // UIImageView's intrinsic size is the GIF's pixel size; without this
        // SwiftUI lets it push wider than the space it was offered.
        for axis in [NSLayoutConstraint.Axis.horizontal, .vertical] {
            view.setContentCompressionResistancePriority(.defaultLow, for: axis)
            view.setContentHuggingPriority(.defaultLow, for: axis)
        }
        return view
    }

    public func updateUIView(_ view: GifPlayerView, context: Context) {
        view.contentMode = contentMode
        view.play(data, key: key)
    }

    public static func dismantleUIView(_ view: GifPlayerView, coordinator: Coordinator) {
        view.stop()
    }
}

public final class GifPlayerView: UIImageView {
    /// Bumped on every new GIF; the animation block exits when it sees a stale value.
    private var generation = 0
    private var currentKey: String?

    public func play(_ data: Data?, key: String) {
        guard currentKey != key else { return }
        currentKey = key
        generation &+= 1
        let thisGeneration = generation

        guard let data else {
            image = nil
            return
        }

        // Show frame one immediately so the cell never flashes empty.
        image = UIImage(data: data)

        _ = CGAnimateImageDataWithBlock(data as CFData, nil) { [weak self] _, frame, stop in
            guard let self, self.generation == thisGeneration else {
                stop.pointee = true
                return
            }
            self.image = UIImage(cgImage: frame)
        }
    }

    public func stop() {
        generation &+= 1
        currentKey = nil
        image = nil
    }
}
