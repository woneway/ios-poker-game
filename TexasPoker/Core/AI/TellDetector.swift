import Foundation

enum TellCategory {
    case timing
    case sizing
    case behavior
    case pattern
}

struct PokerTell {
    let category: TellCategory
    let description: String
    let indicator: String
    let reliability: Double
    let meaning: TellMeaning
}

enum TellMeaning {
    case strong
    case weak
    case bluffing
    case nutted
    case drawing
    case uncertain
}

class TellDetector {
    static let shared = TellDetector()
    
    private var playerTells: [String: [PokerTell]] = [:]
    private var bettingPatterns: [String: [BetPattern]] = [:]
    private let queue = DispatchQueue(label: "com.poker.tells", attributes: .concurrent)
    
    private init() {}
    
    struct BetPattern {
        let timestamp: Date
        let street: Street
        let betSize: Int
        let potSize: Int
        let handStrength: Double
    }
    
    func recordBet(playerId: String, street: Street, betSize: Int, potSize: Int, handStrength: Double) {
        queue.async(flags: .barrier) {
            let pattern = BetPattern(
                timestamp: Date(),
                street: street,
                betSize: betSize,
                potSize: potSize,
                handStrength: handStrength
            )
            
            self.bettingPatterns[playerId, default: []].append(pattern)
            
            if self.bettingPatterns[playerId]!.count > 100 {
                self.bettingPatterns[playerId]!.removeFirst(10)
            }
        }
    }
    
    func detectTimingTell(playerId: String, actionTime: TimeInterval) -> PokerTell? {
        if actionTime < 1.0 {
            return PokerTell(
                category: .timing,
                description: "快速行动",
                indicator: "思考时间 < 1秒",
                reliability: 0.4,
                meaning: .uncertain
            )
        } else if actionTime > 30.0 {
            return PokerTell(
                category: .timing,
                description: "长时间思考",
                indicator: "思考时间 > 30秒",
                reliability: 0.6,
                meaning: .uncertain
            )
        }
        return nil
    }
    
    func detectSizingTell(playerId: String, betSize: Int, potSize: Int, isAllIn: Bool) -> PokerTell? {
        guard potSize > 0 else { return nil }
        
        let betPercent = Double(betSize) / Double(potSize)
        
        if isAllIn {
            return PokerTell(
                category: .sizing,
                description: "全下",
                indicator: "All-in",
                reliability: 0.7,
                meaning: .strong
            )
        }
        
        if betPercent < 0.33 {
            return PokerTell(
                category: .sizing,
                description: "小额下注",
                indicator: "下注 < 1/3 pot",
                reliability: 0.5,
                meaning: .weak
            )
        } else if betPercent > 1.5 {
            return PokerTell(
                category: .sizing,
                description: "超额下注",
                indicator: "下注 > 1.5x pot",
                reliability: 0.6,
                meaning: .bluffing
            )
        }
        
        return nil
    }
    
    func analyzeBettingPattern(playerId: String) -> [PokerTell] {
        return queue.sync {
            guard let patterns = bettingPatterns[playerId], patterns.count >= 10 else {
                return []
            }
            
            var tells: [PokerTell] = []
            
            let recent = patterns.suffix(20)
            let smallBets = recent.filter { Double($0.betSize) / Double($0.potSize) < 0.4 }
            let bigBets = recent.filter { Double($0.betSize) / Double($0.potSize) > 0.8 }
            
            if Double(smallBets.count) / Double(recent.count) > 0.6 {
                tells.append(PokerTell(
                    category: .pattern,
                    description: "经常小额下注",
                    indicator: "60%+ 小于1/3 pot",
                    reliability: 0.6,
                    meaning: .weak
                ))
            }
            
            if Double(bigBets.count) / Double(recent.count) > 0.4 {
                tells.append(PokerTell(
                    category: .pattern,
                    description: "经常超额下注",
                    indicator: "40%+ 大于80% pot",
                    reliability: 0.5,
                    meaning: .bluffing
                ))
            }
            
            let avgStrength = recent.map { $0.handStrength }.reduce(0, +) / Double(recent.count)
            if avgStrength > 0.7 {
                tells.append(PokerTell(
                    category: .pattern,
                    description: "高牌力时行动一致",
                    indicator: "强牌时平均胜率 > 70%",
                    reliability: 0.7,
                    meaning: .strong
                ))
            }
            
            return tells
        }
    }
    
    func getPlayerTells(playerId: String) -> [PokerTell] {
        return queue.sync {
            playerTells[playerId] ?? []
        }
    }
    
    func clearTells(playerId: String) {
        queue.async(flags: .barrier) {
            self.playerTells.removeValue(forKey: playerId)
            self.bettingPatterns.removeValue(forKey: playerId)
        }
    }
}

class HandStrengthProfiler {
    static let shared = HandStrengthProfiler()
    
    private init() {}
    
    func estimateOpponentRangeFromAction(
        action: PlayerAction,
        street: Street,
        position: TablePosition,
        previousActions: [PlayerAction]
    ) -> HandEstimate {
        switch action {
        case .fold:
            return HandEstimate(
                range: 0.0,
                strength: 0.0,
                likelyHands: ["任意弃牌"],
                confidence: 0.8
            )
            
        case .check:
            let strength: Double
            switch street {
            case .flop: strength = 0.3
            case .turn: strength = 0.35
            case .river: strength = 0.4
            default: strength = 0.25
            }
            return HandEstimate(
                range: 0.4,
                strength: strength,
                likelyHands: ["中等牌力", "听牌"],
                confidence: 0.5
            )
            
        case .call:
            return HandEstimate(
                range: 0.35,
                strength: 0.45,
                likelyHands: ["中对", "顶对", "强听牌"],
                confidence: 0.6
            )
            
        case .raise(let amount):
            let isBigRaise = amount > 1000
            return HandEstimate(
                range: isBigRaise ? 0.2 : 0.3,
                strength: isBigRaise ? 0.8 : 0.6,
                likelyHands: isBigRaise ? ["强顶对+", "两对", "Set"] : ["顶对+", "强听牌"],
                confidence: 0.7
            )
            
        case .allIn:
            return HandEstimate(
                range: 0.15,
                strength: 0.9,
                likelyHands: ["强顶对+", "坚果", "强听牌"],
                confidence: 0.85
            )
        }
    }
    
    func combineEstimates(_ estimates: [HandEstimate]) -> HandEstimate {
        guard !estimates.isEmpty else {
            return HandEstimate(range: 0, strength: 0, likelyHands: [], confidence: 0)
        }
        
        let totalConfidence = estimates.reduce(0.0) { $0 + $1.confidence }
        let weightedStrength = estimates.reduce(0.0) { $0 + $1.strength * $1.confidence } / totalConfidence
        let avgRange = estimates.reduce(0.0) { $0 + $1.range } / Double(estimates.count)
        
        var allHands: [String] = []
        for est in estimates {
            allHands.append(contentsOf: est.likelyHands)
        }
        let uniqueHands = Array(Set(allHands)).prefix(5)
        
        return HandEstimate(
            range: avgRange,
            strength: weightedStrength,
            likelyHands: Array(uniqueHands),
            confidence: min(totalConfidence / Double(estimates.count) * 1.2, 0.9)
        )
    }
}

struct HandEstimate {
    let range: Double
    let strength: Double
    let likelyHands: [String]
    let confidence: Double
}
