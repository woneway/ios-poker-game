import Foundation

enum TournamentStageType: String {
    case early = "早期"
    case middle = "中期"
    case late = "后期"
    case bubble = "泡沫期"
    case finalTable = "决赛桌"
    case headsUp = "单挑"
}

struct TournamentICMOutput {
    let pushEV: Double
    let callEV: Double
    let foldEV: Double
    let recommendedAction: PlayerAction
    let risk: Double
    let bubbleFactor: Double
    let icmPressure: Double
}

struct StackDepthCategory {
    let category: String
    let pushRange: Double
    let callRange: Double
    let minOpenRaise: Int
    
    static let short = StackDepthCategory(
        category: "短码 (<10BB)",
        pushRange: 0.6,
        callRange: 0.3,
        minOpenRaise: 0
    )
    
    static let medium = StackDepthCategory(
        category: "中码 (10-25BB)",
        pushRange: 0.4,
        callRange: 0.5,
        minOpenRaise: 2
    )
    
    static let deep = StackDepthCategory(
        category: "深码 (>25BB)",
        pushRange: 0.2,
        callRange: 0.6,
        minOpenRaise: 3
    )
}

class TournamentStrategyOptimizer {
    static let shared = TournamentStrategyOptimizer()
    
    private init() {}
    
    func analyzeStage(
        playersRemaining: Int,
        payoutSpots: Int,
        avgStack: Int,
        bigBlind: Int
    ) -> TournamentStageType {
        let position = playersRemaining - payoutSpots
        
        if playersRemaining == 2 {
            return .headsUp
        }
        
        if playersRemaining <= payoutSpots + 1 && playersRemaining > payoutSpots {
            return .bubble
        }
        
        if playersRemaining <= payoutSpots {
            return .finalTable
        }
        
        let stackToBB = Double(avgStack) / Double(bigBlind)
        
        if stackToBB < 15 {
            return .late
        } else if stackToBB < 40 {
            return .middle
        } else {
            return .early
        }
    }
    
    func calculateTournamentICM(
        stackSize: Int,
        playersRemaining: Int,
        payoutStructure: [Int],
        currentPosition: Int
    ) -> TournamentICMOutput {
        let totalChips = playersRemaining * 1000
        let chipPercent = Double(stackSize) / Double(totalChips)
        
        var pushEV = 0.0
        var callEV = 0.0
        var foldEV = 0.0
        
        for i in 0..<min(playersRemaining, payoutStructure.count) {
            let positionProb = pow(chipPercent, Double(i + 1))
            pushEV += positionProb * Double(payoutStructure[i])
        }
        
        let avgStack = totalChips / playersRemaining
        if stackSize > avgStack {
            callEV = pushEV * 1.1
            foldEV = pushEV * 0.9
        } else if stackSize < avgStack {
            callEV = pushEV * 0.8
            foldEV = pushEV * 1.1
        }
        
        let bubbleFactor = calculateBubbleFactor(
            playersRemaining: playersRemaining,
            payoutStructure: payoutStructure,
            currentPosition: currentPosition
        )
        
        let icmPressure = calculateICMPressure(
            stackSize: stackSize,
            avgStack: avgStack,
            bubbleFactor: bubbleFactor
        )
        
        let recommended: PlayerAction
        if pushEV > callEV && pushEV > foldEV {
            recommended = .allIn
        } else if callEV > foldEV {
            recommended = .call
        } else {
            recommended = .fold
        }
        
        return TournamentICMOutput(
            pushEV: pushEV,
            callEV: callEV,
            foldEV: foldEV,
            recommendedAction: recommended,
            risk: 1.0 - chipPercent,
            bubbleFactor: bubbleFactor,
            icmPressure: icmPressure
        )
    }
    
    private func calculateBubbleFactor(
        playersRemaining: Int,
        payoutStructure: [Int],
        currentPosition: Int
    ) -> Double {
        let payoutPosition = playersRemaining - currentPosition + 1
        let inTheMoney = payoutPosition <= payoutStructure.count
        
        if !inTheMoney && payoutPosition == payoutStructure.count + 1 {
            return 1.5
        }
        
        if payoutPosition <= 3 {
            return 1.2
        }
        
        return 1.0
    }
    
    private func calculateICMPressure(stackSize: Int, avgStack: Int, bubbleFactor: Double) -> Double {
        let stackRatio = Double(stackSize) / Double(avgStack)
        
        var pressure = 0.0
        
        if stackRatio < 0.5 {
            pressure = 0.8
        } else if stackRatio < 1.0 {
            pressure = 0.5
        } else if stackRatio < 1.5 {
            pressure = 0.3
        } else {
            pressure = 0.1
        }
        
        return pressure * bubbleFactor
    }
    
    func getOptimalPushSize(
        stackSize: Int,
        bigBlind: Int,
        playersToAct: Int,
        stage: TournamentStageType
    ) -> Int {
        let baseSize = bigBlind * 3
        
        switch stage {
        case .early:
            return baseSize
        case .middle:
            return Int(Double(baseSize) * 1.2)
        case .late:
            return Int(Double(baseSize) * 1.5)
        case .bubble:
            return Int(Double(baseSize) * 1.3)
        case .finalTable:
            return Int(Double(baseSize) * 1.4)
        case .headsUp:
            return stackSize
        }
    }
    
    func shouldOpenPush(
        stackSize: Int,
        bigBlind: Int,
        position: TablePosition,
        playersRemaining: Int,
        stage: TournamentStageType
    ) -> Bool {
        let stackToBB = Double(stackSize) / Double(bigBlind)
        
        switch stage {
        case .early:
            return stackToBB < 8
        case .middle:
            return stackToBB < 12
        case .late:
            return stackToBB < 15
        case .bubble:
            return stackToBB < 10
        case .finalTable:
            return stackToBB < 8
        case .headsUp:
            return stackToBB < 5
        }
    }
    
    func calculateMinOpenRaise(
        stackSize: Int,
        bigBlind: Int,
        ante: Int,
        playersToAct: Int
    ) -> Int {
        let totalAntes = ante * playersToAct
        let minRaise = bigBlind * 2
        
        let minLegal = max(minRaise, (totalAntes + bigBlind + bigBlind) / 2)
        
        if stackSize < Int(Double(minLegal) * 2.5) {
            return stackSize
        }
        
        return minLegal
    }
    
    func getStackCategory(stackSize: Int, bigBlind: Int) -> StackDepthCategory {
        let stackToBB = Double(stackSize) / Double(bigBlind)
        
        if stackToBB < 10 {
            return .short
        } else if stackToBB < 25 {
            return .medium
        } else {
            return .deep
        }
    }
    
    func adjustForBubble(
        baseAction: PlayerAction,
        playersRemaining: Int,
        payoutSpots: Int,
        myPosition: Int
    ) -> PlayerAction {
        let inTheMoney = myPosition <= payoutSpots
        let isBubble = playersRemaining == payoutSpots + 1
        
        guard !inTheMoney && isBubble else {
            return baseAction
        }
        
        switch baseAction {
        case .allIn:
            return .allIn
        case .raise(let amount):
            return .raise(Int(Double(amount) * 0.8))
        default:
            return baseAction
        }
    }
    
    func getFinalTableStrategy(
        stackRank: Int,
        totalPlayers: Int,
        bigBlind: Int
    ) -> FinalTableStrategy {
        let relativeStack = Double(totalPlayers - stackRank) / Double(totalPlayers)
        
        var aggression: Double
        var priority: String
        
        if relativeStack > 0.7 {
            aggression = 1.2
            priority = "利用短码"
        } else if relativeStack > 0.4 {
            aggression = 1.0
            priority = "积攒筹码"
        } else {
            aggression = 0.8
            priority = "保护排名"
        }
        
        return FinalTableStrategy(
            aggression: aggression,
            priority: priority,
            recommendedPlay: relativeStack > 0.5 ? "激进" : "稳健"
        )
    }
}

struct FinalTableStrategy {
    let aggression: Double
    let priority: String
    let recommendedPlay: String
}

class ShortStackPushFoldOptimizer {
    static let shared = ShortStackPushFoldOptimizer()
    
    private init() {}
    
    func calculatePushEV(
        stackSize: Int,
        bigBlind: Int,
        playersToAct: Int,
        equity: Double,
        payouts: [Int]
    ) -> Double {
        let pushSize = stackSize
        let totalPot = bigBlind + bigBlind / 2 + (playersToAct * bigBlind / 10)
        
        let foldEquity = 0.3
        let callEquity = equity
        
        let winIfFolded = foldEquity * Double(totalPot)
        let loseIfCalled = (1 - foldEquity) * (1 - callEquity) * Double(pushSize)
        let winIfCalled = (1 - foldEquity) * callEquity * Double(totalPot + pushSize * 2)
        
        return winIfFolded + winIfCalled - loseIfCalled
    }
    
    func shouldPush(
        stackSize: Int,
        bigBlind: Int,
        equity: Double,
        playersToAct: Int,
        payouts: [Int]
    ) -> Bool {
        let stackToBB = Double(stackSize) / Double(bigBlind)
        
        guard stackToBB < 15 else { return false }
        
        let ev = calculatePushEV(
            stackSize: stackSize,
            bigBlind: bigBlind,
            playersToAct: playersToAct,
            equity: equity,
            payouts: payouts
        )
        
        let threshold = 0.1
        if stackToBB < 5 {
            return equity > 0.35
        } else if stackToBB < 10 {
            return ev > threshold
        } else {
            return ev > threshold * 1.5
        }
    }
    
    func getCallPushRange(
        stackSize: Int,
        bigBlind: Int,
        pushSize: Int
    ) -> Double {
        let stackToBB = Double(stackSize) / Double(bigBlind)
        let pushToPot = Double(pushSize) / Double(bigBlind * 3)
        
        if stackToBB < 5 {
            return 0.5
        } else if stackToBB < 10 {
            return 0.35
        } else {
            return 0.25
        }
    }
}
