import Foundation

enum GamePhase {
    case preflop
    case flop
    case turn
    case river
    case showdown
}

enum BoardTextureType {
    case dry
    case wet
    case monotone
    case paired
    case rainbow
    case connected
}

struct GameStateSnapshot {
    let timestamp: Date
    let phase: GamePhase
    let potSize: Int
    let communityCards: [Card]
    let activePlayers: Int
    let playersToAct: Int
    let currentBet: Int
    let canCheck: Bool
}

class GameStateAnalyzer {
    static let shared = GameStateAnalyzer()
    
    private var stateHistory: [GameStateSnapshot] = []
    private let queue = DispatchQueue(label: "com.poker.gamestate", attributes: .concurrent)
    
    private init() {}
    
    func captureState(
        phase: GamePhase,
        potSize: Int,
        communityCards: [Card],
        activePlayers: Int,
        playersToAct: Int,
        currentBet: Int,
        canCheck: Bool
    ) {
        queue.async(flags: .barrier) {
            let snapshot = GameStateSnapshot(
                timestamp: Date(),
                phase: phase,
                potSize: potSize,
                communityCards: communityCards,
                activePlayers: activePlayers,
                playersToAct: playersToAct,
                currentBet: currentBet,
                canCheck: canCheck
            )
            
            self.stateHistory.append(snapshot)
            
            if self.stateHistory.count > 50 {
                self.stateHistory.removeFirst()
            }
        }
    }
    
    func analyzeBoardTexture(_ communityCards: [Card]) -> BoardTextureAnalysis {
        guard !communityCards.isEmpty else {
            return BoardTextureAnalysis(
                type: .rainbow,
                wetness: 0,
                connectivity: 0,
                hasPair: false,
                hasFlushDraw: false,
                hasStraightDraw: false,
                highCards: 0
            )
        }
        
        var suitCounts: [Suit: Int] = [:]
        for card in communityCards {
            suitCounts[card.suit, default: 0] += 1
        }
        
        let maxSuit = suitCounts.values.max() ?? 0
        let isMonotone = maxSuit >= 3
        let isPaired = Set(communityCards.map { $0.rank }).count < communityCards.count
        
        let ranks = communityCards.map { $0.rank.rawValue }.sorted()
        var connectivity = 0
        for i in 0..<(ranks.count - 1) {
            if ranks[i + 1] - ranks[i] <= 3 {
                connectivity += 1
            }
        }
        
        let suitedCards = maxSuit
        let hasFlushDraw = suitedCards >= 3 && communityCards.count < 5
        
        var hasStraightDraw = false
        if communityCards.count >= 3 {
            let rankSet = Set(ranks)
            for base in -1...9 {
                let window = Set(base...(base + 4))
                if window.intersection(rankSet).count >= 3 {
                    hasStraightDraw = true
                    break
                }
            }
        }
        
        let highCards = ranks.filter { $0 >= 10 }.count
        
        var wetness = 0.0
        if isMonotone { wetness += 0.4 }
        wetness += Double(connectivity) * 0.2
        if hasFlushDraw || hasStraightDraw { wetness += 0.3 }
        if isPaired { wetness += 0.1 }
        
        let type: BoardTextureType
        if isMonotone {
            type = .monotone
        } else if isPaired {
            type = .paired
        } else if connectivity > 2 {
            type = .connected
        } else if suitedCards <= 1 {
            type = .rainbow
        } else if wetness > 0.5 {
            type = .wet
        } else {
            type = .dry
        }
        
        return BoardTextureAnalysis(
            type: type,
            wetness: wetness,
            connectivity: Double(connectivity) / 3.0,
            hasPair: isPaired,
            hasFlushDraw: hasFlushDraw,
            hasStraightDraw: hasStraightDraw,
            highCards: highCards
        )
    }
    
    func getPotCommitmentLevel(playerBet: Int, potSize: Int, stackSize: Int) -> CommitmentLevel {
        guard stackSize > 0 else { return .uncommitted }
        
        let invested = playerBet
        let remaining = stackSize
        
        let commitmentRatio = Double(invested) / Double(stackSize)
        
        if commitmentRatio > 0.8 {
            return .committed
        } else if commitmentRatio > 0.5 {
            return .invested
        } else if invested > potSize / 2 {
            return .partial
        }
        return .uncommitted
    }
    
    func analyzeActionSequence() -> ActionSequenceAnalysis {
        return queue.sync {
            guard stateHistory.count >= 3 else {
                return ActionSequenceAnalysis(
                    isAggressive: false,
                    isPassive: false,
                    hasRaiseWar: false,
                    actionCount: stateHistory.count,
                    avgBetSize: 0
                )
            }
            
            let recent = stateHistory.suffix(5)
            let avgBet = recent.map { $0.currentBet }.reduce(0, +) / recent.count
            
            let hasRaises = recent.contains { $0.currentBet > 0 }
            
            return ActionSequenceAnalysis(
                isAggressive: avgBet > 100,
                isPassive: avgBet < 50,
                hasRaiseWar: false,
                actionCount: recent.count,
                avgBetSize: avgBet
            )
        }
    }
    
    func isMultiwayPot() -> Bool {
        return queue.sync {
            guard let last = stateHistory.last else { return false }
            return last.activePlayers > 2
        }
    }
    
    func getHeadsUpChance() -> Double {
        return queue.sync {
            guard let last = stateHistory.last else { return 0 }
            return last.activePlayers == 2 ? 1.0 : 0.0
        }
    }
}

struct BoardTextureAnalysis {
    let type: BoardTextureType
    let wetness: Double
    let connectivity: Double
    let hasPair: Bool
    let hasFlushDraw: Bool
    let hasStraightDraw: Bool
    let highCards: Int
    
    var isDry: Bool {
        return wetness < 0.4
    }
    
    var isWet: Bool {
        return wetness > 0.6
    }
}

enum CommitmentLevel {
    case uncommitted
    case partial
    case invested
    case committed
    
    var description: String {
        switch self {
        case .uncommitted: return "未投入"
        case .partial: return "部分投入"
        case .invested: return "已投入"
        case .committed: return "已套牢"
        }
    }
}

struct ActionSequenceAnalysis {
    let isAggressive: Bool
    let isPassive: Bool
    let hasRaiseWar: Bool
    let actionCount: Int
    let avgBetSize: Int
}

class HandCategoryClassifier {
    static let shared = HandCategoryClassifier()
    
    private init() {}
    
    func classifyHand(holeCards: [Card], communityCards: [Card]) -> HandClassification {
        guard communityCards.count >= 3 else {
            return classifyPreFlop(holeCards: holeCards)
        }
        
        let eval = HandEvaluator.evaluate(holeCards: holeCards, communityCards: communityCards)
        
        switch eval.0 {
        case 9:
            return HandClassification(category: .royalFlush, strength: 1.0, description: "皇家同花顺")
        case 8:
            return HandClassification(category: .straightFlush, strength: 0.95, description: "同花顺")
        case 7:
            return HandClassification(category: .fourOfAKind, strength: 0.9, description: "四条")
        case 6:
            return HandClassification(category: .fullHouse, strength: 0.85, description: "葫芦")
        case 5:
            return HandClassification(category: .flush, strength: 0.8, description: "同花")
        case 4:
            return HandClassification(category: .straight, strength: 0.75, description: "顺子")
        case 3:
            return HandClassification(category: .threeOfAKind, strength: 0.65, description: "三条")
        case 2:
            return HandClassification(category: .twoPair, strength: 0.5, description: "两对")
        case 1:
            return classifyOnePair(holeCards: holeCards, communityCards: communityCards)
        default:
            return classifyHighCard(holeCards: holeCards, communityCards: communityCards)
        }
    }
    
    private func classifyPreFlop(holeCards: [Card]) -> HandClassification {
        guard holeCards.count == 2 else {
            return HandClassification(category: .unknown, strength: 0, description: "未知")
        }
        
        let isPair = holeCards[0].rank == holeCards[1].rank
        let isSuited = holeCards[0].suit == holeCards[1].suit
        let high = max(holeCards[0].rank.rawValue, holeCards[1].rank.rawValue)
        let low = min(holeCards[0].rank.rawValue, holeCards[1].rank.rawValue)
        
        if isPair {
            if high >= 11 {
                return HandClassification(category: .premium, strength: 0.9, description: "高对")
            } else if high >= 9 {
                return HandClassification(category: .strong, strength: 0.75, description: "中对")
            }
            return HandClassification(category: .pair, strength: 0.6, description: "小对")
        }
        
        if high >= 12 && isSuited {
            return HandClassification(category: .strong, strength: 0.8, description: "同花AK")
        }
        
        if high >= 11 && low >= 10 {
            return HandClassification(category: .strong, strength: 0.7, description: "AKo")
        }
        
        if isSuited && high >= 10 {
            return HandClassification(category: .suitedConnector, strength: 0.55, description: "同花连牌")
        }
        
        return HandClassification(category: .weak, strength: 0.3, description: "弱牌")
    }
    
    private func classifyOnePair(holeCards: [Card], communityCards: [Card]) -> HandClassification {
        let holeRank = holeCards[0].rank == holeCards[1].rank ? holeCards[0].rank : holeCards[0].rank
        let communityRanks = communityCards.map { $0.rank }
        
        let isTopPair = communityRanks.contains(holeRank)
        let isOverpair = holeCards[0].rank.rawValue > (communityRanks.max()?.rawValue ?? 0)
        
        if isTopPair && holeRank.rawValue >= 11 {
            return HandClassification(category: .topPair, strength: 0.7, description: "顶对顶踢")
        } else if isTopPair {
            return HandClassification(category: .topPair, strength: 0.6, description: "顶对")
        } else if isOverpair {
            return HandClassification(category: .overpair, strength: 0.55, description: "超对")
        } else if holeRank.rawValue >= 10 {
            return HandClassification(category: .middlePair, strength: 0.45, description: "中对")
        }
        
        return HandClassification(category: .weakPair, strength: 0.3, description: "弱对")
    }
    
    private func classifyHighCard(holeCards: [Card], communityCards: [Card]) -> HandClassification {
        let highCard = max(holeCards[0].rank.rawValue, holeCards[1].rank.rawValue)
        let isSuited = holeCards[0].suit == holeCards[1].suit
        
        if highCard >= 12 && isSuited {
            return HandClassification(category: .aceSuited, strength: 0.4, description: "A高同花")
        } else if highCard >= 12 {
            return HandClassification(category: .aceHigh, strength: 0.35, description: "A高牌")
        }
        
        return HandClassification(category: .trash, strength: 0.1, description: "垃圾牌")
    }
}

enum GameHandCategory {
    case royalFlush
    case straightFlush
    case fourOfAKind
    case fullHouse
    case flush
    case straight
    case threeOfAKind
    case twoPair
    case onePair
    case highCard
    case premium
    case strong
    case suitedConnector
    case pair
    case topPair
    case overpair
    case middlePair
    case weakPair
    case aceSuited
    case aceHigh
    case weak
    case trash
    case unknown
}

struct HandClassification {
    let category: GameHandCategory
    let strength: Double
    let description: String
    
    var isStrong: Bool {
        return strength > 0.6
    }
    
    var isDraw: Bool {
        return false
    }
}
