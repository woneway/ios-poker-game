import Foundation

enum ActionType {
    case fold
    case check
    case call
    case bet
    case raise
    case allIn
}

struct CompleteEV {
    let action: ActionType
    let ev: Double
    let equity: Double
    let expectedWin: Double
    let expectedLose: Double
    let foldEquity: Double
    let isPositiveEV: Bool
    let recommendation: String
}

class ComprehensiveEVCalculator {
    static let shared = ComprehensiveEVCalculator()
    
    private init() {}
    
    func calculateCompleteEV(
        holeCards: [Card],
        communityCards: [Card],
        street: Street,
        action: ActionType,
        betSize: Int,
        callAmount: Int,
        potSize: Int,
        stackSize: Int,
        opponentStack: Int,
        opponentCallProbability: Double,
        opponentFoldProbability: Double,
        isValueBet: Bool
    ) -> CompleteEV {
        let equity = MonteCarloSimulator.calculateEquity(
            holeCards: holeCards,
            communityCards: communityCards,
            playerCount: 2,
            iterations: street == .river ? 200 : 500
        )
        
        switch action {
        case .fold:
            return calculateFoldEV()
            
        case .check:
            return calculateCheckEV(equity: equity, potSize: potSize)
            
        case .call:
            return calculateCallEV(
                equity: equity,
                callAmount: callAmount,
                potSize: potSize,
                stackSize: stackSize,
                opponentStack: opponentStack
            )
            
        case .bet, .raise:
            return calculateBetRaiseEV(
                equity: equity,
                betSize: betSize,
                potSize: potSize,
                callProbability: opponentCallProbability,
                foldProbability: opponentFoldProbability,
                isValueBet: isValueBet
            )
            
        case .allIn:
            return calculateAllInEV(
                equity: equity,
                stackSize: stackSize,
                callAmount: callAmount,
                potSize: potSize,
                opponentCallProbability: opponentCallProbability
            )
        }
    }
    
    private func calculateFoldEV() -> CompleteEV {
        return CompleteEV(
            action: .fold,
            ev: 0,
            equity: 0,
            expectedWin: 0,
            expectedLose: 0,
            foldEquity: 1.0,
            isPositiveEV: true,
            recommendation: "Fold: giving up hand"
        )
    }
    
    private func calculateCheckEV(equity: Double, potSize: Int) -> CompleteEV {
        let expectedWin = equity * Double(potSize)
        
        return CompleteEV(
            action: .check,
            ev: 0,
            equity: equity,
            expectedWin: expectedWin,
            expectedLose: 0,
            foldEquity: 0,
            isPositiveEV: true,
            recommendation: "Check: see next card free"
        )
    }
    
    private func calculateCallEV(
        equity: Double,
        callAmount: Int,
        potSize: Int,
        stackSize: Int,
        opponentStack: Int
    ) -> CompleteEV {
        let winValue = equity * Double(potSize)
        let loseValue = (1 - equity) * Double(callAmount)
        
        let netEV = winValue - loseValue
        
        let riskRewardRatio = Double(opponentStack) / Double(max(callAmount, 1))
        
        let recommendation: String
        if netEV > 0 {
            recommendation = "Call: +EV = \(Int(netEV)) chips"
        } else if riskRewardRatio > 3.0 && equity > 0.25 {
            recommendation = "Call: implied odds justify"
        } else {
            recommendation = "Fold recommended"
        }
        
        return CompleteEV(
            action: .call,
            ev: netEV,
            equity: equity,
            expectedWin: winValue,
            expectedLose: loseValue,
            foldEquity: 0,
            isPositiveEV: netEV > 0,
            recommendation: recommendation
        )
    }
    
    private func calculateBetRaiseEV(
        equity: Double,
        betSize: Int,
        potSize: Int,
        callProbability: Double,
        foldProbability: Double,
        isValueBet: Bool
    ) -> CompleteEV {
        let foldEquity = foldProbability * Double(potSize + betSize)
        
        let callEV = callProbability * (
            equity * Double(potSize + betSize * 2) - (1 - equity) * Double(betSize)
        )
        
        let totalEV = foldEquity + callEV
        
        let totalBets = foldProbability + callProbability
        let adjustedEquity = totalBets > 0 ? (foldProbability * 1.0 + callProbability * equity) / totalBets : equity
        
        let recommendation: String
        if totalEV > 0 {
            recommendation = "Bet/Raise: +EV = \(Int(totalEV))"
        } else if isValueBet && equity > 0.6 {
            recommendation = "Value bet: strength justifies"
        } else {
            recommendation = "Check better"
        }
        
        return CompleteEV(
            action: .bet,
            ev: totalEV,
            equity: adjustedEquity,
            expectedWin: equity * Double(potSize + betSize),
            expectedLose: (1 - equity) * Double(betSize),
            foldEquity: foldProbability,
            isPositiveEV: totalEV > 0,
            recommendation: recommendation
        )
    }
    
    private func calculateAllInEV(
        equity: Double,
        stackSize: Int,
        callAmount: Int,
        potSize: Int,
        opponentCallProbability: Double
    ) -> CompleteEV {
        let totalRisk = Double(stackSize + callAmount)
        
        let winEV = equity * Double(potSize + stackSize)
        let loseEV = (1 - equity) * totalRisk
        
        let totalEV = winEV - loseEV
        
        let foldEV = (1 - opponentCallProbability) * Double(potSize + stackSize)
        let callEV = opponentCallProbability * totalEV
        
        let totalExpected = foldEV + callEV
        
        let recommendation: String
        if equity > 0.5 && totalExpected > 0 {
            recommendation = "All-in: profitable at \(Int(equity*100))%"
        } else if equity > 0.4 && opponentCallProbability < 0.3 {
            recommendation = "All-in: fold equity"
        } else {
            recommendation = "All-in: -EV"
        }
        
        return CompleteEV(
            action: .allIn,
            ev: totalExpected,
            equity: equity,
            expectedWin: winEV,
            expectedLose: loseEV,
            foldEquity: 1 - opponentCallProbability,
            isPositiveEV: totalExpected > 0,
            recommendation: recommendation
        )
    }
    
    func compareActions(
        actions: [ActionType],
        holeCards: [Card],
        communityCards: [Card],
        street: Street,
        betSize: Int,
        callAmount: Int,
        potSize: Int,
        stackSize: Int,
        opponentStack: Int
    ) -> [CompleteEV] {
        var results: [CompleteEV] = []
        
        for action in actions {
            let callProb = 0.5
            let foldProb = 0.3
            
            let ev = calculateCompleteEV(
                holeCards: holeCards,
                communityCards: communityCards,
                street: street,
                action: action,
                betSize: betSize,
                callAmount: callAmount,
                potSize: potSize,
                stackSize: stackSize,
                opponentStack: opponentStack,
                opponentCallProbability: callProb,
                opponentFoldProbability: foldProb,
                isValueBet: false
            )
            results.append(ev)
        }
        
        return results.sorted { $0.ev > $1.ev }
    }
}
