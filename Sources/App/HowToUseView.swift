import SwiftUI

struct HowToUseView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    hero
                }
                .listRowBackground(Color.clear)

                Section("Turn it on in Messages") {
                    step(1, "Open Messages and start or open any conversation.")
                    step(2, "Tap the plus button to the left of the text field.")
                    step(3, "Tap More, then choose GifStash.")
                    step(4, "Search for a GIF and tap it to drop it into your message.")
                }

                Section {
                    feature(
                        "text.bubble",
                        "Nothing sends by itself",
                        "Tapping a GIF puts it in the message field, so you can add text or remove it first."
                    )
                    feature(
                        "bookmark",
                        "Save your favourites",
                        "Tap the bookmark on any GIF. Saved GIFs show up here and in Messages."
                    )
                    feature(
                        "square.and.arrow.up",
                        "Share from the app",
                        "Tap a GIF here to preview it, save it, or share it anywhere."
                    )
                }
            }
            .navigationTitle("Guide")
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(BrandGradient(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .purple.opacity(0.4), radius: 16, y: 6)
            Text("GifStash")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text("Find the perfect GIF and keep the good ones.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(String(number))
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.tint, in: Circle())
            Text(text)
                .font(.callout)
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 2)
    }
}
