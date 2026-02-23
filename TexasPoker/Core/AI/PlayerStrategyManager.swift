import Foundation

enum StrategyType: String, Codable {
    case tight = "紧"
    case loose = "松"
    case aggressive = "激进"
    case passive = "被动"
    case balanced = "平衡"
    case exploit = "剥削"
    
    var description: String { rawValue }
}

class PlayerStrategyManager {
    static let shared = PlayerStrategyManager()
    
    private var playerStrategies: [String: PlayerStrategy] = [:]
    private var playerTiltLevels: [String: Double] = [:]
    private var handHistory: [String: [HandRecord]] = [:]
    private let queue = DispatchQueue(label: "com.poker.strategy", attributes: .concurrent)
    
    private init() {}
    
    struct HandRecord: Codable {
        let id: UUID
        let timestamp: Date
        let position: Int
        let holeCards: [Card]
        let communityCards: [Card]
        let actions: [String]
        let profit: Int
        let won: Bool
    }
    
    struct PlayerStrategy: Codable {
        var type: StrategyType
        var openRange: [String]
        var threeBetRange: [String]
        var callRange: [String]
        var foldTo3Bet: Double
        var cBetFrequency: Double
        var donkBetFrequency: Double
        var checkRaiseFrequency: Double
        var bluffFrequency: Double
        var tiltAdjustment: Double
        var positionAdjustments: [Int: Double]
        var streetStrategy: StreetStrategy
        
        struct StreetStrategy: Codable {
            var flopBetFrequency: Double
            var turnBetFrequency: Double
            var riverBetFrequency: Double
            var doubleBarrelChance: Double
            var tripleBarrelChance: Double
        }
        
        static func defaultStrategy() -> PlayerStrategy {
            return PlayerStrategy(
                type: .balanced,
                openRange: [],
                threeBetRange: [],
                callRange: [],
                foldTo3Bet: 0.4,
                cBetFrequency: 0.6,
                donkBetFrequency: 0.2,
                checkRaiseFrequency: 0.15,
                bluffFrequency: 0.25,
                tiltAdjustment: 1.0,
                positionAdjustments: [0: 0.9, 1: 1.0, 2: 1.1, 3: 1.2],
                streetStrategy: StreetStrategy(
                    flopBetFrequency: 0.65,
                    turnBetFrequency: 0.5,
                    riverBetFrequency: 0.4,
                    doubleBarrelChance: 0.35,
                    tripleBarrelChance: 0.15
                )
            )
        }
        
        static func tightStrategy() -> PlayerStrategy {
            var strategy = defaultStrategy()
            strategy.type = .tight
            strategy.bluffFrequency = 0.15
            strategy.cBetFrequency = 0.75
            return strategy
        }
        
        static func looseStrategy() -> PlayerStrategy {
            var strategy = defaultStrategy()
            strategy.type = .loose
            strategy.bluffFrequency = 0.35
            strategy.cBetFrequency = 0.5
            return strategy
        }
        
        static func aggressiveStrategy() -> PlayerStrategy {
            var strategy = defaultStrategy()
            strategy.type = .aggressive
            strategy.bluffFrequency = 0.35
            strategy.cBetFrequency = 0.7
            strategy.checkRaiseFrequency = 0.25
            return strategy
        }
        
        static func passiveStrategy() -> PlayerStrategy {
            var strategy = defaultStrategy()
            strategy.type = .passive
            strategy.bluffFrequency = 0.15
            strategy.cBetFrequency = 0.4
            return strategy
        }
    }
    
    func setStrategy(for playerId: String, strategy: PlayerStrategy) {
        queue.async(flags: .barrier) {
            self.playerStrategies[playerId] = strategy
        }
    }
    
    func getStrategy(for playerId: String) -> PlayerStrategy {
        return queue.sync {
            return playerStrategies[playerId] ?? PlayerStrategy.defaultStrategy()
        }
    }
    
    func recordHand(for playerId: String, hand: HandRecord) {
        queue.async(flags: .barrier) {
            self.handHistory[playerId, default: []].append(hand)
            if self.handHistory[playerId]?.count ?? 0 > 100 {
                self.handHistory[playerId]?.removeFirst(10)
            }
            self.updateTiltLevel(playerId: playerId)
        }
    }
    
    private func updateTiltLevel(playerId: String) {
        guard let hands = handHistory[playerId], hands.count >= 5 else {
            playerTiltLevels[playerId] = 1.0
            return
        }
        
        let recentHands = Array(hands.suffix(10))
        let losingStreak = recentHands.filter { $0.profit < 0 }.count
        let totalProfit = recentHands.reduce(0) { $0 + $1.profit }
        
        var tiltMultiplier = 1.0
        if losingStreak >= 5 {
            tiltMultiplier = 1.3
        } else if losingStreak >= 3 && totalProfit < -500 {
            tiltMultiplier = 1.2
        } else if totalProfit > 500 {
            tiltMultiplier = 0.9
        }
        
        playerTiltLevels[playerId] = tiltMultiplier
    }
    
    func getTiltLevel(for playerId: String) -> Double {
        return queue.sync {
            return playerTiltLevels[playerId] ?? 1.0
        }
    }
    
    func adaptStrategy(for playerId: String, basedOn opponentStats: OpponentStats) {
        queue.async(flags: .barrier) {
            var strategy = self.playerStrategies[playerId] ?? PlayerStrategy.defaultStrategy()
            
            if opponentStats.vpip > 0.4 {
                strategy.type = .loose
                strategy.bluffFrequency *= 1.3
            } else if opponentStats.vpip < 0.2 {
                strategy.type = .tight
                strategy.bluffFrequency *= 0.8
            }
            
            if opponentStats.pfr > 0.15 {
                strategy.foldTo3Bet *= 1.2
            }
            
            if opponentStats.cBet > 0.7 {
                strategy.checkRaiseFrequency *= 1.3
            }
            
            self.playerStrategies[playerId] = strategy
        }
    }
    
    func getRecommendedAction(
        for playerId: String,
        situation: ActionSituation
    ) -> RecommendedAction {
        let strategy = getStrategy(for: playerId)
        let tiltMultiplier = getTiltLevel(for: playerId)
        
        switch situation.actionType {
        case .preflopOpen:
            return evaluatePreflopOpen(strategy: strategy, situation: situation, tiltMultiplier: tiltMultiplier)
        case .facing3Bet:
            return evaluateFacing3Bet(strategy: strategy, situation: situation, tiltMultiplier: tiltMultiplier)
        case .facingBet:
            return evaluateFacingBet(strategy: strategy, situation: situation)
        case .decisionToBet:
            return evaluateBetDecision(strategy: strategy, situation: situation, tiltMultiplier: tiltMultiplier)
        case .postFlopAction:
            return evaluatePostFlopAction(strategy: strategy, situation: situation)
        }
    }
    
    private func evaluatePreflopOpen(strategy: PlayerStrategy, situation: ActionSituation, tiltMultiplier: Double) -> RecommendedAction {
        let handStrength = situation.handStrength ?? 0.5
        let positionAdjustment = strategy.positionAdjustments[situation.position] ?? 1.0
        let adjustedStrength = handStrength * positionAdjustment * tiltMultiplier
        
        let shouldOpen: Bool
        let size: Int
        
        if adjustedStrength > 0.7 {
            shouldOpen = true
            size = situation.potSize
        } else if adjustedStrength > 0.5 {
            shouldOpen = Double.random(in: 0...1) < strategy.bluffFrequency
            size = situation.potSize * 3 / 4
        } else {
            shouldOpen = false
            size = 0
        }
        
        return RecommendedAction(
            action: shouldOpen ? .raise(size) : .fold,
            confidence: abs(adjustedStrength - 0.5) * 2,
            reasoning: "基于策略类型: \(strategy.type.rawValue), 位置调整: \(String(format: "%.1f", positionAdjustment))"
        )
    }
    
    private func evaluateFacing3Bet(strategy: PlayerStrategy, situation: ActionSituation, tiltMultiplier: Double) -> RecommendedAction {
        let handStrength = situation.handStrength ?? 0.5
        let adjustedStrength = handStrength * tiltMultiplier
        
        if adjustedStrength > 0.6 {
            return RecommendedAction(
                action: .raise(situation.potSize * 3),
                confidence: adjustedStrength,
                reasoning: "强牌应对3-bet"
            )
        } else if adjustedStrength > strategy.foldTo3Bet {
            return RecommendedAction(
                action: .call,
                confidence: 0.7,
                reasoning: "中等牌力选择跟注"
            )
        } else {
            return RecommendedAction(
                action: .fold,
                confidence: 1 - adjustedStrength,
                reasoning: "弃牌避免损失"
            )
        }
    }
    
    private func evaluateFacingBet(strategy: PlayerStrategy, situation: ActionSituation) -> RecommendedAction {
        let handStrength = situation.handStrength ?? 0.5
        let potOdds = Double(situation.toCall) / Double(situation.potSize + situation.toCall)
        
        if handStrength > potOdds + 0.1 {
            return RecommendedAction(
                action: .call,
                confidence: handStrength,
                reasoning: "赔率支持跟注"
            )
        } else {
            return RecommendedAction(
                action: .fold,
                confidence: potOdds - handStrength + 0.5,
                reasoning: "赔率不足"
            )
        }
    }
    
    private func evaluateBetDecision(strategy: PlayerStrategy, situation: ActionSituation, tiltMultiplier: Double) -> RecommendedAction {
        let handStrength = situation.handStrength ?? 0.5
        let adjustedStrength = handStrength * tiltMultiplier
        let shouldBet: Bool
        let size: Int
        
        if adjustedStrength > 0.7 {
            shouldBet = true
            size = Int(Double(situation.potSize) * (0.6 + strategy.bluffFrequency * 0.2))
        } else if adjustedStrength > 0.4 {
            shouldBet = Double.random(in: 0...1) < strategy.cBetFrequency
            size = situation.potSize / 2
        } else {
            shouldBet = Double.random(in: 0...1) < strategy.bluffFrequency
            size = situation.potSize / 3
        }
        
        return RecommendedAction(
            action: shouldBet ? .raise(size) : .check,
            confidence: abs(adjustedStrength - 0.5) * 2,
            reasoning: "C-bet频率: \(Int(strategy.cBetFrequency*100))%"
        )
    }
    
    private func evaluatePostFlopAction(strategy: PlayerStrategy, situation: ActionSituation) -> RecommendedAction {
        let handStrength = situation.handStrength ?? 0.5
        let street = situation.street ?? .flop
        
        let betFrequency: Double
        switch street {
        case .flop:
            betFrequency = strategy.streetStrategy.flopBetFrequency
        case .turn:
            betFrequency = strategy.streetStrategy.turnBetFrequency
        case .river:
            betFrequency = strategy.streetStrategy.riverBetFrequency
        }
        
        let shouldBet = handStrength > 0.5 && Double.random(in: 0...1) < betFrequency
        let size = situation.potSize / 2
        
        return RecommendedAction(
            action: shouldBet ? .raise(size) : .check,
            confidence: abs(handStrength - 0.5) * 2,
            reasoning: "\(street.rawValue)圈下注频率: \(Int(betFrequency*100))%"
        )
    }
    
    func getPositionName(for position: Int) -> String {
        switch position {
        case 0: return "SB"
        case 1: return "BB"
        case 2: return "UTG"
        case 3: return "UTG+1"
        case 4: return "MP"
        case 5: return "CO"
        case 6: return "BTN"
        default: return "位置\(position)"
        }
    }
}

struct ActionSituation {
    let actionType: ActionSituationType
    let handStrength: Double?
    let position: Int
    let potSize: Int
    let toCall: Int
    let stackSize: Int
    let boardCards: [Card]
    let street: Street?
    
    enum ActionSituationType {
        case preflopOpen
        case facing3Bet
        case facingBet
        case decisionToBet
        case postFlopAction
    }
    
    enum Street: String, Codable {
        case flop = "翻牌"
        case turn = "转牌"
        case river = "河牌"
    }
}

struct OpponentStats {
    let vpip: Double
    let pfr: Double
    let threeBet: Double
    let cBet: Double
    let wtsd: Double
}

struct RecommendedAction {
    let action: PlayerAction
    let confidence: Double
    let reasoning: String
}
