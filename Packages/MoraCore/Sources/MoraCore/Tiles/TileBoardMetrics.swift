import Foundation

/// Phase-level tile-board counters. Persisted in `SessionSummaryEntity`.
public struct TileBoardMetrics: Hashable, Codable, Sendable {
    public var chainCount: Int
    public var truncatedChainCount: Int
    public var totalDropMisses: Int
    public var autoFillCount: Int

    public init(
        chainCount: Int = 0,
        truncatedChainCount: Int = 0,
        totalDropMisses: Int = 0,
        autoFillCount: Int = 0
    ) {
        self.chainCount = chainCount
        self.truncatedChainCount = truncatedChainCount
        self.totalDropMisses = totalDropMisses
        self.autoFillCount = autoFillCount
    }
}
