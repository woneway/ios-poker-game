import Foundation

/// Represents a cash game session with buy-in, top-ups, and hand profit tracking.
struct CashGameSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    let initialBuyIn: Int
    var topUpTotal: Int = 0
    var finalChips: Int = 0
    var handsPlayed: Int = 0
    var handProfits: [Int] = []

    /// Net profit: final chips minus initial buy-in and total top-ups
    var netProfit: Int {
        finalChips - initialBuyIn - topUpTotal
    }

    /// Maximum single hand win (positive profit)
    var maxWin: Int {
        handProfits.max() ?? 0
    }

    /// Maximum single hand loss (negative profit)
    var maxLoss: Int {
        handProfits.min() ?? 0
    }

    /// Session duration in seconds
    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    /// Creates a new cash game session with the given buy-in amount.
    /// - Parameter buyIn: The initial buy-in amount in chips.
    init(buyIn: Int) {
        self.id = UUID()
        self.startTime = Date()
        self.initialBuyIn = buyIn
    }
}
