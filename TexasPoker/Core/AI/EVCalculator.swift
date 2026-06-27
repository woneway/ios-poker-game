import Foundation

// MARK: - EV Calculator Utilities
//
// This file contains expected value (EV) calculation utilities.

struct EVCalculator {

    // MARK: - Call EV

    /// Calculate expected value of calling a bet
    static func calculateCallEV(
        equity: Double,
        callAmount: Int,
        potSize: Int,
        opponentRange: Double = GameConstants.AI.defaultOpponentRange
    ) -> Double {
        guard callAmount > 0 else { return 0 }

        let winValue = equity * Double(potSize)
        let loseValue = (1.0 - equity) * Double(callAmount)

        return winValue - loseValue
    }

    // MARK: - Raise EV

    /// Calculate expected value of raising
    static func calculateRaiseEV(
        equity: Double,
        raiseAmount: Int,
        currentBet: Int,
        potSize: Int,
        opponentCallProb: Double = GameConstants.AI.defaultOpponentCallProb
    ) -> Double {
        guard raiseAmount > 0 else { return 0 }

        let foldEquity = (1.0 - opponentCallProb) * Double(potSize)

        let callEV = opponentCallProb * (
            equity * Double(potSize + raiseAmount * 2) - (1.0 - equity) * Double(raiseAmount)
        )

        return foldEquity + callEV
    }

    // MARK: - Pot Odds

    /// Calculate pot odds as a percentage
    static func calculatePotOdds(callAmount: Int, potSize: Int) -> Double {
        guard callAmount > 0 else { return 0 }
        return Double(callAmount) / Double(potSize + callAmount)
    }

    // MARK: - Implied Odds

    /// Calculate implied odds based on SPR
    static func calculateImpliedOdds(spr: Double, street: Street) -> Double {
        let sprHighThreshold = GameConstants.AI.sprHighThreshold
        let sprMediumThreshold = GameConstants.AI.sprMediumThreshold
        let sprTurnHighThreshold = GameConstants.AI.sprTurnHighThreshold
        let sprTurnMediumThreshold = GameConstants.AI.sprTurnMediumThreshold
        let impliedOddsFlopHigh = GameConstants.AI.impliedOddsFlopHigh
        let impliedOddsFlopMedium = GameConstants.AI.impliedOddsFlopMedium
        let impliedOddsTurnHigh = GameConstants.AI.impliedOddsTurnHigh
        let impliedOddsTurnMedium = GameConstants.AI.impliedOddsTurnMedium

        var baseImplied: Double = 0
        switch street {
        case .flop:
            baseImplied = spr > sprHighThreshold ? impliedOddsFlopHigh :
                          (spr > sprMediumThreshold ? impliedOddsFlopMedium : 0)
        case .turn:
            baseImplied = spr > sprTurnHighThreshold ? impliedOddsTurnHigh :
                          (spr > sprTurnMediumThreshold ? impliedOddsTurnMedium : 0)
        case .river:
            baseImplied = 0
        default:
            baseImplied = 0
        }
        return baseImplied
    }

    // MARK: - Best Action Selection

    /// Select the best action based on available options
    static func selectBestAction(
        availableActions: [PlayerAction],
        equity: Double,
        callAmount: Int,
        potSize: Int,
        spr: Double,
        street: Street,
        profile: AIProfile,
        stackSize: Int,
        learnedAction: PlayerAction? = nil
    ) -> PlayerAction {
        let potOdds = calculatePotOdds(callAmount: callAmount, potSize: potSize)
        let impliedOdds = calculateImpliedOdds(spr: spr, street: street)

        var bestEV = -Double.infinity
        var bestAction: PlayerAction = .fold

        let totalOdds = potOdds + impliedOdds
        let isPositiveEV = equity > totalOdds

        let learnedBias: Double = learnedAction != nil ? 0.15 : 0.0

        for action in availableActions {
            var actionEV: Double = 0

            switch action {
            case .fold:
                actionEV = 0

            case .check:
                actionEV = 0.1  // Free play has small value

            case .call:
                if isPositiveEV {
                    actionEV = equity * Double(potSize + callAmount) - (1.0 - equity) * Double(callAmount)
                } else {
                    actionEV = -0.2
                }

            case .raise(let amount):
                let raiseEV = calculateRaiseEV(
                    equity: equity,
                    raiseAmount: amount,
                    currentBet: callAmount,
                    potSize: potSize
                )
                actionEV = raiseEV + learnedBias * 10

            case .allIn:
                // All-in is like a large raise
                let allInEV = calculateRaiseEV(
                    equity: equity,
                    raiseAmount: stackSize,
                    currentBet: callAmount,
                    potSize: potSize
                )
                actionEV = allInEV

            case .raise(let amount):
                // Simplified raise/bet EV
                actionEV = equity * Double(potSize + amount * 2) - (1.0 - equity) * Double(amount)
            }

            if actionEV > bestEV {
                bestEV = actionEV
                bestAction = action
            }
        }

        return bestAction
    }

    // MARK: - Positive EV Check

    /// Determine if a call is +EV
    static func isPositiveEV(
        equity: Double,
        callAmount: Int,
        potSize: Int,
        spr: Double,
        street: Street
    ) -> Bool {
        let potOdds = calculatePotOdds(callAmount: callAmount, potSize: potSize)
        let impliedOdds = calculateImpliedOdds(spr: spr, street: street)
        let breakEvenEquity = potOdds - impliedOdds

        return equity > max(breakEvenEquity, 0)
    }
}
