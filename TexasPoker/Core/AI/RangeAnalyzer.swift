import Foundation

// MARK: - Position Enum

/// Poker table positions in 8-max format
enum Position: String, CaseIterable {
    case utg        // Under the gun (3 seats from dealer)
    case utgPlus1   // UTG+1 (4 seats from dealer)
    case mp         // Middle position (5 seats from dealer)
    case hj         // Hijack (6 seats from dealer)
    case co         // Cutoff (7 seats from dealer)
    case btn        // Button (dealer, 0 seats from dealer)
    case sb         // Small blind (1 seat from dealer)
    case bb         // Big blind (2 seats from dealer)
    
    /// Convert position to seat offset from dealer
    /// BTN=0, SB=1, BB=2, UTG=3, UTG+1=4, MP=5, HJ=6, CO=7
    var seatOffset: Int {
        switch self {
        case .btn: return 0
        case .sb: return 1
        case .bb: return 2
        case .utg: return 3
        case .utgPlus1: return 4
        case .mp: return 5
        case .hj: return 6
        case .co: return 7
        }
    }
    
    /// Convert seat offset to Position
    static func from(seatOffset: Int) -> Position {
        switch seatOffset {
        case 0: return .btn
        case 1: return .sb
        case 2: return .bb
        case 3: return .utg
        case 4: return .utgPlus1
        case 5: return .mp
        case 6: return .hj
        case 7: return .co
        default:
            // Fallback for non-8-max tables
            if seatOffset < 3 {
                return seatOffset == 1 ? .sb : .bb
            }
            return .mp
        }
    }
}

// MARK: - Preflop Action Enum

/// Preflop actions for range estimation
enum PreflopAction: String {
    case fold
    case call
    case raise
    case threebet
    case fourbet
}

// MARK: - Postflop Action Enum

/// Postflop actions for range narrowing
enum PostflopAction: String {
    case check
    case bet
    case call
    case raise
    case fold
}

// MARK: - Hand Range Struct

/// Represents a player's estimated hand range
struct HandRange {
    let position: Position
    let action: PreflopAction
    let street: Street
    var rangeWidth: Double      // 0.0 to 1.0 (0% to 100% of hands)
    var description: String
}

// MARK: - Range Narrowing Factors

/// Range narrowing factor types
enum NarrowFactorType {
    case wetBoardBet, dryBoardBet, check, raise, call
}

/// Constants for range narrowing based on postflop actions
/// 这些值基于GTO理论和经验值
/// 注意：优先使用实例 config 中的值
private enum RangeNarrowFactors {
    /// Wet board bet: range更极化，需要更紧
    static let wetBoardBet: Double = 0.85

    /// Dry board bet: 可以包括更多诈唬
    static let dryBoardBet: Double = 0.95

    /// Check: 大幅弱化范围
    static let check: Double = 0.70

    /// Raise: 大幅强化范围（强牌+听牌）
    static let raise: Double = 0.50

    /// Call: 中等牌力
    static let call: Double = 0.75

    /// 从配置获取因子
    static func factor(for type: NarrowFactorType, config: RangeAnalyzer.RangeConfig? = nil) -> Double {
        guard let config = config else {
            return defaultValue(for: type)
        }

        switch type {
        case .wetBoardBet: return config.narrowFactors.wetBoardBet
        case .dryBoardBet: return config.narrowFactors.dryBoardBet
        case .check: return config.narrowFactors.check
        case .raise: return config.narrowFactors.raise
        case .call: return config.narrowFactors.call
        }
    }

    private static func defaultValue(for type: NarrowFactorType) -> Double {
        switch type {
        case .wetBoardBet: return 0.85
        case .dryBoardBet: return 0.95
        case .check: return 0.70
        case .raise: return 0.50
        case .call: return 0.75
        }
    }
}

// MARK: - Range Analyzer

/// Analyzes and estimates opponent hand ranges based on position and action
class RangeAnalyzer {

    // MARK: - 可配置范围（可通过 GameSettings 覆盖）

    /// 预置范围配置
    struct RangeConfig {
        /// 位置对应的 Chen 分数阈值
        let preflopRanges: [Position: Double]

        /// 范围缩窄因子
        let narrowFactors: NarrowFactors

        struct NarrowFactors {
            let wetBoardBet: Double
            let dryBoardBet: Double
            let check: Double
            let raise: Double
            let call: Double
        }

        /// 默认配置（GTO 8-max）
        static let defaultConfig = RangeConfig(
            preflopRanges: [
                .utg: 7.0,      // ~14% of hands (88+, ATs+, KQs, AJo+)
                .utgPlus1: 6.5, // ~17%
                .mp: 6.0,       // ~20%
                .hj: 5.0,       // ~25%
                .co: 4.0,       // ~30%
                .btn: 3.0,      // ~42%
                .sb: 4.5,       // ~30% (3-bet or fold preferred)
                .bb: 2.0        // ~45% (defend vs BTN open)
            ],
            narrowFactors: NarrowFactors(
                wetBoardBet: 0.85,
                dryBoardBet: 0.95,
                check: 0.70,
                raise: 0.50,
                call: 0.75
            )
        )

        /// 紧凶配置（更适合初学者）
        static let tightConfig = RangeConfig(
            preflopRanges: [
                .utg: 9.0,
                .utgPlus1: 8.0,
                .mp: 7.0,
                .hj: 6.0,
                .co: 5.0,
                .btn: 4.0,
                .sb: 6.0,
                .bb: 4.0
            ],
            narrowFactors: NarrowFactors(
                wetBoardBet: 0.80,
                dryBoardBet: 0.90,
                check: 0.65,
                raise: 0.45,
                call: 0.70
            )
        )

        /// 松凶配置（高风险）
        static let looseAggressiveConfig = RangeConfig(
            preflopRanges: [
                .utg: 5.0,
                .utgPlus1: 4.5,
                .mp: 4.0,
                .hj: 3.5,
                .co: 2.5,
                .btn: 2.0,
                .sb: 3.0,
                .bb: 1.5
            ],
            narrowFactors: NarrowFactors(
                wetBoardBet: 0.90,
                dryBoardBet: 1.0,
                check: 0.75,
                raise: 0.55,
                call: 0.80
            )
        )
    }

    // MARK: - 实例属性

    /// 当前使用的范围配置
    var config: RangeConfig

    // MARK: - 初始化

    init(config: RangeConfig = .defaultConfig) {
        self.config = config
    }

    // MARK: - Constants

    /// Default range width for unknown position
    private static let defaultRangeWidth: Double = 0.20

    /// Position awareness threshold (below this, position is ignored)
    private static let positionAwarenessThreshold: Double = 0.1

    /// Preflop opening ranges by position (Chen score threshold)
    /// Based on GTO solver outputs for 8-max games
    static let preflopRanges: [Position: Double] = [
        .utg: 7.0,      // ~14% of hands (88+, ATs+, KQs, AJo+)
        .utgPlus1: 6.5, // ~17%
        .mp: 6.0,       // ~20%
        .hj: 5.0,       // ~25%
        .co: 4.0,       // ~30%
        .btn: 3.0,      // ~42%
        .sb: 4.5,       // ~30% (3-bet or fold preferred)
        .bb: 2.0        // ~45% (defend vs BTN open)
    ]

    // MARK: - Chen Formula Conversion Constants

    /// Chen threshold range minimum
    private static let chenThresholdMin: Double = 2.0

    /// Chen threshold range maximum
    private static let chenThresholdMax: Double = 14.0

    /// Base range multiplier
    private static let chenRangeMultiplier: Double = 0.45

    /// Minimum possible range width
    private static let minRangeWidth: Double = 0.05

    /// Maximum possible range width
    private static let maxRangeWidth: Double = 0.50

    /// Estimate opponent's hand range based on position and action
    /// - Parameters:
    ///   - position: Player's position at the table
    ///   - action: The preflop action taken
    ///   - facingRaise: Whether the player is facing a raise
    /// - Returns: HandRange with estimated range width and description
    static func estimateRange(
        position: Position,
        action: PreflopAction,
        facingRaise: Bool
    ) -> HandRange {

        var rangeWidth: Double
        var description: String

        switch action {
        case .fold:
            rangeWidth = 0.0
            description = "已弃牌"

        case .call:
            if facingRaise {
                // Calling a raise: set-mining pairs, suited connectors (~15%)
                rangeWidth = 0.15
                description = "跟注加注：22-99, 同花连牌 (~15%)"
            } else {
                // Limping: wider range (~25%)
                rangeWidth = 0.25
                description = "跟注/平跟：小对子, 同花牌, 连牌 (~25%)"
            }

        case .raise:
            // Opening raise: use position-based threshold
            guard let threshold = Self.preflopRanges[position] else {
                rangeWidth = Self.defaultRangeWidth
                description = "加注：未知位置"
                return HandRange(
                    position: position,
                    action: action,
                    street: .preFlop,
                    rangeWidth: rangeWidth,
                    description: description
                )
            }

            // Convert Chen threshold to range width
            // Chen 7.0 at UTG ~14% range
            // Chen 3.0 at BTN ~42% range
            // 使用非线性映射
            let baseRange = max(Self.minRangeWidth, min(Self.maxRangeWidth, (threshold - Self.chenThresholdMin) / (Self.chenThresholdMax - Self.chenThresholdMin) * Self.chenRangeMultiplier))
            rangeWidth = baseRange
            
            // Generate position-specific description
            let posName = position.rawValue.uppercased()
            let percentage = Int(rangeWidth * 100)
            description = "\(posName) 开池加注：Chen ≥ \(String(format: "%.1f", threshold)) (~\(percentage)%)"
            
        case .threebet:
            // 3-bet range: premium hands + some bluffs (~15%)
            rangeWidth = 0.15
            description = "3-bet 范围：QQ+, AK, AQs, 少量诈唬 (~15%)"
            
        case .fourbet:
            // 4-bet range: super premium hands (~5%)
            rangeWidth = 0.05
            description = "4-bet 范围：QQ+, AKs (~5%)"
        }
        
        return HandRange(
            position: position,
            action: action,
            street: .preFlop,
            rangeWidth: rangeWidth,
            description: description
        )
    }
}

// MARK: - Postflop Range Narrowing Extension

extension RangeAnalyzer {
    
    /// Narrow range based on postflop action and board texture
    /// - Parameters:
    ///   - range: The range to narrow
    ///   - action: The postflop action taken
    ///   - board: The board texture
    /// - Returns: New narrowed range (immutable, functional approach)
    static func narrowRange(
        range: HandRange,
        action: PostflopAction,
        board: BoardTexture,
        config: RangeConfig? = nil
    ) -> HandRange {
        var newWidth = range.rangeWidth
        var newDescription = range.description

        switch action {
        case .bet:
            // Bet: maintain or slightly strengthen range
            if board.wetness > 0.6 {
                // Wet board bet is tighter (more polarized)
                newWidth *= RangeNarrowFactors.factor(for: .wetBoardBet, config: config)
                newDescription += " → Bet on wet board (强化)"
            } else {
                // Dry board may include more bluffs
                newWidth *= RangeNarrowFactors.factor(for: .dryBoardBet, config: config)
                newDescription += " → Bet on dry board (可能诈唬)"
            }

        case .check:
            // Check: weaken range significantly
            newWidth *= RangeNarrowFactors.factor(for: .check, config: config)
            newDescription += " → Check (弱化)"

        case .raise:
            // Raise: strengthen range significantly (strong hands + draws)
            newWidth *= RangeNarrowFactors.factor(for: .raise, config: config)
            newDescription += " → Raise (强牌/听牌)"

        case .call:
            // Call: medium strength (draws, medium pairs, showdown value)
            newWidth *= RangeNarrowFactors.factor(for: .call, config: config)
            newDescription += " → Call (中等牌力)"

        case .fold:
            // Fold: range is eliminated
            newWidth = 0.0
            newDescription = "已弃牌"
        }

        #if DEBUG
        print("📊 范围缩窄：\(Int(range.rangeWidth * 100))% → \(Int(newWidth * 100))%")
        #endif

        return HandRange(
            position: range.position,
            action: range.action,
            street: range.street,
            rangeWidth: newWidth,
            description: newDescription
        )
    }
}
