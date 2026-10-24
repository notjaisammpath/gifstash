import UIKit
import SwiftUI
import Messages

final class MessagesViewController: MSMessagesAppViewController {
    private var browser: UIHostingController<GifBrowserView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        installBrowser()
    }

    // MARK: - Conversation lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        // The host app may have changed bookmarks while we were not running,
        // and App Group writes are not observable across processes.
        BookmarkStore.shared.reload()
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        if presentationStyle == .compact {
            view.endEditing(true)
        }
    }

    // MARK: - Setup

    private func installBrowser() {
        let root = GifBrowserView(
            onSelect: { [weak self] item in
                self?.send(item)
            },
            onNeedsRoom: { [weak self] in
                guard let self, self.presentationStyle == .compact else { return }
                self.requestPresentationStyle(.expanded)
            }
        )

        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .clear

        addChild(controller)
        view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        controller.didMove(toParent: self)
        browser = controller
    }

    // MARK: - Sending

    private func send(_ item: GifItem) {
        guard let conversation = activeConversation else {
            presentProblem("No active conversation.")
            return
        }

        Task {
            do {
                let fileURL = try await GifLoader.shared.fileURL(for: item)
                try await attach(fileURL, filename: item.filename, to: conversation)
                // Collapse back so the message field is reachable again.
                if presentationStyle == .expanded {
                    requestPresentationStyle(.compact)
                }
            } catch {
                presentProblem(error.localizedDescription)
            }
        }
    }

    /// `insertAttachment` drops the GIF into the input field rather than sending
    /// it outright, which lets the sender add text or back out.
    private func attach(
        _ url: URL,
        filename: String,
        to conversation: MSConversation
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conversation.insertAttachment(url, withAlternateFilename: filename) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func presentProblem(_ message: String) {
        let alert = UIAlertController(
            title: "Could not add GIF",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
