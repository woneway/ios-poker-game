import Foundation

enum PotOddsType {
    case direct
    case implied
    case reverseImplied
    case effective
}

struct PotOddsResult {
    let type: PotOddsType
    let odds: Double
    let requiredEquity: Double
    let breakEvenPotSize: Int
    let isProfitable: Bool
    let confidence: Double
}

class PotOddsCalculator {
    static let shared = PotOddsCalculator()
    
    private init() {}
    
    func calculateDirectOdds(callAmount: Int, potSize: Int) -> Double {
        guard callAmount > 0 else { return 0 }
        return Double(callAmount) / Double(potSize + callAmount)
    }
    
    func calculateImpliedOdds(
        callAmount: Int,
        potSize: Int,
        stackSize: Int,
        street: Street,
        handStrength: Double,
        isDraw: Bool
    ) -> Double {
        let directOdds = calculateDirectOdds(callAmount: callAmount, potSize: potSize)
        
        let remainingStreet = remainingStreets(street: street)
        let stackToPotRatio = Double(stackSize) / Double(max(potSize, 1))
        
        var impliedMultiplier: Double = 1.0
        
        if isDraw && remainingStreet > 0 {
            let drawStrength = min(handStrength * 2.0, 0.8)
            let streetBonus = Double(remainingStreet) * 0.05
            impliedMultiplier = 1.0 + drawStrength + streetBonus
        }
        
        if stackToPotRatio > 5.0 {
            impliedMultiplier *= 1.2
        } else if stackToPotRatio < 2.0 {
            impliedMultiplier *= 0.8
        }
        
        let impliedOdds = directOdds * impliedMultiplier
        
        return min(impliedOdds, 0.95)
    }
    
    func calculateReverseImpliedOdds(
        callAmount: Int,
        potSize: Int,
        stackSize: Int,
        opponentStack: Int,
        street: Street,
        isDrawingDeadRisk: Double
    ) -> Double {
        let directOdds = calculateDirectOdds(callAmount: callAmount, potSize: potSize)
        
        let effectiveStack = min(stackSize, opponentStack)
        let stackToPotRatio = Double(effectiveStack) / Double(max(potSize, 1))
        
        var reversePenalty: Double = 0.0
        
        if stackToPotRatio > 3.0 && isDrawingDeadRisk > 0.2 {
            reversePenalty = isDrawingDeadRisk * 0.15 * Double(remainingStreets(street: street) + 1)
        }
        
        return max(0, directOdds - reversePenalty)
    }
    
    func calculateEffectiveOdds(
        callAmount: Int,
        potSize: Int,
        myStack: Int,
        opponentStack: Int,
        street: Street,
        hasDraw: Bool,
        drawEquity: Double
    ) -> PotOddsResult {
        let directOdds = calculateDirectOdds(callAmount: callAmount, potSize: potSize)
        
        let impliedOdds = calculateImpliedOdds(
            callAmount: callAmount,
            potSize: potSize,
            stackSize: myStack,
            street: street,
            handStrength: drawEquity,
            isDraw: hasDraw
        )
        
        let reverseImpliedOdds = calculateReverseImpliedOdds(
            callAmount: callAmount,
            potSize: potSize,
            stackSize: myStack,
            opponentStack: opponentStack,
            street: street,
            isDrawingDeadRisk: hasDraw ? (1 - drawEquity) : 0
        )
        
        let effectiveOdds = min(impliedOdds, reverseImpliedOdds)
        
        let requiredEquity = effectiveOdds
        let isProfitable = drawEquity > requiredEquity
        
        let confidence = calculateConfidence(
            street: street,
            hasDraw: hasDraw,
            stackToPotRatio: Double(min(myStack, opponentStack)) / Double(max(potSize, 1))
        )
        
        let breakEvenPot = callAmount > 0 ? Int(Double(callAmount) / max(drawEquity, 0.01)) - callAmount : 0
        
        return PotOddsResult(
            type: .effective,
            odds: effectiveOdds,
            requiredEquity: requiredEquity,
            breakEvenPotSize: breakEvenPot,
            isProfitable: isProfitable,
            confidence: confidence
        )
    }
    
    func shouldCallWithDraw(
        callAmount: Int,
        potSize: Int,
        outs: Int,
        street: Street,
        myStack: Int,
        opponentStack: Int,
        currentEquity: Double
    ) -> Bool {
        let result = calculateEffectiveOdds(
            callAmount: callAmount,
            potSize: potSize,
            myStack: myStack,
            opponentStack: opponentStack,
            street: street,
            hasDraw: true,
            drawEquity: currentEquity
        )
        
        return result.isProfitable
    }
    
    private func remainingStreets(street: Street) -> Int {
        switch street {
        case .preFlop: return 4
        case .flop: return 3
        case .turn: return 2
        case .river: return 1
        }
    }
    
    private func calculateConfidence(street: Street, hasDraw: Bool, stackToPotRatio: Double) -> Double {
        var confidence = 0.7
        
        switch street {
        case .flop:
            confidence = 0.85
        case .turn:
            confidence = 0.9
        case .river:
            confidence = 1.0
        default:
            confidence = 0.6
        }
        
        if hasDraw {
            confidence *= 0.9
        }
        
        if stackToPotRatio < 2.0 {
            confidence *= 1.0
        } else if stackToPotRatio > 10.0 {
            confidence *= 0.85
        }
        
        return confidence
    }
}

class StackPotRatioCalculator {
    static let shared = StackPotRatioCalculator()
    
    private init() {}
    
    func calculateSPR(stackSize: Int, potSize: Int) -> Double {
        guard potSize > 0 else { return Double(stackSize) }
        return Double(stackSize) / Double(potSize)
    }
    
    func getSPRCategory(spr: Double) -> String {
        if spr < 3 {
            return "低SPR (set mining)"
        } else if spr < 8 {
            return "中SPR (标准)"
        } else if spr < 15 {
            return "高SPR (深筹码)"
        } else {
            return "超高SPR (超深)"
        }
    }
    
    func optimalBetSize(spr: Double, potSize: Int, handStrength: Double, isValueBet: Bool) -> Int {
        var targetSPR: Double
        
        if isValueBet {
            if handStrength > 0.8 {
                targetSPR = 0.5
            } else if handStrength > 0.6 {
                targetSPR = 0.75
            } else {
                targetSPR = 1.0
            }
        } else {
            targetSPR = 1.5
        }
        
        let currentSPR = calculateSPR(stackSize: potSize, potSize: potSize)
        
        if currentSPR < targetSPR {
            return potSize / 2
        } else if currentSPR < targetSPR * 1.5 {
            return potSize / 3
        } else {
            return potSize / 4
        }
    }
}
