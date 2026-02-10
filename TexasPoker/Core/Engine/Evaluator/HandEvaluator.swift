import Foundation

class HandEvaluator {
    
    // Category: 8=StraightFlush, 7=Quads, 6=FullHouse, 5=Flush, 4=Straight,
    //           3=Trips, 2=TwoPair, 1=Pair, 0=HighCard
    // Returns (category, kickers) where kickers are sorted descending for comparison
    
    static func evaluate(holeCards: [Card], communityCards: [Card]) -> (Int, [Int]) {
        let allCards = holeCards + communityCards
        let combinations = combinationsOf5(from: allCards)
        
        var bestScore = (-1, [Int]())
        
        for hand in combinations {
            let score = eval5(cards: hand)
            if score.0 > bestScore.0 {
                bestScore = score
            } else if score.0 == bestScore.0 {
                if PokerUtils.compareKickers(score.1, bestScore.1) > 0 {
                    bestScore = score
                }
            }
        }
        return bestScore
    }
    
    private static func eval5(cards: [Card]) -> (Int, [Int]) {
        // Sort by rank descending
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let ranks = sorted.map { $0.rank.rawValue }
        let suits = sorted.map { $0.suit }
        
        let isFlush = suits.allSatisfy { $0 == suits[0] }
        
        // Check Straight (normal)
        var isStraight = true
        for i in 0..<4 {
            if ranks[i] != ranks[i+1] + 1 {
                isStraight = false
                break
            }
        }
        
        // Check Wheel (A-2-3-4-5): sorted ranks = [12, 3, 2, 1, 0]
        let isWheel = !isStraight && ranks == [12, 3, 2, 1, 0]
        if isWheel {
            isStraight = true
        }
        
        // For wheel, the high card is 5 (rank 3), not Ace
        // Kickers for straight: just the high card of the straight
        let straightKickers: [Int] = isWheel ? [3] : [ranks[0]]
        
        // Count frequencies
        var counts: [Int: Int] = [:]
        for r in ranks { counts[r, default: 0] += 1 }
        let countsValues = counts.values.sorted(by: >)
        
        // 8. Straight Flush (including wheel straight flush)
        if isFlush && isStraight {
            return (8, straightKickers)
        }
        
        // 7. Four of a Kind
        if countsValues == [4, 1] {
            let quadRank = counts.first { $0.value == 4 }!.key
            let kicker = counts.first { $0.value == 1 }!.key
            return (7, [quadRank, kicker])
        }
        
        // 6. Full House
        if countsValues == [3, 2] {
            let tripRank = counts.first { $0.value == 3 }!.key
            let pairRank = counts.first { $0.value == 2 }!.key
            return (6, [tripRank, pairRank])
        }
        
        // 5. Flush
        if isFlush {
            return (5, ranks)
        }
        
        // 4. Straight
        if isStraight {
            return (4, straightKickers)
        }
        
        // 3. Three of a Kind
        if countsValues == [3, 1, 1] {
            let tripRank = counts.first { $0.value == 3 }!.key
            let kickers = ranks.filter { $0 != tripRank }.sorted(by: >)
            return (3, [tripRank] + kickers)
        }
        
        // 2. Two Pair
        if countsValues == [2, 2, 1] {
            let pairs = counts.filter { $0.value == 2 }.keys.sorted(by: >)
            let kicker = counts.filter { $0.value == 1 }.keys.first!
            return (2, pairs + [kicker])
        }
        
        // 1. One Pair
        if countsValues == [2, 1, 1, 1] {
            let pairRank = counts.first { $0.value == 2 }!.key
            let kickers = ranks.filter { $0 != pairRank }.sorted(by: >)
            return (1, [pairRank] + kickers)
        }
        
        // 0. High Card
        return (0, ranks)
    }
    
    private static func combinationsOf5(from cards: [Card]) -> [[Card]] {
        var result: [[Card]] = []
        let n = cards.count
        guard n >= 5 else { return [] }
        
        for i in 0..<(n-4) {
            for j in (i+1)..<(n-3) {
                for k in (j+1)..<(n-2) {
                    for l in (k+1)..<(n-1) {
                        for m in (l+1)..<n {
                            result.append([cards[i], cards[j], cards[k], cards[l], cards[m]])
                        }
                    }
                }
            }
        }
        return result
    }
}
