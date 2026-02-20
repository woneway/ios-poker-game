import Foundation

struct HandCategory: Equatable {
    let topPairs: Double
    let middlePairs: Double
    let bottomPairs: Double
    let overpairs: Double
    let draws: Double
    let air: Double
    
    var totalValue: Double {
        topPairs + middlePairs + overpairs
    }
    
    var totalDraws: Double {
        draws
    }
}

struct RangeEquity {
    let valueRange: Double
    let drawRange: Double
    let airRange: Double
    let totalEquity: Double
    
    var isPolarized: Bool {
        return valueRange > 0.6 && airRange > 0.2
    }
}

class HandRangeOptimizer {
    static let shared = HandRangeOptimizer()
    
    private init() {}
    
    func calculateRangeEquity(
        holeCards: [Card],
        communityCards: [Card],
        opponentRange: HandRange,
        iterations: Int = 500
    ) -> RangeEquity {
        let playerEquity = MonteCarloSimulator.calculateEquity(
            holeCards: holeCards,
            communityCards: communityCards,
            playerCount: 2,
            iterations: iterations
        )
        
        let baseEquity = playerEquity * opponentRange.rangeWidth
        
        let valueRatio = min(baseEquity * 1.5, 0.7)
        let drawRatio = calculateDrawRatio(communityCards: communityCards)
        let airRatio = max(0, 1.0 - valueRatio - drawRatio)
        
        let adjustedValue = valueRatio * opponentRange.rangeWidth
        let adjustedDraws = drawRatio * opponentRange.rangeWidth
        let adjustedAir = airRatio * opponentRange.rangeWidth
        
        return RangeEquity(
            valueRange: adjustedValue,
            drawRange: adjustedDraws,
            airRange: adjustedAir,
            totalEquity: adjustedValue + adjustedDraws * 0.3
        )
    }
    
    private func calculateDrawRatio(communityCards: [Card]) -> Double {
        guard communityCards.count >= 3 else { return 0 }
        
        var suitedCount = 0
        var connectedCount = 0
        
        let ranks = communityCards.map { $0.rank.rawValue }.sorted()
        let suits = communityCards.map { $0.suit }
        
        for i in 0..<suits.count {
            for j in (i+1)..<suits.count {
                if suits[i] == suits[j] {
                    suitedCount += 1
                }
            }
        }
        
        for i in 0..<ranks.count - 1 {
            if ranks[i+1] - ranks[i] <= 3 {
                connectedCount += 1
            }
        }
        
        let wetness = Double(suitedCount + connectedCount) / Double(communityCards.count * communityCards.count)
        
        return min(wetness * 0.8, 0.4)
    }
    
    func estimateCallRange(
        potOdds: Double,
        boardTexture: GameBoardTexture,
        position: TablePosition,
        street: Street
    ) -> Double {
        var baseCallRange: Double
        
        switch street {
        case .flop:
            baseCallRange = 0.35
        case .turn:
            baseCallRange = 0.30
        case .river:
            baseCallRange = 0.25
        default:
            baseCallRange = 0.40
        }
        
        let positionMultiplier: Double
        switch position {
        case .btn, .co:
            positionMultiplier = 1.1
        case .sb, .bb:
            positionMultiplier = 0.9
        default:
            positionMultiplier = 1.0
        }
        
        let oddsMultiplier = 1.0 + (potOdds * 0.5)
        
        var adjustedRange = baseCallRange * positionMultiplier * oddsMultiplier
        
        if boardTexture == .wet {
            adjustedRange *= 0.85
        } else if boardTexture == .dry {
            adjustedRange *= 1.1
        }
        
        return min(max(adjustedRange, 0.05), 0.60)
    }
    
    func estimateValueBetRange(
        handStrength: Double,
        boardTexture: GameBoardTexture,
        potSize: Int,
        stackSize: Int
    ) -> Bool {
        let spr = StackPotRatioCalculator.shared.calculateSPR(stackSize: stackSize, potSize: potSize)
        
        if handStrength > 0.85 {
            return true
        }
        
        if handStrength > 0.7 && boardTexture != .wet {
            return true
        }
        
        if handStrength > 0.6 && spr < 5 {
            return true
        }
        
        if handStrength > 0.5 && boardTexture == .dry && spr < 3 {
            return true
        }
        
        return false
    }
    
    func shouldBluffReraise(
        equity: Double,
        potSize: Int,
        callAmount: Int,
        opponentTendency: PlayerTendency,
        boardTexture: GameBoardTexture
    ) -> Bool {
        let potOdds = Double(callAmount) / Double(potSize + callAmount)
        
        let foldEquity = calculateFoldEquity(opponentTendency: opponentTendency)
        
        let bluffEV = (foldEquity * Double(potSize)) - ((1 - foldEquity) * Double(callAmount) * (1 - equity))
        
        let isWetBoard = boardTexture == .wet
        
        if isWetBoard && equity < 0.3 {
            return false
        }
        
        if equity > potOdds * 1.5 {
            return true
        }
        
        return bluffEV > 0 && equity > 0.25
    }
    
    private func calculateFoldEquity(opponentTendency: PlayerTendency) -> Double {
        switch opponentTendency {
        case .nit:
            return 0.75
        case .tag:
            return 0.55
        case .abc:
            return 0.45
        case .lag:
            return 0.30
        case .callingStation:
            return 0.15
        case .lpp:
            return 0.35
        case .unknown:
            return 0.45
        }
    }
}

class OptimalBetSizing {
    static let shared = OptimalBetSizing()
    
    private init() {}
    
    func calculateValueBetSize(
        potSize: Int,
        handStrength: Double,
        boardTexture: GameBoardTexture,
        opponentTendency: PlayerTendency
    ) -> Int {
        let basePercent: Double
        
        if handStrength > 0.85 {
            basePercent = 0.75
        } else if handStrength > 0.7 {
            basePercent = 0.60
        } else {
            basePercent = 0.45
        }
        
        var adjusted = basePercent
        
        switch opponentTendency {
        case .nit:
            adjusted *= 1.15
        case .callingStation:
            adjusted *= 1.25
        case .lag:
            adjusted *= 0.90
        default:
            break
        }
        
        if boardTexture == .dry {
            adjusted *= 0.85
        } else if boardTexture == .wet {
            adjusted *= 1.1
        }
        
        return max(Int(Double(potSize) * adjusted), potSize / 4)
    }
    
    func calculateBluffSize(
        potSize: Int,
        boardTexture: GameBoardTexture,
        street: Street
    ) -> Int {
        let basePercent: Double
        
        switch street {
        case .flop:
            basePercent = 0.40
        case .turn:
            basePercent = 0.55
        case .river:
            basePercent = 0.70
        default:
            basePercent = 0.33
        }
        
        if boardTexture == .dry {
            return max(potSize / 3, 1)
        }
        
        return max(Int(Double(potSize) * basePercent), potSize / 4)
    }
    
    func calculateProtectionBet(
        potSize: Int,
        handStrength: Double,
        drawsExist: Bool
    ) -> Int {
        guard drawsExist else {
            return 0
        }
        
        if handStrength > 0.8 {
            return 0
        }
        
        let protectionSize: Double
        if handStrength > 0.6 {
            protectionSize = 0.33
        } else {
            protectionSize = 0.50
        }
        
        return max(Int(Double(potSize) * protectionSize), potSize / 4)
    }
}
