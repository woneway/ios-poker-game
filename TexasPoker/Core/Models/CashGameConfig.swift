import Foundation

/// Configuration for a cash game table, defining blind levels and buy-in ranges.
struct CashGameConfig: Codable {
    let smallBlind: Int
    let bigBlind: Int
    let minBuyIn: Int
    let maxBuyIn: Int
    let maxBuyIns: Int

    /// Default configuration (10/20 blinds)
    static let `default` = CashGameConfig(
        smallBlind: 10,
        bigBlind: 20,
        minBuyIn: 400,
        maxBuyIn: 2000,
        maxBuyIns: 5
    )

    /// Creates a configuration from blind levels.
    /// - Parameters:
    ///   - smallBlind: The small blind amount.
    ///   - bigBlind: The big blind amount.
    /// - Returns: A CashGameConfig with buy-in range calculated as 20-100 big blinds.
    static func from(smallBlind: Int, bigBlind: Int, maxBuyIns: Int = 5) -> CashGameConfig {
        CashGameConfig(
            smallBlind: smallBlind,
            bigBlind: bigBlind,
            minBuyIn: bigBlind * 20,
            maxBuyIn: bigBlind * 100,
            maxBuyIns: maxBuyIns
        )
    }
}
