import Foundation

/// Linear-interpolation percentile. `p` in [0, 1]. Returns nil for empty input.
func percentile(_ values: [Double], p: Double) -> Double? {
    guard !values.isEmpty else { return nil }
    guard p > 0 else { return values.min() }
    guard p < 1 else { return values.max() }
    let sorted = values.sorted()
    let rank = p * Double(sorted.count - 1)
    let lower = Int(rank.rounded(.down))
    let upper = Int(rank.rounded(.up))
    if lower == upper { return sorted[lower] }
    let fraction = rank - Double(lower)
    return sorted[lower] + fraction * (sorted[upper] - sorted[lower])
}
