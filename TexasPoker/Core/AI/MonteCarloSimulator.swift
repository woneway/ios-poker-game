import Foundation

class MonteCarloSimulator {

    /// 静态缓存：基础可用牌（去除大小王）
    /// 52 张牌：4 花色 x 13 点数
    private static var cachedBaseCards: [Card]? = nil
    
    /// Equity 结果缓存
    /// Key: (holeCards sorted by id, communityCards sorted by id, playerCount)
    /// Value: calculated equity
    private static var equityCache: [String: Double] = [:]
    private static let maxCacheSize = 1000  // 限制缓存大小
    
    /// 缓存键生成
    private static func cacheKey(holeCards: [Card], communityCards: [Card], playerCount: Int) -> String {
        let holeIds = holeCards.map { $0.id }.sorted()
        let communityIds = communityCards.map { $0.id }.sorted()
        return "\(holeIds)-\(communityIds)-\(playerCount)"
    }

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
    
    /// 清理所有缓存（测试用）
    #if DEBUG
    static func clearCache() {
        cachedBaseCards = nil
        equityCache.removeAll()
    }
    #endif
    
    /// 清理 Equity 缓存
    static func clearEquityCache() {
        equityCache.removeAll()
    }

    /// Calculate equity (win probability) for a given hand
    /// - Parameters:
    ///   - holeCards: The player's 2 hole cards
    ///   - communityCards: Current community cards (0, 3, 4, or 5)
    ///   - playerCount: Number of active players (including hero)
    ///   - iterations: Number of simulations (default 1000 for speed)
    /// - Returns: Double between 0.0 and 1.0
    static func calculateEquity(holeCards: [Card], communityCards: [Card], playerCount: Int, iterations: Int = 1000) -> Double {
        guard playerCount > 1 else { return 1.0 }
        
        // 检查缓存
        let key = cacheKey(holeCards: holeCards, communityCards: communityCards, playerCount: playerCount)
        if let cached = equityCache[key] {
            return cached
        }

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
        let equity = (Double(wins) + Double(splits) / 2.0) / Double(iterations)
        
        // 存储到缓存
        if equityCache.count >= maxCacheSize {
            // 缓存已满，清除最旧的50%
            let keysToRemove = Array(equityCache.keys.prefix(maxCacheSize / 2))
            for key in keysToRemove {
                equityCache.removeValue(forKey: key)
            }
        }
        equityCache[key] = equity
        
        return equity
    }

}
