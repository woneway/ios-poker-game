import Foundation

// MARK: - EV Calculation Models

/// Represents the expected value of a potential action
struct ExpectedValue {
    let action: PlayerAction
    let ev: Double
    let reason: String

    static func compare(_ a: ExpectedValue, _ b: ExpectedValue) -> ExpectedValue {
        return a.ev >= b.ev ? a : b
    }
}

/// Action options with their calculated EVs
struct ActionEV {
    let action: PlayerAction
    let equity: Double      // Win probability
    let potOdds: Double     // Break-even equity needed
    let impliedOdds: Double // Implied odds bonus
    let ev: Double          // Expected value

    /// Determine if this action is +EV
    var isPositiveEV: Bool {
        return equity > potOdds
    }
}

// MARK: - Draw & Board Analysis Helpers

/// Describes the type of draws a player has
struct DrawInfo {
    let hasFlushDraw: Bool       // 4 cards of same suit (need 1 more)
    let hasOpenEndedStraight: Bool  // 4 consecutive (need 1 on either end)
    let hasGutshot: Bool         // Need 1 specific card to complete straight
    let hasComboDraws: Bool      // Flush draw + straight draw
    let flushOuts: Int           // Number of cards that complete flush
    let straightOuts: Int        // Number of cards that complete straight
    let overlap: Int             // Cards that complete both draws

    init(hasFlushDraw: Bool, hasOpenEndedStraight: Bool, hasGutshot: Bool,
         hasComboDraws: Bool, flushOuts: Int, straightOuts: Int, overlap: Int = 0) {
        self.hasFlushDraw = hasFlushDraw
        self.hasOpenEndedStraight = hasOpenEndedStraight
        self.hasGutshot = hasGutshot
        self.hasComboDraws = hasComboDraws
        self.flushOuts = flushOuts
        self.straightOuts = straightOuts
        self.overlap = overlap
    }

    var totalOuts: Int {
        // Subtract actual overlap when both flush + straight draws exist
        if hasComboDraws {
            return flushOuts + straightOuts - overlap
        }
        return flushOuts + straightOuts
    }

    var hasAnyDraw: Bool {
        return hasFlushDraw || hasOpenEndedStraight || hasGutshot
    }
}

/// Board texture analysis
struct BoardTexture {
    let wetness: Double     // 0 = rainbow dry, 1 = monotone connected
    let isPaired: Bool      // Board has a pair
    let isMonotone: Bool    // 3+ cards same suit on board
    let isTwoTone: Bool     // Exactly 2 suits on board
    let hasHighCards: Bool  // Board has A, K, or Q
    let connectivity: Double // 0 = scattered, 1 = very connected
}
