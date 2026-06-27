import Foundation

// MARK: - Decision Engine Analysis Extensions
// This file contains analysis and utility methods extracted from DecisionEngine.swift
// to reduce file size and improve maintainability
//
// Note: chenFormula and analyzeDraws delegate to HandAnalysis to avoid duplication

extension DecisionEngine {

    // MARK: - Chen Formula (delegate to HandAnalysis)

    /// Bill Chen's formula for starting hand strength
    /// Returns a score from -1.5 to 20
    /// Reference: "The Mathematics of Poker" by Bill Chen
    static func chenFormula(_ cards: [Card]) -> Double {
        HandAnalysis.chenFormula(cards)
    }

    /// Normalize Chen score to 0-1 range for threshold comparison
    /// Chen range: roughly -1.5 to 20 (AA=20)
    static func chenToNormalized(_ chen: Double) -> Double {
        HandAnalysis.chenToNormalized(chen)
    }

    // MARK: - Draw Analysis (delegate to HandAnalysis)

    /// Analyze flush and straight draws
    static func analyzeDraws(holeCards: [Card], communityCards: [Card]) -> DrawInfo {
        HandAnalysis.analyzeDraws(holeCards: holeCards, communityCards: communityCards)
    }

    // MARK: - Board Texture Analysis

    /// Analyze how wet/dry and connected a board is
    static func analyzeBoardTexture(_ community: [Card]) -> BoardTexture {
        guard !community.isEmpty else {
            return BoardTexture(wetness: 0, isPaired: false, isMonotone: false,
                                isTwoTone: false, hasHighCards: false, connectivity: 0)
        }

        // Suit analysis
        var suitCounts: [Suit: Int] = [:]
        for card in community {
            suitCounts[card.suit, default: 0] += 1
        }
        let maxSuit = suitCounts.values.max() ?? 0
        let isMonotone = maxSuit >= 3
        let isTwoTone = suitCounts.count == 2

        // Pair analysis
        let ranks = community.map { $0.rank.rawValue }
        let uniqueRanks = Set(ranks)
        let isPaired = uniqueRanks.count < community.count

        // High card analysis
        let hasHighCards = ranks.contains(where: { $0 >= 10 })  // Q, K, A

        // Connectivity: how many cards are within 4 of each other
        let sorted = ranks.sorted()
        var connScore = 0.0
        for i in 0..<sorted.count {
            for j in (i+1)..<sorted.count {
                let diff = sorted[j] - sorted[i]
                if diff <= 4 { connScore += 1.0 }
            }
        }
        let maxConn = Double(sorted.count * (sorted.count - 1)) / 2.0
        let connectivity = maxConn > 0 ? connScore / maxConn : 0

        // Wetness calculation (0-1)
        var wetness = 0.0
        if isMonotone { wetness += 0.40 }
        else if isTwoTone { wetness += 0.15 }

        wetness += connectivity * 0.35
        if isPaired { wetness -= 0.10 }  // Paired boards are drier

        wetness = max(0.0, min(1.0, wetness))

        return BoardTexture(
            wetness: wetness,
            isPaired: isPaired,
            isMonotone: isMonotone,
            isTwoTone: isTwoTone,
            hasHighCards: hasHighCards,
            connectivity: connectivity
        )
    }
}
