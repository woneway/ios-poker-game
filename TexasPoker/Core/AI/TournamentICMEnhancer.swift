import Foundation

struct ICMState {
    let payouts: [Int]
    let stacks: [Int]
    let playersRemaining: Int
    
    var totalPrizePool: Int {
        payouts.reduce(0, +)
    }
}

class ICMDecisionEngine {
    static let shared = ICMDecisionEngine()
    
    private init() {}
    
    func calculateICM(
        stacks: [Int],
        payouts: [Int]
    ) -> [Double] {
        guard !stacks.isEmpty else { return [] }
        
        let totalChips = stacks.reduce(0, +)
        guard totalChips > 0 else { return stacks.map { _ in 0 } }
        
        var equities: [Double] = []
        
        for i in 0..<stacks.count {
            let equity = calculatePlayerEquity(
                stack: stacks[i],
                totalChips: totalChips,
                payouts: payouts,
                excludeIndex: i,
                allStacks: stacks
            )
            equities.append(equity)
        }
        
        return equities
    }
    
    private func calculatePlayerEquity(
        stack: Int,
        totalChips: Int,
        payouts: [Int],
        excludeIndex: Int,
        allStacks: [Int]
    ) -> Double {
        let chipPercent = Double(stack) / Double(totalChips)
        
        var equity = 0.0
        
        for payoutIndex in 0..<payouts.count {
            let probability = calculateFinishProbability(
                chipPercent: chipPercent,
                position: payoutIndex,
                playersRemaining: allStacks.count
            )
            equity += probability * Double(payouts[payoutIndex])
        }
        
        return equity
    }
    
    private func calculateFinishProbability(
        chipPercent: Double,
        position: Int,
        playersRemaining: Int
    ) -> Double {
        guard playersRemaining > 0 else { return 0 }
        
        let baseProbability = pow(chipPercent, Double(position + 1))
        
        let positionBonus: Double
        switch position {
        case 0: positionBonus = 1.5
        case 1: positionBonus = 1.2
        case 2: positionBonus = 1.0
        default: positionBonus = 0.8
        }
        
        return baseProbability * positionBonus
    }
    
    func shouldICMPush(
        stackSize: Int,
        bigBlind: Int,
        currentPot: Int,
        icmState: ICMState,
        equity: Double
    ) -> Bool {
        let stackToBB = Double(stackSize) / Double(bigBlind)
        
        guard stackToBB < 20 else { return false }
        
        let bubbleFactor = calculateBubbleFactor(icmState: icmState)
        
        let icmThreshold = calculateICMThreshold(
            stackToBB: stackToBB,
            bubbleFactor: bubbleFactor,
            playersRemaining: icmState.playersRemaining
        )
        
        return equity > icmThreshold
    }
    
    private func calculateBubbleFactor(icmState: ICMState) -> Double {
        guard icmState.playersRemaining > 1 else { return 1.0 }
        
        let avgStack = icmState.stacks.reduce(0, +) / icmState.playersRemaining
        
        let bubblePlayers = icmState.stacks.filter { $0 < avgStack / 2 }.count
        
        if bubblePlayers <= 1 {
            return 1.0
        }
        
        return 1.0 + Double(bubblePlayers) * 0.15
    }
    
    private func calculateICMThreshold(
        stackToBB: Double,
        bubbleFactor: Double,
        playersRemaining: Int
    ) -> Double {
        var threshold = 0.5
        
        if stackToBB < 5 {
            threshold = 0.4
        } else if stackToBB < 10 {
            threshold = 0.45
        } else if stackToBB < 15 {
            threshold = 0.5
        } else {
            threshold = 0.55
        }
        
        threshold *= bubbleFactor
        
        if playersRemaining == 3 {
            threshold *= 1.1
        } else if playersRemaining == 2 {
            threshold *= 1.2
        }
        
        return threshold
    }
    
    func calculateICMEquityChange(
        currentStacks: [Int],
        newStacks: [Int],
        payouts: [Int]
    ) -> [Double] {
        let currentEquity = calculateICM(stacks: currentStacks, payouts: payouts)
        let newEquity = calculateICM(stacks: newStacks, payouts: payouts)
        
        var changes: [Double] = []
        for i in 0..<currentEquity.count {
            let change = newEquity[i] - currentEquity[i]
            changes.append(change)
        }
        
        return changes
    }
}

class TournamentICMEnhancer {
    static let shared = TournamentICMEnhancer()
    
    private let icmEngine = ICMDecisionEngine.shared
    
    private init() {}
    
    func evaluatePushDecision(
        playerStack: Int,
        bigBlind: Int,
        ante: Int,
        playersRemaining: Int,
        payouts: [Int],
        equity: Double,
        position: TablePosition
    ) -> ICMDecision {
        let potSize = calculateCurrentPot(
            playerStack: playerStack,
            bigBlind: bigBlind,
            ante: ante,
            playersRemaining: playersRemaining
        )
        
        let stacks = Array(repeating: playerStack, count: playersRemaining)
        
        let icmState = ICMState(payouts: payouts, stacks: stacks, playersRemaining: playersRemaining)
        
        let shouldPush = icmEngine.shouldICMPush(
            stackSize: playerStack,
            bigBlind: bigBlind,
            currentPot: potSize,
            icmState: icmState,
            equity: equity
        )
        
        let icmEquityChange = calculatePushEquityChange(
            playerStack: playerStack,
            potSize: potSize,
            equity: equity
        )
        
        let risk = calculateRisk(stackSize: playerStack, bigBlind: bigBlind)
        
        return ICMDecision(
            shouldPush: shouldPush,
            icmEquityChange: icmEquityChange,
            risk: risk,
            recommendedAction: shouldPush ? .allIn : .fold
        )
    }
    
    private func calculateCurrentPot(playerStack: Int, bigBlind: Int, ante: Int, playersRemaining: Int) -> Int {
        let sb = bigBlind / 2
        return sb + bigBlind + (ante * playersRemaining)
    }
    
    private func calculatePushEquityChange(playerStack: Int, potSize: Int, equity: Double) -> Double {
        let chipsWon = Double(potSize) * equity
        let chipsLost = Double(playerStack) * (1 - equity)
        return chipsWon - chipsLost
    }
    
    private func calculateRisk(stackSize: Int, bigBlind: Int) -> Double {
        let stackToBB = Double(stackSize) / Double(bigBlind)
        
        if stackToBB < 5 {
            return 0.9
        } else if stackToBB < 10 {
            return 0.7
        } else if stackToBB < 20 {
            return 0.4
        }
        return 0.2
    }
}

struct ICMDecision {
    let shouldPush: Bool
    let icmEquityChange: Double
    let risk: Double
    let recommendedAction: PlayerAction
    
    var isICMProfitable: Bool {
        return icmEquityChange > 0
    }
}

class BubblePlayAnalyzer {
    static let shared = BubblePlayAnalyzer()
    
    private init() {}
    
    func isBubbleSituation(
        stacks: [Int],
        bigBlind: Int,
        payoutJump: Double
    ) -> Bool {
        let avgStack = stacks.reduce(0, +) / stacks.count
        
        let shortStack = stacks.filter { $0 < bigBlind * 10 }.count
        
        guard shortStack >= 1 else { return false }
        
        return payoutJump > 0.3
    }
    
    func calculateBubblePressure(
        stack: Int,
        bigBlind: Int,
        avgStack: Int,
        payouts: [Int]
    ) -> Double {
        let stackRatio = Double(stack) / Double(avgStack)
        
        var pressure = 0.0
        
        if stackRatio < 0.5 {
            pressure = 0.8
        } else if stackRatio < 1.0 {
            pressure = 0.5
        } else if stackRatio < 1.5 {
            pressure = 0.3
        }
        
        if payouts.count >= 2 {
            let jumpValue = Double(payouts[0] - payouts[1]) / Double(payouts[0])
            pressure *= (1 + jumpValue)
        }
        
        return min(pressure, 1.0)
    }
    
    func adjustStrategyForBubble(
        baseEquity: Double,
        bubblePressure: Double,
        isShortStack: Bool
    ) -> Double {
        var adjusted = baseEquity
        
        if bubblePressure > 0.5 {
            adjusted *= 1.2
        }
        
        if isShortStack && bubblePressure > 0.3 {
            adjusted *= 1.15
        }
        
        return min(adjusted, 0.95)
    }
}
