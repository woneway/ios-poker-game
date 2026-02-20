import Foundation

enum TablePosition: Int, CaseIterable {
    case utg = 0      // UTG (Under the Gun)
    case utg1 = 1     // UTG+1
    case mp = 2       // MP (Middle Position)
    case hj = 3       // Hijack
    case co = 4       // Cutoff
    case btn = 5       // Button
    case sb = 6        // Small Blind
    case bb = 7        // Big Blind
    
    var name: String {
        switch self {
        case .utg: return "UTG"
        case .utg1: return "UTG+1"
        case .mp: return "MP"
        case .hj: return "HJ"
        case .co: return "CO"
        case .btn: return "BTN"
        case .sb: return "SB"
        case .bb: return "BB"
        }
    }
    
    var positionalAdvantage: Double {
        switch self {
        case .btn: return 1.0
        case .co: return 0.85
        case .hj: return 0.7
        case .mp: return 0.5
        case .utg1: return 0.35
        case .utg: return 0.25
        case .sb: return 0.3
        case .bb: return 0.4
        }
    }
    
    var stealability: Double {
        switch self {
        case .btn: return 1.0
        case .co: return 0.9
        case .hj: return 0.7
        case .sb: return 0.6
        default: return 0.0
        }
    }
}

struct PositionStrategy {
    let openRaiseRange: Double
    let threeBetRange: Double
    let fourBetRange: Double
    let callOpenRange: Double
    let squeezeRange: Double
    
    static let utg = PositionStrategy(
        openRaiseRange: 0.15,
        threeBetRange: 0.08,
        fourBetRange: 0.03,
        callOpenRange: 0.10,
        squeezeRange: 0.05
    )
    
    static let mp = PositionStrategy(
        openRaiseRange: 0.20,
        threeBetRange: 0.10,
        fourBetRange: 0.04,
        callOpenRange: 0.12,
        squeezeRange: 0.07
    )
    
    static let hijack = PositionStrategy(
        openRaiseRange: 0.28,
        threeBetRange: 0.12,
        fourBetRange: 0.05,
        callOpenRange: 0.15,
        squeezeRange: 0.10
    )
    
    static let cutoff = PositionStrategy(
        openRaiseRange: 0.35,
        threeBetRange: 0.15,
        fourBetRange: 0.06,
        callOpenRange: 0.18,
        squeezeRange: 0.12
    )
    
    static let button = PositionStrategy(
        openRaiseRange: 0.45,
        threeBetRange: 0.18,
        fourBetRange: 0.08,
        callOpenRange: 0.20,
        squeezeRange: 0.15
    )
    
    static let sb = PositionStrategy(
        openRaiseRange: 0.25,
        threeBetRange: 0.12,
        fourBetRange: 0.04,
        callOpenRange: 0.08,
        squeezeRange: 0.15
    )
    
    static let bb = PositionStrategy(
        openRaiseRange: 0.30,
        threeBetRange: 0.15,
        fourBetRange: 0.06,
        callOpenRange: 0.15,
        squeezeRange: 0.10
    )
    
    static func forPosition(_ position: TablePosition) -> PositionStrategy {
        switch position {
        case .utg, .utg1: return .utg
        case .mp: return .mp
        case .hj: return .hijack
        case .co: return .cutoff
        case .btn: return .button
        case .sb: return .sb
        case .bb: return .bb
        }
    }
}

class PositionStrategyManager {
    static let shared = PositionStrategyManager()
    
    private var positionAdjustments: [String: PositionStrategy] = [:]
    
    private init() {}
    
    func getStrategy(for playerId: String, position: TablePosition) -> PositionStrategy {
        if let custom = positionAdjustments[playerId] {
            return custom
        }
        return PositionStrategy.forPosition(position)
    }
    
    func adjustStrategy(for playerId: String, basedOn results: [HandResult]) {
        guard results.count >= 10 else { return }
        
        let winRate = Double(results.filter { $0 == .win }.count) / Double(results.count)
        
        var adjusted = positionAdjustments[playerId] ?? PositionStrategy.forPosition(.btn)
        
        if winRate > 0.6 {
            adjusted = PositionStrategy(
                openRaiseRange: adjusted.openRaiseRange * 1.2,
                threeBetRange: adjusted.threeBetRange * 1.15,
                fourBetRange: adjusted.fourBetRange * 1.1,
                callOpenRange: adjusted.callOpenRange * 0.9,
                squeezeRange: adjusted.squeezeRange * 1.2
            )
        } else if winRate < 0.4 {
            adjusted = PositionStrategy(
                openRaiseRange: adjusted.openRaiseRange * 0.8,
                threeBetRange: adjusted.threeBetRange * 0.85,
                fourBetRange: adjusted.fourBetRange * 0.9,
                callOpenRange: adjusted.callOpenRange * 1.2,
                squeezeRange: adjusted.squeezeRange * 0.7
            )
        }
        
        positionAdjustments[playerId] = adjusted
    }
    
    func reset(for playerId: String) {
        positionAdjustments.removeValue(forKey: playerId)
    }
}

class MultiwayPotOptimizer {
    static let shared = MultiwayPotOptimizer()
    
    private init() {}
    
    func calculateEquityRequirement(
        playersRemaining: Int,
        potOdds: Double,
        position: TablePosition
    ) -> Double {
        let baseEquity = 1.0 / Double(playersRemaining)
        
        var adjusted = baseEquity
        
        switch playersRemaining {
        case 2:
            adjusted *= 1.0
        case 3:
            adjusted *= 1.15
        case 4:
            adjusted *= 1.25
        default:
            adjusted *= 1.3
        }
        
        if position == .bb {
            adjusted *= 0.9
        }
        
        return min(adjusted + potOdds * 0.5, 0.8)
    }
    
    func shouldCbetMultiway(
        equity: Double,
        potSize: Int,
        playersCount: Int,
        boardTexture: GameBoardTexture
    ) -> Bool {
        let threshold = 0.35 + Double(playersCount - 2) * 0.1
        
        if boardTexture == .dry && equity > threshold {
            return true
        }
        
        if boardTexture == .wet && equity > threshold + 0.15 {
            return true
        }
        
        return false
    }
    
    func adjustValueBetSizing(
        baseSize: Int,
        playersRemaining: Int,
        equity: Double
    ) -> Int {
        var multiplier = 1.0
        
        switch playersRemaining {
        case 3:
            multiplier = 0.9
        case 4:
            multiplier = 0.85
        default:
            multiplier = 1.0
        }
        
        if equity > 0.8 {
            multiplier *= 1.1
        }
        
        return Int(Double(baseSize) * multiplier)
    }
}

class ShortStackStrategy {
    static let shared = ShortStackStrategy()
    
    private init() {}
    
    func shouldPushAllIn(
        stackSize: Int,
        bigBlind: Int,
        equity: Double,
        position: TablePosition,
        playersToAct: Int
    ) -> Bool {
        let stackToBB = Double(stackSize) / Double(bigBlind)
        
        if stackToBB < 3 {
            return equity > 0.4
        }
        
        if stackToBB < 10 {
            let pushThreshold = calculatePushThreshold(
                stackToBB: stackToBB,
                position: position,
                playersToAct: playersToAct
            )
            return equity > pushThreshold
        }
        
        return false
    }
    
    private func calculatePushThreshold(stackToBB: Double, position: TablePosition, playersToAct: Int) -> Double {
        var threshold = 0.5
        
        threshold -= Double(playersToAct) * 0.05
        
        switch position {
        case .btn, .co:
            threshold -= 0.05
        case .sb, .bb:
            threshold -= 0.03
        case .utg, .utg1:
            threshold += 0.05
        default:
            break
        }
        
        if stackToBB < 5 {
            threshold -= 0.1
        }
        
        return max(threshold, 0.3)
    }
    
    func calculateMinRaise(
        stackSize: Int,
        potSize: Int,
        bigBlind: Int
    ) -> Int {
        let minLegal = max(bigBlind, potSize / 4)
        
        if stackSize < minLegal * 3 {
            return stackSize
        }
        
        return minLegal
    }
}
