import SwiftUI

struct HowToUseView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Turn it on in Messages") {
                    step(1, "Open Messages and start or open any conversation.")
                    step(2, "Tap the plus button to the left of the text field.")
                    step(3, "Tap More, then enable GifStash.")
                    step(4, "Pick GifStash from the app row to search GIFs.")
                }

                Section("Sending") {
                    Text("Tapping a GIF drops it into the message field rather than sending it immediately, so you can add text or remove it first.")
                        .font(.callout)
                }

                Section("Bookmarks") {
                    Text("Bookmarks are stored in a shared App Group, so anything you save here shows up in the Messages extension and vice versa.")
                        .font(.callout)
                }

                Section("API keys") {
                    Text("Keys are read from Config/Secrets.xcconfig at build time and are never bundled into source control. Get a GIPHY key at developers.giphy.com.")
                        .font(.callout)
                }
            }
            .navigationTitle("Setup")
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(String(number))
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(.tint, in: Circle())
            Text(text)
                .font(.callout)
        }
    }
}
