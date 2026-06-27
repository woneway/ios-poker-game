import Foundation

// MARK: - Hand Analysis Utilities
//
// This file contains hand analysis utilities including Chen Formula,
// draw analysis, and board texture analysis.
// Extracted to improve code modularity.

struct HandAnalysis {

    // MARK: - Chen Formula

    /// Bill Chen's formula for starting hand strength
    /// Returns a score from -1.5 to 20
    /// Reference: "The Mathematics of Poker" by Bill Chen
    static func chenFormula(_ cards: [Card]) -> Double {
        guard cards.count == 2 else { return 0.0 }

        let r1 = cards[0].rank.rawValue  // 0=2, 1=3, ..., 12=Ace
        let r2 = cards[1].rank.rawValue
        let high = max(r1, r2)
        let low = min(r1, r2)
        let isPair = r1 == r2
        let isSuited = cards[0].suit == cards[1].suit
        let gap = high - low

        var score: Double

        // Step 1: Score the highest card
        switch high {
        case 12: score = 10.0  // Ace
        case 11: score = 8.0   // King
        case 10: score = 7.0   // Queen
        case 9:  score = 6.0   // Jack
        default: score = Double(high + 2) / 2.0  // 2→2, 3→2.5, 4→3, ..., 10→6
        }

        // Step 2: Pairs - multiply by 2, minimum 5
        if isPair {
            score = max(5.0, score * 2.0)
            return score  // Pairs don't get gap/suited adjustments
        }

        // Step 3: Suited bonus
        if isSuited {
            score += 2.0
        }

        // Step 4: Gap penalty
        switch gap {
        case 1: break              // Connected: no penalty
        case 2: score -= 1.0       // 1-gap
        case 3: score -= 2.0       // 2-gap
        case 4: score -= 4.0       // 3-gap
        default: score -= 5.0      // 4+ gap
        }

        // Step 5: Straight bonus for low connected cards
        if gap <= 2 && high <= 10 {
            score += 1.0
        }

        return max(-1.5, score)
    }

    /// Normalize Chen score to 0-1 range
    static func chenToNormalized(_ chen: Double) -> Double {
        return max(0.0, min(1.0, (chen + 1.5) / 21.5))
    }

    // MARK: - Draw Analysis

    /// Analyze flush and straight draws
    static func analyzeDraws(holeCards: [Card], communityCards: [Card]) -> DrawInfo {
        let allCards = holeCards + communityCards

        // Flush Draw analysis
        var suitCounts: [Suit: Int] = [:]
        for card in allCards {
            suitCounts[card.suit, default: 0] += 1
        }
        let maxSuitCount = suitCounts.values.max() ?? 0
        let hasFlushDraw = maxSuitCount == 4 && communityCards.count < 5

        var flushSuit: Suit? = nil
        for (suit, count) in suitCounts where count == 4 {
            flushSuit = suit
            break
        }

        var flushOuts = 0
        if hasFlushDraw, flushSuit != nil {
            flushOuts = 13 - maxSuitCount
        }

        // Straight Draw analysis
        let ranks = Set(allCards.map { $0.rank.rawValue })
        var rankSet = ranks
        if ranks.contains(12) { rankSet.insert(-1) }

        var hasOESD = false
        var hasGutshot = false
        var straightOuts = 0

        if communityCards.count >= 3 && communityCards.count < 5 {
            for baseRank in -1...9 {
                let window = Set(baseRank...(baseRank + 4))
                let overlap = window.intersection(rankSet)
                if overlap.count == 4 {
                    let missing = window.subtracting(rankSet)
                    if let missingRank = missing.first {
                        if missingRank == baseRank || missingRank == baseRank + 4 {
                            if !hasOESD {
                                hasOESD = true
                                straightOuts = 8
                            }
                        } else {
                            if !hasOESD && !hasGutshot {
                                hasGutshot = true
                                straightOuts = 4
                            }
                        }
                    }
                }
            }
        }

        let hasCombo = hasFlushDraw && (hasOESD || hasGutshot)

        var overlap = 0
        if hasCombo {
            overlap = 1  // Simplified estimate
        }

        return DrawInfo(
            hasFlushDraw: hasFlushDraw,
            hasOpenEndedStraight: hasOESD,
            hasGutshot: hasGutshot,
            hasComboDraws: hasCombo,
            flushOuts: flushOuts,
            straightOuts: straightOuts,
            overlap: overlap
        )
    }

    // MARK: - Board Texture Analysis

    /// Analyze the board texture
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
        let uniqueSuits = suitCounts.count
        let isTwoTone = uniqueSuits == 2

        // Rank analysis
        var rankCounts: [Rank: Int] = [:]
        for card in community {
            rankCounts[card.rank, default: 0] += 1
        }
        let isPaired = rankCounts.values.contains { $0 >= 2 }

        // High cards
        let highRanks: Set<Int> = [12, 11, 10]
        let hasHighCards = community.contains { highRanks.contains($0.rank.rawValue) }

        // Connectivity
        let sortedRanks = community.map { $0.rank.rawValue }.sorted()
        var consecutiveCount = 1
        var maxConsecutive = 1
        for i in 1..<sortedRanks.count {
            if sortedRanks[i] - sortedRanks[i-1] == 1 {
                consecutiveCount += 1
                maxConsecutive = max(maxConsecutive, consecutiveCount)
            } else if sortedRanks[i] - sortedRanks[i-1] > 1 {
                consecutiveCount = 1
            }
        }

        // Check Ace-low straight
        let aceLowRanks = Set(sortedRanks)
        if aceLowRanks.contains(12) && aceLowRanks.contains(0) &&
           aceLowRanks.contains(1) && aceLowRanks.contains(2) {
            maxConsecutive = max(maxConsecutive, 4)
        }

        let connectivity = Double(maxConsecutive) / 5.0
        let suitedness = isMonotone ? 1.0 : (isTwoTone ? 0.5 : 0.0)
        let wetness = (connectivity + suitedness) / 2.0

        return BoardTexture(
            wetness: wetness,
            isPaired: isPaired,
            isMonotone: isMonotone,
            isTwoTone: isTwoTone,
            hasHighCards: hasHighCards,
            connectivity: connectivity
        )
    }

    // MARK: - Hand Strength

    /// Calculate basic hand strength
    static func calculateHandStrength(holeCards: [Card], community: [Card]) -> Double {
        guard community.count >= 3 else { return 0.5 }

        let allCards = holeCards + community

        // Check pairs
        var rankCounts: [Rank: Int] = [:]
        for card in allCards {
            rankCounts[card.rank, default: 0] += 1
        }

        let maxPairCount = rankCounts.values.max() ?? 0
        let tripsCount = rankCounts.values.filter { $0 == 3 }.count
        let quadsCount = rankCounts.values.filter { $0 >= 4 }.count

        // Check flush
        var suitCounts: [Suit: Int] = [:]
        for card in allCards {
            suitCounts[card.suit, default: 0] += 1
        }
        let hasFlush = suitCounts.values.contains { $0 >= 5 }

        // Check straight
        let hasStraight = checkStraight(cards: allCards)

        var strength: Double = 0.3

        if quadsCount > 0 {
            strength = 0.95
        } else if tripsCount > 0 {
            strength = 0.80
        } else if maxPairCount >= 2 {
            strength = 0.70
        } else if maxPairCount == 1 {
            strength = 0.50
        }

        if hasFlush {
            strength = max(strength, 0.85)
        }
        if hasStraight {
            strength = max(strength, 0.90)
        }

        return strength
    }

    /// Check if cards contain a straight
    private static func checkStraight(cards: [Card]) -> Bool {
        let ranks = Set(cards.map { $0.rank.rawValue })
        var rankSet = ranks
        if ranks.contains(12) { rankSet.insert(-1) }

        for baseRank in -1...9 {
            let window = Set(baseRank...(baseRank + 4))
            if window.isSubset(of: rankSet) {
                return true
            }
        }
        return false
    }
}
