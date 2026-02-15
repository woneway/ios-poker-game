import Foundation

class MonteCarloSimulator {

    /// 静态缓存：基础可用牌（去除大小王）
    /// 52 张牌：4 花色 x 13 点数
    private static var cachedBaseCards: [Card]? = nil

    /// 获取基础可用牌（缓存）
    private static func getBaseCards() -> [Card] {
        if let cached = cachedBaseCards {
            return cached
        }

        var cards: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                cards.append(Card(rank: rank, suit: suit))
            }
        }
        cachedBaseCards = cards
        return cards
    }

    /// 清理缓存（测试用）
    #if DEBUG
    static func clearCache() {
        cachedBaseCards = nil
    }
    #endif

    /// Calculate equity (win probability) for a given hand
    /// - Parameters:
    ///   - holeCards: The player's 2 hole cards
    ///   - communityCards: Current community cards (0, 3, 4, or 5)
    ///   - playerCount: Number of active players (including hero)
    ///   - iterations: Number of simulations (default 1000 for speed)
    /// - Returns: Double between 0.0 and 1.0
    static func calculateEquity(holeCards: [Card], communityCards: [Card], playerCount: Int, iterations: Int = 1000) -> Double {
        guard playerCount > 1 else { return 1.0 }

        var wins = 0
        var splits = 0

        // 使用缓存的基础牌
        let knownCards = Set(holeCards + communityCards)
        let availableCards = getBaseCards().filter { !knownCards.contains($0) }

        // 计算需要的牌数：每个对手2张 + 5张公共牌
        let neededCards = (playerCount - 1) * 2 + 5
        guard availableCards.count >= neededCards else {
            // 牌数不足，无法进行有效的蒙特卡洛模拟
            return 0.5 // 返回默认值
        }

        for _ in 0..<iterations {
            var deckCards = availableCards
            deckCards.shuffle()

            // Deal to opponents
            var opponentHands: [[Card]] = []
            for _ in 0..<(playerCount - 1) {
                let op1 = deckCards.removeLast()
                let op2 = deckCards.removeLast()
                opponentHands.append([op1, op2])
            }

            // Deal remaining community cards
            var simCommunity = communityCards
            while simCommunity.count < 5 {
                simCommunity.append(deckCards.removeLast())
            }

            // Evaluate
            let myScore = HandEvaluator.evaluate(holeCards: holeCards, communityCards: simCommunity)
            var win = true
            var split = false

            for opHand in opponentHands {
                let opScore = HandEvaluator.evaluate(holeCards: opHand, communityCards: simCommunity)

                // Compare (Tuple: (Category, Kickers))
                // Function returns (Int, [Int]). Higher Int is better category.

                if opScore.0 > myScore.0 {
                    win = false; break
                } else if opScore.0 == myScore.0 {
                    // Compare kickers
                    let cmp = PokerUtils.compareKickers(myScore.1, opScore.1)
                    if cmp < 0 { win = false; break } // I lost on kickers
                    if cmp == 0 { split = true } // Tie so far
                }
            }

            if win {
                if split { splits += 1 }
                else { wins += 1 }
            }
        }

        // Equity = (Wins + (Splits / 2)) / Iterations
        return (Double(wins) + Double(splits) / 2.0) / Double(iterations)
    }

}
