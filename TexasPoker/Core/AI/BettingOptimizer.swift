import Foundation

struct BettingStrategy {
    let minBet: Int
    let maxBet: Int
    let optimalPercentile: Double
    let isPolarized: Bool
    
    static let standard = BettingStrategy(
        minBet: 0,
        maxBet: 0,
        optimalPercentile: 0.66,
        isPolarized: false
    )
    
    static let smallBall = BettingStrategy(
        minBet: 0,
        maxBet: 0,
        optimalPercentile: 0.5,
        isPolarized: false
    )
    
    static let largeBetting = BettingStrategy(
        minBet: 0,
        maxBet: 0,
        optimalPercentile: 0.75,
        isPolarized: true
    )
}

class BetSizingOptimizer {
    static let shared = BetSizingOptimizer()
    
    private let decisionCache = AIDecisionCache()
    
    private init() {}
    
    func calculateOptimalBetSize(
        potSize: Int,
        effectiveStack: Int,
        equity: Double,
        boardTexture: GameBoardTexture,
        opponentType: PlayerTendency,
        isValueBet: Bool
    ) -> Int {
        let basePercent = calculateBasePercent(equity: equity, boardTexture: boardTexture)
        
        var adjustedPercent = applyOpponentAdjustment(
            basePercent: basePercent,
            opponentType: opponentType,
            isValueBet: isValueBet
        )
        
        adjustedPercent = applyStackDepthAdjustment(
            percent: adjustedPercent,
            effectiveStack: effectiveStack,
            potSize: potSize
        )
        
        let betSize = Int(Double(potSize) * adjustedPercent)
        
        return max(betSize, calculateMinBet(potSize: potSize))
    }
    
    private func calculateBasePercent(equity: Double, boardTexture: GameBoardTexture) -> Double {
        switch boardTexture {
        case .dry:
            return min(equity * 1.2, 0.8)
        case .wet:
            return equity * 0.9
        case .paired:
            return equity * 0.85
        case .rainbow:
            return equity
        }
    }
    
    private func applyOpponentAdjustment(basePercent: Double, opponentType: PlayerTendency, isValueBet: Bool) -> Double {
        switch opponentType {
        case .callingStation:
            if isValueBet { return basePercent * 1.2 }
            return basePercent * 0.7
        case .nit:
            return basePercent * 1.1
        case .lag:
            if isValueBet { return basePercent * 0.9 }
            return basePercent * 1.15
        default:
            return basePercent
        }
    }
    
    private func applyStackDepthAdjustment(percent: Double, effectiveStack: Int, potSize: Int) -> Double {
        let stackToPotRatio = Double(effectiveStack) / Double(max(potSize, 1))
        
        if stackToPotRatio < 3 {
            return percent * 0.8
        } else if stackToPotRatio > 20 {
            return percent * 1.1
        }
        
        return percent
    }
    
    private func calculateMinBet(potSize: Int) -> Int {
        return max(potSize / 4, 10)
    }
    
    func calculateThreeBarrelProbability(
        boardTexture: GameBoardTexture,
        opponentType: PlayerTendency,
        street: Street
    ) -> Double {
        var probability = 0.3
        
        switch street {
        case .flop:
            probability = 0.4
        case .turn:
            probability = 0.35
        case .river:
            probability = 0.25
        default:
            probability = 0
        }
        
        switch opponentType {
        case .nit:
            probability *= 0.5
        case .lag:
            probability *= 1.3
        case .callingStation:
            probability *= 0.3
        default:
            break
        }
        
        if boardTexture == .dry {
            probability *= 1.2
        } else if boardTexture == .wet {
            probability *= 0.7
        }
        
        return min(probability, 0.6)
    }
}

class BluffingOptimizer {
    static let shared = BluffingOptimizer()
    
    private init() {}
    
    func shouldBluff(
        equity: Double,
        potSize: Int,
        opponentStack: Int,
        boardTexture: GameBoardTexture,
        street: Street,
        opponentTendency: PlayerTendency
    ) -> Bool {
        let foldEquity = calculateFoldEquity(opponentTendency: opponentTendency)
        
        let bluffEV = calculateBluffEV(
            equity: equity,
            foldEquity: foldEquity,
            potSize: potSize
        )
        
        let riskRewardRatio = calculateRiskReward(
            potSize: potSize,
            opponentStack: opponentStack
        )
        
        return bluffEV > 0 && riskRewardRatio < 3.0
    }
    
    private func calculateFoldEquity(opponentTendency: PlayerTendency) -> Double {
        switch opponentTendency {
        case .nit: return 0.7
        case .tag: return 0.5
        case .lag: return 0.3
        case .callingStation: return 0.1
        case .lpp: return 0.2
        case .abc: return 0.4
        case .unknown: return 0.4
        }
    }
    
    private func calculateBluffEV(equity: Double, foldEquity: Double, potSize: Int) -> Double {
        let winIfCalled = Double(potSize) * equity - Double(potSize / 2) * (1 - equity)
        let winIfFolded = Double(potSize) * foldEquity
        let loseIfCalled = Double(potSize / 2) * (1 - equity) * (1 - foldEquity)
        
        return winIfCalled + winIfFolded - loseIfCalled
    }
    
    private func calculateRiskReward(potSize: Int, opponentStack: Int) -> Double {
        guard potSize > 0 else { return 0 }
        return Double(opponentStack) / Double(potSize)
    }
}

class HeroCallOptimizer {
    static let shared = HeroCallOptimizer()
    
    private init() {}
    
    func shouldCall(
        potOdds: Double,
        equity: Double,
        impliedOdds: Double,
        opponentTendency: PlayerTendency,
        betSize: Int,
        stackBehind: Int
    ) -> Bool {
        let effectiveOdds = potOdds + impliedOdds
        
        guard equity > effectiveOdds else { return false }
        
        let margin = equity - effectiveOdds
        
        let confidenceThreshold = calculateConfidenceThreshold(
            opponentTendency: opponentTendency,
            betSize: betSize,
            stackBehind: stackBehind
        )
        
        return margin > confidenceThreshold
    }
    
    private func calculateConfidenceThreshold(opponentTendency: PlayerTendency, betSize: Int, stackBehind: Int) -> Double {
        var threshold = 0.05
        
        if stackBehind < betSize * 3 {
            threshold *= 1.5
        }
        
        switch opponentTendency {
        case .lag:
            threshold *= 0.8
        case .callingStation:
            threshold *= 0.6
        case .nit:
            threshold *= 1.2
        default:
            break
        }
        
        return threshold
    }
}
