import Foundation

// MARK: - Bluff Signal Enum

/// Signals that indicate potential bluffing behavior
enum BluffSignal: String {
    case tripleBarrel       // 3 条街持续下注
    case riverOverbet       // River 超额下注
    case highAggression     // 对手 AF 过高
    case wetBoardContinue   // Wet board 持续攻击
    case dryBoardLargeBet   // Dry board 大额下注
    case inconsistentSizing // 下注尺寸不一致
}

// MARK: - Bluff Indicator Struct

/// Result of bluff detection analysis
struct BluffIndicator {
    let bluffProbability: Double  // 0-1 (0% to 100%)
    let confidence: Double         // 置信度 (based on sample size)
    let signals: [BluffSignal]     // 诈唬信号列表
    
    /// Recommendation based on bluff probability
    var recommendation: String {
        if bluffProbability > 0.6 {
            return "高诈唬概率 - 扩大跟注范围"
        } else if bluffProbability < 0.3 {
            return "低诈唬概率 - 收紧跟注范围"
        } else {
            return "不确定 - 按 pot odds 决策"
        }
    }
}

// MARK: - Bet Action Struct

/// Records a betting action for history tracking
struct BetAction {
    let street: Street
    let type: ActionType
    let amount: Int
    
    enum ActionType {
        case check
        case bet
        case call
        case raise
        case fold
    }
}

// MARK: - Bluff Detector

/// Detects bluffing patterns based on betting history and opponent stats
class BluffDetector {
    
    /// Calculate bluff probability based on opponent behavior and betting patterns
    /// - Parameters:
    ///   - opponent: Opponent model with stats (AF, VPIP, etc.)
    ///   - board: Board texture analysis
    ///   - betHistory: History of betting actions in current hand
    ///   - potSize: Current pot size
    /// - Returns: BluffIndicator with probability, confidence, and signals
    static func calculateBluffProbability(
        opponent: OpponentModel,
        board: BoardTexture,
        betHistory: [BetAction],
        potSize: Int
    ) -> BluffIndicator {
        
        var bluffScore = 0.0
        var signals: [BluffSignal] = []
        
        // 1. High aggression factor (AF > 3.0 indicates aggressive player)
        if opponent.af > 3.0 {
            bluffScore += 0.20
            signals.append(.highAggression)
        }
        
        // 2. Triple barrel (3 streets of continuous betting)
        if betHistory.count >= 3 {
            let allBets = betHistory.allSatisfy { $0.type == .bet || $0.type == .raise }
            if allBets {
                bluffScore += 0.25
                signals.append(.tripleBarrel)
            }
        }
        
        // 3. Board texture analysis
        if board.wetness < 0.3 {
            // Dry board: easier to represent strong hands (bluff opportunity)
            bluffScore += 0.15
            signals.append(.dryBoardLargeBet)
        } else if board.wetness > 0.7 {
            // Wet board: continued aggression may indicate bluff
            if betHistory.count >= 2 {
                bluffScore += 0.10
                signals.append(.wetBoardContinue)
            }
        }
        
        // 4. River overbet (bet > 1.2x pot on river)
        if let lastBet = betHistory.last, lastBet.street == .river {
            let sizeRatio = Double(lastBet.amount) / Double(max(1, potSize))
            if sizeRatio > 1.2 {
                bluffScore += 0.20
                signals.append(.riverOverbet)
            }
        }
        
        // 5. Inconsistent bet sizing (high variance in bet sizes)
        if betHistory.count >= 2 {
            let sizes = betHistory.map { Double($0.amount) / Double(max(1, potSize)) }
            let variance = calculateVariance(sizes)
            if variance > 0.3 {
                bluffScore += 0.10
                signals.append(.inconsistentSizing)
            }
        }
        
        // Cap probability at 85% (never 100% certain)
        let probability = min(0.85, bluffScore)
        
        // Confidence based on sample size (need at least 30 hands for good confidence)
        let confidence = min(1.0, Double(opponent.totalHands) / 30.0)
        
        return BluffIndicator(
            bluffProbability: probability,
            confidence: confidence,
            signals: signals
        )
    }
    
    /// Calculate variance of a set of values
    private static func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }
}
