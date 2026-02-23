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
///
/// Bluff weights are based on poker heuristics:
/// - High AF: Aggressive players bluff more often (经验值)
/// - Triple barrel: 3 streets of betting often indicates polarization (GTO理论)
/// - Dry board + bet: Easier to represent strong hands, so more likely to be bluff (GTO理论)
/// - Wet board + bet: Usually value-heavy, but continued aggression can be bluff (经验值)
/// - River overbet: Most polarized play, often bluff (GTO理论)
/// - Inconsistent sizing: Sign of weakness/indecision (经验值)
class BluffDetector {

    // MARK: - Constants

    /// Threshold for high aggression factor
    private static let highAFThreshold: Double = 3.0

    /// Minimum bet history count for triple barrel detection
    private static let tripleBarrelMinCount: Int = 3

    /// Dry board wetness threshold
    private static let dryBoardThreshold: Double = 0.3

    /// Wet board wetness threshold
    private static let wetBoardThreshold: Double = 0.7

    /// Minimum bet history for wet board continuation check
    private static let wetBoardContinuationMinCount: Int = 2

    /// River overbet ratio threshold (> 1.2x pot)
    private static let overbetRatioThreshold: Double = 1.2

    /// Variance threshold for inconsistent sizing
    private static let sizingVarianceThreshold: Double = 0.3

    /// Minimum hands for good confidence
    private static let minHandsForConfidence: Int = 30

    /// Maximum bluff probability cap
    private static let maxBluffProbability: Double = 0.90

    // MARK: - Bluff Weights

    /// Weights for each bluff signal (经验值，来自GTO理论和数据)
    private struct BluffWeights {
        static let highAF: Double = 0.20         // AF > 3.0 高于正常
        static let tripleBarrel: Double = 0.25   // 3条街持续下注
        static let dryBoard: Double = 0.15       // 干燥面+大注
        static let wetBoard: Double = 0.10       // 湿润面持续攻击
        static let riverOverbet: Double = 0.20   // 河牌超池下注
        static let inconsistentSizing: Double = 0.10 // 尺寸不一致
    }
    
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
        // 激进玩家诈唬频率更高
        if opponent.af > Self.highAFThreshold {
            bluffScore += BluffWeights.highAF
            signals.append(.highAggression)
        }

        // 2. Triple barrel (3 streets of continuous betting)
        // 三条街持续下注通常表示极化范围（强牌或纯诈）
        if betHistory.count >= Self.tripleBarrelMinCount {
            // 使用兼容性写法替代 allSatisfy
            let allBets = betHistory.allSatisfy { $0.type == .bet || $0.type == .raise } ||
                          betHistory.filter { $0.type == .bet || $0.type == .raise }.count == betHistory.count
            if allBets {
                bluffScore += BluffWeights.tripleBarrel
                signals.append(.tripleBarrel)
            }
        }

        // 3. Board texture analysis
        // 干燥面：容易代表强牌，诈唬机会更大
        // 湿润面：持续攻击通常是真强牌
        if board.wetness < Self.dryBoardThreshold {
            // Dry board: easier to represent strong hands (bluff opportunity)
            bluffScore += BluffWeights.dryBoard
            signals.append(.dryBoardLargeBet)
        } else if board.wetness > Self.wetBoardThreshold {
            // Wet board: continued aggression may indicate bluff
            if betHistory.count >= Self.wetBoardContinuationMinCount {
                bluffScore += BluffWeights.wetBoard
                signals.append(.wetBoardContinue)
            }
        }

        // 4. River overbet (bet > 1.2x pot on river)
        // 河牌超池是最极化的下注，通常是诈
        if let lastBet = betHistory.last, lastBet.street == .river {
            let sizeRatio = Double(lastBet.amount) / Double(max(1, potSize))
            if sizeRatio > Self.overbetRatioThreshold {
                bluffScore += BluffWeights.riverOverbet
                signals.append(.riverOverbet)
            }
        }

        // 5. Inconsistent bet sizing (high variance in bet sizes)
        // 尺寸不一致表示软弱或犹豫
        if betHistory.count >= 2 {
            let sizes = betHistory.map { Double($0.amount) / Double(max(1, potSize)) }
            let variance = calculateVariance(sizes)
            if variance > Self.sizingVarianceThreshold {
                bluffScore += BluffWeights.inconsistentSizing
                signals.append(.inconsistentSizing)
            }
        }

        // Cap probability at 90% (永远不要100%确定)
        let probability = min(Self.maxBluffProbability, bluffScore)

        // Confidence based on sample size (need at least 30 hands for good confidence)
        let confidence = min(1.0, Double(opponent.totalHands) / Double(Self.minHandsForConfidence))
        
        return BluffIndicator(
            bluffProbability: probability,
            confidence: confidence,
            signals: signals
        )
    }
    
    /// Calculate variance of a set of values (sample variance)
    private static func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        // 使用样本方差 (n-1) 而不是总体方差 (n)
        return squaredDiffs.reduce(0, +) / Double(values.count - 1)
    }
}
