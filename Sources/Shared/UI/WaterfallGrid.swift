import SwiftUI

/// Column-packed grid. GIFs have wildly different aspect ratios, and a plain
/// LazyVGrid leaves ragged gaps because every row sizes to its tallest cell.
/// Packing each item into whichever column is currently shortest keeps the
/// layout tight, and the result is deterministic so appending a page does not
/// reshuffle what is already on screen.
struct WaterfallGrid<Item: Identifiable, Cell: View>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    /// Normalized height of one item at unit width, i.e. 1 / aspectRatio.
    let heightRatio: (Item) -> Double
    @ViewBuilder let cell: (Item) -> Cell

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(packed().enumerated()), id: \.offset) { _, column in
                LazyVStack(spacing: spacing) {
                    ForEach(column) { item in
                        cell(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private func packed() -> [[Item]] {
        let count = max(1, columns)
        var buckets = Array(repeating: [Item](), count: count)
        var heights = Array(repeating: 0.0, count: count)

        for item in items {
            // Ties resolve to the leftmost column, which keeps order readable.
            var shortest = 0
            for index in 1..<count where heights[index] < heights[shortest] - 0.0001 {
                shortest = index
            }
            buckets[shortest].append(item)
            heights[shortest] += max(0.2, min(3.0, heightRatio(item)))
        }
        return buckets
    }
}
