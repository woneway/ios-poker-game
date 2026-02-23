import Foundation

enum PlayerHandCategory: String, Equatable {
    case premium
    case strong
    case medium
    case speculative
    case weak
    
    var description: String {
        switch self {
        case .premium: return "顶级 (AA, KK, QQ, AKs)"
        case .strong: return "强牌 (JJ, TT, AQs, AKo)"
        case .medium: return "中等 (99-77, AJo, KQs)"
        case .speculative: return "投机 (66-22, suited connectors)"
        case .weak: return "弱牌 (offsuit, broadway以下)"
        }
    }
}

struct HandReading {
    let playerId: String
    let handCategory: PlayerHandCategory
    let confidence: Double
    let street: Street
    let communityCards: [Card]
    let reasoning: String
}

class HandReadingSystem {
    static let shared = HandReadingSystem()
    
    private var playerTendencies: [String: PlayerHandCategory] = [:]
    private var streetReadings: [String: [Street: HandReading]] = [:]
    
    private init() {}
    
    func updateTendency(playerId: String, category: PlayerHandCategory) {
        playerTendencies[playerId] = category
    }
    
    func readHand(playerId: String, communityCards: [Card], street: Street, recentActions: [PlayerAction]) -> HandReading {
        let baseCategory = playerTendencies[playerId] ?? .medium
        
        var adjustedCategory = baseCategory
        var confidence = 0.5
        var reasoning = "基于玩家倾向: \(baseCategory.description)"
        
        if communityCards.isEmpty {
            adjustedCategory = baseCategory
            confidence = 0.4
            reasoning = "翻牌前 - 样本不足"
        } else {
            let hasPair = checkForPair(communityCards)
            let hasFlushDraw = checkForFlushDraw(communityCards)
            let hasStraightDraw = checkForStraightDraw(communityCards)
            
            if hasPair {
                adjustedCategory = upgradeCategory(baseCategory, by: 1)
                confidence += 0.15
                reasoning += "\n公共牌有对子 - 可能击中顶对"
            }
            
            if hasFlushDraw || hasStraightDraw {
                confidence += 0.1
                reasoning += hasFlushDraw ? "\n有同花听牌" : "\n有顺子听牌"
            }
            
            let actionConfidence = analyzeActions(recentActions, street: street)
            confidence += actionConfidence
            reasoning += actionConfidence > 0 ? "\n根据行动调整信心+\(Int(actionConfidence*100))%" : ""
        }
        
        confidence = min(0.95, confidence)
        
        let reading = HandReading(
            playerId: playerId,
            handCategory: adjustedCategory,
            confidence: confidence,
            street: street,
            communityCards: communityCards,
            reasoning: reasoning
        )
        
        if streetReadings[playerId] == nil {
            streetReadings[playerId] = [:]
        }
        streetReadings[playerId]?[street] = reading
        
        return reading
    }
    
    private func checkForPair(_ communityCards: [Card]) -> Bool {
        var ranks: [Int: Int] = [:]
        for card in communityCards {
            ranks[card.rank.rawValue, default: 0] += 1
        }
        return ranks.values.contains { $0 >= 2 }
    }
    
    private func checkForFlushDraw(_ communityCards: [Card]) -> Bool {
        var suits: [Suit: Int] = [:]
        for card in communityCards {
            suits[card.suit, default: 0] += 1
        }
        return suits.values.contains { $0 >= 3 }
    }
    
    private func checkForStraightDraw(_ communityCards: [Card]) -> Bool {
        let sortedRanks = communityCards.map { $0.rank.rawValue }.sorted()
        guard sortedRanks.count >= 3 else { return false }
        var gaps = 0
        for i in 0..<(sortedRanks.count - 1) {
            gaps += sortedRanks[i + 1] - sortedRanks[i] - 1
        }
        return gaps <= 2 && (sortedRanks.last! - sortedRanks.first!) <= 4
    }
    
    private func upgradeCategory(_ category: PlayerHandCategory, by levels: Int) -> PlayerHandCategory {
        let order: [PlayerHandCategory] = [.weak, .speculative, .medium, .strong, .premium]
        guard let currentIndex = order.firstIndex(of: category) else { return category }
        let newIndex = min(order.count - 1, currentIndex + levels)
        return order[newIndex]
    }
    
    private func analyzeActions(_ actions: [PlayerAction], street: Street) -> Double {
        guard !actions.isEmpty else { return 0 }
        
        var confidence: Double = 0.0
        
        var hasRaise = false
        var hasCheck = false
        var hasCall = false
        
        for action in actions {
            switch action {
            case .raise: hasRaise = true
            case .check: hasCheck = true
            case .call: hasCall = true
            default: break
            }
        }
        
        if hasRaise {
            confidence += 0.15
        }
        
        if hasCall && !hasRaise {
            confidence += 0.05
        }
        
        if hasCheck && street == .river {
            confidence -= 0.1
        }
        
        return confidence
    }
    
    func getReading(for playerId: String, at street: Street) -> HandReading? {
        return streetReadings[playerId]?[street]
    }
    
    func clearReadings(for playerId: String? = nil) {
        if let playerId = playerId {
            streetReadings.removeValue(forKey: playerId)
            playerTendencies.removeValue(forKey: playerId)
        } else {
            streetReadings.removeAll()
            playerTendencies.removeAll()
        }
    }
}
