import Foundation

enum GTOAction {
    case check
    case bet33
    case bet50
    case bet66
    case bet75
    case bet100
    case allIn
    case fold
    
    var potMultiplier: Double {
        switch self {
        case .check, .fold: return 0
        case .bet33: return 0.33
        case .bet50: return 0.50
        case .bet66: return 0.66
        case .bet75: return 0.75
        case .bet100: return 1.0
        case .allIn: return 10.0
        }
    }
}

struct GTODecision {
    let action: GTOAction
    let frequency: Double
    let reason: String
    let minimumDefenseFrequency: Double
    let valueRatio: Double
    let bluffRatio: Double
}

class GTOStrategyHelper {
    static let shared = GTOStrategyHelper()
    
    private init() {}
    
    func calculateMDF(betSize: Int, potSize: Int) -> Double {
        guard betSize > 0 else { return 1.0 }
        return 1.0 - Double(betSize) / Double(potSize + betSize)
    }
    
    func getOptimalBetSize(
        street: Street,
        boardTexture: GameBoardTexture,
        isIP: Bool,
        handStrength: Double,
        hasDraw: Bool
    ) -> GTOAction {
        var baseSize: Double
        
        switch street {
        case .flop:
            baseSize = boardTexture == .dry ? 0.33 : 0.50
        case .turn:
            baseSize = boardTexture == .dry ? 0.50 : 0.66
        case .river:
            baseSize = hasDraw ? 0.66 : 0.75
        default:
            baseSize = 0.50
        }
        
        if !isIP {
            baseSize *= 0.9
        }
        
        if handStrength > 0.8 {
            baseSize = max(baseSize, 0.66)
        } else if handStrength < 0.4 {
            baseSize = min(baseSize, 0.33)
        }
        
        return sizeToAction(baseSize * 100)
    }
    
    private func sizeToAction(_ percent: Double) -> GTOAction {
        switch percent {
        case ..<20: return .check
        case 20..<42: return .bet33
        case 42..<58: return .bet50
        case 58..<70: return .bet66
        case 70..<85: return .bet75
        case 85..<150: return .bet100
        default: return .allIn
        }
    }
    
    func calculateValueBluffRatio(
        potSize: Int,
        betSize: Int,
        equity: Double
    ) -> (value: Double, bluff: Double) {
        let potOdds = Double(betSize) / Double(potSize + betSize)
        
        let valueRatio = equity / max(potOdds, 0.01)
        let bluffRatio = (1 - equity) / max(potOdds, 0.01)
        
        let total = valueRatio + bluffRatio
        
        return (
            value: total > 0 ? valueRatio / total : 0.7,
            bluff: total > 0 ? bluffRatio / total : 0.3
        )
    }
    
    func getDefendingRange(
        mdf: Double,
        handStrength: Double,
        hasDraw: Bool,
        equity: Double,
        potOdds: Double
    ) -> GTODecision {
        let mustCall = equity > potOdds
        
        let valueHands = min(handStrength * 0.6, 0.5)
        let drawHands = hasDraw ? 0.15 : 0.0
        let airHands = equity < potOdds ? min((potOdds - equity) * mdf, 0.1) : 0
        
        let totalDefend = valueHands + drawHands + airHands
        
        let raiseFrequency = min(totalDefend * 0.2, 0.15)
        
        let reason: String
        if mustCall {
            reason = "Must call: equity > pot odds"
        } else if totalDefend > mdf {
            reason = "Defend \(Int(totalDefend*100))% to meet MDF \(Int(mdf*100))%"
        } else {
            reason = "Tighten range below MDF"
        }
        
        return GTODecision(
            action: .bet33,
            frequency: totalDefend,
            reason: reason,
            minimumDefenseFrequency: mdf,
            valueRatio: valueHands,
            bluffRatio: airHands
        )
    }
    
    func calculateDonkBetFrequency(
        boardTexture: GameBoardTexture,
        isIP: Bool,
        pfrWasIP: Bool
    ) -> Double {
        guard !isIP else { return 0.05 }
        
        var frequency = 0.15
        
        if boardTexture == .dry {
            frequency *= 1.2
        } else if boardTexture == .wet {
            frequency *= 0.8
        }
        
        if pfrWasIP {
            frequency *= 0.7
        }
        
        return frequency
    }
    
    func getCheckRaiseFrequency(
        boardTexture: GameBoardTexture,
        handStrength: Double,
        hasDraw: Bool,
        isIP: Bool
    ) -> Double {
        var frequency = 0.25
        
        if handStrength > 0.7 {
            frequency = 0.35
        } else if handStrength < 0.4 {
            frequency = 0.15
        }
        
        if boardTexture == .wet {
            frequency *= 1.1
        }
        
        if hasDraw {
            frequency *= 1.2
        }
        
        if isIP {
            frequency *= 0.8
        }
        
        return frequency
    }
    
    func calculateOptimalCbetSize(
        street: Street,
        boardTexture: GameBoardTexture,
        isPFR: Bool,
        hasRangeAdvantage: Bool
    ) -> Int {
        guard isPFR else { return 0 }
        
        let basePercent: Double
        
        switch street {
        case .flop:
            if boardTexture == .dry && hasRangeAdvantage {
                basePercent = 0.50
            } else if boardTexture == .wet {
                basePercent = 0.33
            } else {
                basePercent = 0.40
            }
        case .turn:
            basePercent = boardTexture == .dry ? 0.50 : 0.60
        case .river:
            basePercent = 0.66
        default:
            basePercent = 0.40
        }
        
        return Int(basePercent * 100)
    }
    
    func shouldDoubleBarrel(
        street: Street,
        firstBetSize: Int,
        firstBetSucceeded: Bool,
        boardTexture: GameBoardTexture,
        equity: Double,
        opponentTendency: PlayerTendency
    ) -> Double {
        guard street == .turn else { return 0 }
        
        var frequency = 0.35
        
        if firstBetSucceeded {
            frequency *= 1.3
        }
        
        if equity > 0.6 {
            frequency *= 1.2
        }
        
        if boardTexture == .dry {
            frequency *= 1.1
        } else if boardTexture == .wet {
            frequency *= 0.8
        }
        
        switch opponentTendency {
        case .nit:
            frequency *= 0.7
        case .callingStation:
            frequency *= 0.5
        case .lag:
            frequency *= 1.2
        default:
            break
        }
        
        return min(frequency, 0.6)
    }
    
    func shouldTripleBarrel(
        riverEquity: Double,
        boardTexture: GameBoardTexture,
        potSize: Int,
        betSize: Int,
        opponentTendency: PlayerTendency
    ) -> Double {
        var frequency = 0.20
        
        if riverEquity > 0.7 {
            frequency = 0.40
        } else if riverEquity > 0.5 {
            frequency = 0.25
        }
        
        if boardTexture == .dry {
            frequency *= 1.3
        } else if boardTexture == .wet {
            frequency *= 0.7
        }
        
        let potOdds = Double(betSize) / Double(potSize + betSize)
        if riverEquity > potOdds * 1.5 {
            frequency *= 1.2
        }
        
        switch opponentTendency {
        case .nit:
            frequency *= 1.2
        case .callingStation:
            frequency *= 0.3
        case .lag:
            frequency *= 1.1
        default:
            break
        }
        
        return min(frequency, 0.5)
    }
}

class ExploitStrategyHelper {
    static let shared = ExploitStrategyHelper()
    
    private init() {}
    
    func adjustForOpponent(
        baseStrategy: GTODecision,
        opponentTendency: PlayerTendency,
        handStrength: Double
    ) -> GTODecision {
        var adjusted = baseStrategy
        
        switch opponentTendency {
        case .nit:
            if baseStrategy.frequency > 0.3 {
                adjusted = GTODecision(
                    action: baseStrategy.action,
                    frequency: baseStrategy.frequency * 0.8,
                    reason: "vs Nit: fold more",
                    minimumDefenseFrequency: baseStrategy.minimumDefenseFrequency,
                    valueRatio: baseStrategy.valueRatio,
                    bluffRatio: baseStrategy.bluffRatio * 0.5
                )
            }
            
        case .callingStation:
            adjusted = GTODecision(
                action: baseStrategy.action,
                frequency: baseStrategy.frequency * 1.2,
                reason: "vs Calling Station: bet more",
                minimumDefenseFrequency: baseStrategy.minimumDefenseFrequency,
                valueRatio: baseStrategy.valueRatio * 1.1,
                bluffRatio: baseStrategy.bluffRatio * 0.3
            )
            
        case .lag:
            if handStrength > 0.6 {
                adjusted = GTODecision(
                    action: .allIn,
                    frequency: baseStrategy.frequency,
                    reason: "vs LAG: value bet big",
                    minimumDefenseFrequency: baseStrategy.minimumDefenseFrequency,
                    valueRatio: baseStrategy.valueRatio,
                    bluffRatio: baseStrategy.bluffRatio
                )
            }
            
        default:
            break
        }
        
        return adjusted
    }
    
    func exploitLoosePassive(
        callFrequency: Double,
        foldFrequency: Double,
        raiseFrequency: Double
    ) -> String {
        if callFrequency > 0.6 {
            return "Value bet: opponent calls too much"
        } else if foldFrequency > 0.5 {
            return "Bluff more: opponent folds too much"
        } else if raiseFrequency < 0.1 {
            return "Check behind: no raises to fear"
        }
        return "Standard play"
    }
    
    func exploitTightAggressive(
        fourBetFrequency: Double,
        continuationBetFrequency: Double,
        boardTexture: GameBoardTexture
    ) -> String {
        if fourBetFrequency > 0.15 {
            return "Flat more: opponent 4-bets light"
        } else if continuationBetFrequency > 0.7 && boardTexture == .wet {
            return "Check-raise: opponent cbets too much on wet boards"
        } else if boardTexture == .dry {
            return "Call more: opponent will bet/fold"
        }
        return "Standard play"
    }
}
