import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClear = false

    private var catalog: GifCatalog { .shared }
    private var store: BookmarkStore { .shared }

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    ForEach(catalog.providers, id: \.id) { provider in
                        Button {
                            catalog.select(provider.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.displayName)
                                        .foregroundStyle(.primary)
                                    if !provider.isConfigured {
                                        Text("No API key")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if catalog.selectedID == provider.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .disabled(!provider.isConfigured)
                    }
                }

                Section("Content Rating") {
                    Picker("Rating", selection: ratingBinding) {
                        ForEach(GifRating.allCases, id: \.self) { rating in
                            Text(rating.label).tag(rating)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Saved") {
                    HStack {
                        Text("Bookmarks")
                        Spacer()
                        Text(String(store.bookmarks.count))
                            .foregroundStyle(.secondary)
                    }
                    Button("Remove All Bookmarks", role: .destructive) {
                        confirmingClear = true
                    }
                    .disabled(store.bookmarks.isEmpty)
                }

                Section {
                    LabeledContent("Version", value: Self.version)
                } footer: {
                    Text("GIFs and trending results are provided by the selected source.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Remove all bookmarks?",
                isPresented: $confirmingClear,
                titleVisibility: .visible
            ) {
                Button("Remove All", role: .destructive) { store.removeAll() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private var ratingBinding: Binding<GifRating> {
        Binding(
            get: { catalog.rating },
            set: { catalog.setRating($0) }
        )
    }
}
