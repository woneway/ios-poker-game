import Foundation
import SwiftUI

/// 头像类型：emoji或图片
enum AvatarType: Equatable {
    case emoji(String)           // Emoji头像
    case image(String)          // 图片资源名称

    var displayValue: String {
        switch self {
        case .emoji(let value): return value
        case .image(let name): return name
        }
    }
}

struct AIProfile: Equatable {

    // MARK: - Tilt Adjustment Coefficients (常量定义)

    /// Tilt 对 tightness 的影响系数：tilt 增加 1.0 会降低 tightness
    private static let tiltEffectOnTightness: Double = 0.4

    /// Tilt 对 aggression 的影响系数：tilt 增加 1.0 会增加 aggression
    private static let tiltEffectOnAggression: Double = 0.3

    /// Tilt 对 bluff frequency 的影响系数
    private static let tiltEffectOnBluffFreq: Double = 0.25

    /// Tilt 对 call-down tendency 的影响系数
    private static let tiltEffectOnCallDown: Double = 0.2

    /// Minimum effective tightness after tilt (防止过紧)
    private static let minEffectiveTightness: Double = 0.05

    /// Maximum effective values (防止超出范围)
    private static let maxEffectiveAggression: Double = 1.0
    private static let maxEffectiveBluffFreq: Double = 0.8
    private static let maxEffectiveCallDown: Double = 1.0

    // MARK: - Position Bonus Constants (GTO-based)

    /// Position bonuses for VPIP adjustment
    private static let positionBonuses: [Int: Double] = [
        0: 0.20,   // BTN - widest opening range
        1: -0.05,  // SB - positional disadvantage postflop
        2: 0.05,   // BB - already invested, wider defense
        3: -0.18,  // UTG - tightest opening range
        4: -0.14,  // UTG+1
        5: -0.08,  // MP
        6: 0.06,   // HJ (hijack)
        7: 0.14    // CO (cutoff)
    ]

    struct Constants {
        // Preflop threshold base multiplier
        static let preflopThresholdBase: Double = 0.7

        // Minimum and maximum threshold values
        static let minPreflopThreshold: Double = 0.05
        static let maxPreflopThreshold: Double = 0.9
    }

    /// 唯一标识符，用于 playerUniqueId 计算
    /// 例如："石头", "老狐狸", "安娜"
    let id: String
    
    let name: String
    let avatar: AvatarType       // 头像：emoji或图片
    let description: String

    // Core parameters (0.0 - 1.0)
    var tightness: Double        // High = plays fewer hands (low VPIP)
    var aggression: Double       // High = raises more, calls less (PFR/VPIP)
    var bluffFreq: Double        // Probability to bet/raise with weak hand
    let foldTo3Bet: Double       // How often folds facing a re-raise
    let cbetFreq: Double         // Continuation bet frequency on flop
    let cbetTurnFreq: Double     // Turn c-bet frequency (barrel rate)

    // Position awareness (0.0 = ignores position, 1.0 = fully position-dependent)
    let positionAwareness: Double

    // Tilt sensitivity (0.0 = never tilts, 1.0 = tilts easily after bad beats)
    let tiltSensitivity: Double

    // Call-down tendency: how willing to call bets without strong hand (for calling stations)
    var callDownTendency: Double

    // === Extended Behavior Dimensions ===

    /// Risk tolerance (0.0 = extremely conservative, 1.0 = max EV seeker)
    /// Affects: whether to call uncertain all-ins, whether to buy insurance
    let riskTolerance: Double

    /// Bluff detection ability (0.0 = can't read bluffs, 1.0 = accurately detects)
    /// Affects: fold frequency when facing potential bluffs
    let bluffDetection: Double

    /// Deep stack threshold (in big blinds)
    /// When stack depth exceeds this,启用特殊策略
    let deepStackThreshold: Double

    // Current tilt level (mutable, adjusted after each hand)
    var currentTilt: Double = 0.0

    // MARK: - Effective Parameters (adjusted by tilt)

    /// Effective tightness after tilt adjustment
    /// Tilt makes players looser (play more hands)
    var effectiveTightness: Double {
        return max(Self.minEffectiveTightness, tightness - currentTilt * Self.tiltEffectOnTightness)
    }

    /// Effective aggression after tilt adjustment
    /// Tilt makes players more aggressive (raise more)
    var effectiveAggression: Double {
        return min(Self.maxEffectiveAggression, aggression + currentTilt * Self.tiltEffectOnAggression)
    }

    /// Effective bluff frequency after tilt adjustment
    /// Tilt increases bluffing
    var effectiveBluffFreq: Double {
        return min(Self.maxEffectiveBluffFreq, bluffFreq + currentTilt * Self.tiltEffectOnBluffFreq)
    }

    /// Effective call-down tendency after tilt
    /// Tilt increases stubbornness (calling more)
    var effectiveCallDown: Double {
        return min(Self.maxEffectiveCallDown, callDownTendency + currentTilt * Self.tiltEffectOnCallDown)
    }

    // MARK: - Position Adjustments

    /// VPIP adjustment based on seat position relative to dealer
    /// seatOffset: 0=BTN, 1=SB, 2=BB, 3=UTG, 4=UTG+1, 5=MP, 6=HJ, 7=CO
    func vpipAdjustment(seatOffset: Int, totalPlayers: Int) -> Double {
        guard positionAwareness > 0.1 else { return 0 }

        // GTO-based position adjustments
        // BTN is the best position, UTG is the worst
        let posBonus = Self.positionBonuses[seatOffset] ?? 0.0

        return posBonus * positionAwareness
    }

    // MARK: - Starting Hand Strength Threshold

    /// Returns the minimum hand strength (0-1) to voluntarily enter the pot preflop
    /// Lower threshold = plays more hands
    func preflopThreshold(seatOffset: Int, totalPlayers: Int) -> Double {
        let base = effectiveTightness * Constants.preflopThresholdBase  // 0.0 ~ 0.7
        let posAdj = vpipAdjustment(seatOffset: seatOffset, totalPlayers: totalPlayers)
        return max(Constants.minPreflopThreshold, min(Constants.maxPreflopThreshold, base - posAdj))
    }
    
    // MARK: - Equatable

    static func == (lhs: AIProfile, rhs: AIProfile) -> Bool {
        return lhs.name == rhs.name
            && lhs.tightness == rhs.tightness
            && lhs.aggression == rhs.aggression
            && lhs.bluffFreq == rhs.bluffFreq
            && lhs.foldTo3Bet == rhs.foldTo3Bet
            && lhs.cbetFreq == rhs.cbetFreq
            && lhs.cbetTurnFreq == rhs.cbetTurnFreq
            && lhs.positionAwareness == rhs.positionAwareness
            && lhs.tiltSensitivity == rhs.tiltSensitivity
            && lhs.callDownTendency == rhs.callDownTendency
            && lhs.currentTilt == rhs.currentTilt
    }
    
    // MARK: - 7 Preset Characters
    // Based on real-world poker archetypes with standard stat ranges:
    // VPIP ≈ (1 - tightness) * 100
    // PFR ≈ (1 - tightness) * aggression * 100
    // AF ≈ aggression / (1 - aggression) (for values near 1 this diverges)
    
    /// 1. 石头 (The Rock/Nit) - Ultra-Tight-Aggressive
    /// Real stats: VPIP 8-12%, PFR 7-10%, AF 3-4
    /// Only plays top 10% of hands, but when they play they RAISE.
    /// Very predictable: if they bet, they have it.
    static let rock = AIProfile(
        id: "rock",
        name: "石头",
        avatar: .emoji("🪨"),
        description: "只玩顶级牌，一旦入池就加注",
        tightness: 0.90,
        aggression: 0.82,      // High! Rocks raise when they play
        bluffFreq: 0.03,       // Almost never bluffs
        foldTo3Bet: 0.30,      // Low! Their range is already premium
        cbetFreq: 0.72,        // Bets flop with their strong range
        cbetTurnFreq: 0.55,    // Barrels turn with strong hands
        positionAwareness: 0.3, // Ignores position mostly - just plays premiums
        tiltSensitivity: 0.1,
        callDownTendency: 0.15, // Folds if beaten, very discipline
        riskTolerance: 0.4,    // Conservative, plays solid hands
        bluffDetection: 0.5,   // Average ability to read opponents
        deepStackThreshold: 200 // Slightly looser in deep games
    )
    
    /// 2. 疯子麦克 (Maniac Mike) - Ultra-Loose-Aggressive
    /// Real stats: VPIP 55-70%, PFR 35-50%, AF 4-6
    /// Plays most hands, raises constantly, hard to read because range is so wide
    static let maniac = AIProfile(
        id: "maniac",
        name: "疯子麦克",
        avatar: .emoji("🤪"),
        description: "疯狂加注，什么牌都玩",
        tightness: 0.15,       // Plays ~85% of hands
        aggression: 0.90,      // Always raising
        bluffFreq: 0.42,       // Very high bluff frequency
        foldTo3Bet: 0.18,      // Rarely folds to 3-bets
        cbetFreq: 0.88,        // Almost always c-bets
        cbetTurnFreq: 0.70,    // High double-barrel rate
        positionAwareness: 0.2, // Barely cares about position
        tiltSensitivity: 0.3,
        callDownTendency: 0.40, // Will call light sometimes
        riskTolerance: 0.9,     // Extremely aggressive, max EV seeker
        bluffDetection: 0.2,    // Can't read opponents well
        deepStackThreshold: 150 // Even more aggressive in deep games
    )
    
    /// 3. 跟注站安娜 (Calling Station Anna) - Loose-Passive
    /// Real stats: VPIP 50-65%, PFR 4-8%, AF 0.5-1.0
    /// Calls with anything, rarely raises, never folds a pair.
    /// The most exploitable type: just value-bet relentlessly.
    static let callingStation = AIProfile(
        id: "calling_station",
        name: "安娜",
        avatar: .emoji("👩"),
        description: "喜欢跟注，舍不得弃牌",
        tightness: 0.30,       // Plays ~70% of hands
        aggression: 0.12,      // Almost never raises
        bluffFreq: 0.03,      // Doesn't bluff (just calls)
        foldTo3Bet: 0.35,      // Calls most 3-bets (calling station trait)
        cbetFreq: 0.05,       // Almost never c-bets (passive player)
        cbetTurnFreq: 0.02,   // Almost never fires turn
        positionAwareness: 0.1,// Ignores position
        tiltSensitivity: 0.2,
        callDownTendency: 0.85, // THE defining trait: calls down with anything
        riskTolerance: 0.3,   // Conservative but calls too much
        bluffDetection: 0.15,  // Can't read opponents at all
        deepStackThreshold: 200 // Still calls in deep games
    )
    
    /// 4. 狡猾狐狸 (The Fox) - Balanced TAG (Tight-Aggressive)
    /// Real stats: VPIP 22-28%, PFR 18-24%, AF 2.5-3.5
    /// Plays a solid TAG style, mixes in some bluffs, hard to read.
    static let fox = AIProfile(
        id: "fox",
        name: "老狐狸",
        avatar: .emoji("🦊"),
        description: "平衡型高手，难以读牌",
        tightness: 0.55,       // ~45% VPIP (adjusts with position)
        aggression: 0.68,      // Raises more than calls
        bluffFreq: 0.22,       // Balanced bluff frequency
        foldTo3Bet: 0.52,      // Folds weak hands, defends strong ones
        cbetFreq: 0.65,        // Standard c-bet frequency
        cbetTurnFreq: 0.45,    // Selective turn barrels
        positionAwareness: 0.80, // Very position-aware
        tiltSensitivity: 0.15,
        callDownTendency: 0.30, // Moderate - will fold weak hands to pressure
        riskTolerance: 0.6,   // Balanced risk approach
        bluffDetection: 0.7,  // Good at reading opponents
        deepStackThreshold: 180 // More aggressive in deep games
    )
    
    /// 5. 鲨鱼汤姆 (Shark Tom) - LAG Position Master
    /// Real stats: VPIP 28-35%, PFR 22-30%, AF 3-4.5
    /// Exploits position mercilessly, widens range in late position, tightens early.
    static let shark = AIProfile(
        id: "shark",
        name: "鲨鱼汤姆",
        avatar: .emoji("🦈"),
        description: "位置意识极强，后位杀手",
        tightness: 0.48,       // Base ~52% VPIP, much wider IP
        aggression: 0.78,      // Very aggressive
        bluffFreq: 0.28,       // Good bluff frequency
        foldTo3Bet: 0.50,      // Balanced 3-bet defense
        cbetFreq: 0.75,        // High c-bet frequency
        cbetTurnFreq: 0.55,    // Fires turn with equity
        positionAwareness: 0.95, // Master of position
        tiltSensitivity: 0.1,
        callDownTendency: 0.25, // Disciplined
        riskTolerance: 0.7,   // Seeks max EV
        bluffDetection: 0.85, // Excellent at reading opponents
        deepStackThreshold: 150 // Very aggressive in deep games
    )
    
    /// 6. 学院派艾米 (Academic Amy) - GTO Solver
    /// Plays closest to game-theory optimal strategy.
    /// Uses mathematically balanced value/bluff ratios, optimal bet sizing.
    /// Very hard to exploit, never tilts, position-aware.
    static let academic = AIProfile(
        id: "academic",
        name: "艾米",
        avatar: .emoji("🎓"),
        description: "严格GTO，数学驱动，不可利用",
        tightness: 0.52,       // Slightly tight of average
        aggression: 0.62,      // Moderately aggressive
        bluffFreq: 0.25,       // GTO-balanced bluff ratio (~MDF-derived)
        foldTo3Bet: 0.48,      // Balanced 3-bet calling range
        cbetFreq: 0.60,        // Board-texture dependent (handled in engine)
        cbetTurnFreq: 0.42,    // Board-texture dependent
        positionAwareness: 0.85, // Very position-aware
        tiltSensitivity: 0.02,  // Never tilts (robot precision)
        callDownTendency: 0.35, // Calls when odds dictate
        riskTolerance: 0.6,   // EV-based decision making
        bluffDetection: 0.9,  // Best at reading opponents
        deepStackThreshold: 200 // GTO-style in deep games
    )
    
    /// 7. 情绪玩家大卫 (Tilt David) - Dynamic: TAG → LAG-Fish under tilt
    /// Normally plays a decent TAG game, but after losing a big pot,
    /// becomes progressively more loose, aggressive, and bluff-heavy.
    static let tiltDavid = AIProfile(
        id: "tilt_david",
        name: "大卫",
        avatar: .emoji("😤"),
        description: "输钱后情绪化，容易上头",
        tightness: 0.55,       // Normal: decent TAG
        aggression: 0.55,      // Normal: moderate
        bluffFreq: 0.18,       // Normal: reasonable
        foldTo3Bet: 0.50,      // Normal: balanced
        cbetFreq: 0.58,        // Normal
        cbetTurnFreq: 0.40,    // Normal
        positionAwareness: 0.5, // Moderate position sense
        tiltSensitivity: 0.85,  // THE defining trait: extreme tilt potential
        callDownTendency: 0.30, // Normal; rises to 0.50+ when tilted
        riskTolerance: 0.5,   // Moderate
        bluffDetection: 0.4,  // Average (gets worse when tilted)
        deepStackThreshold: 180 // Moderate deep play
    )
    
    /// Legacy preset for backward compatibility
    static let balanced = fox
    
    // MARK: - Signature Actions
    
    /// Signature actions for visual feedback
    enum SignatureAction: String {
        case none = ""
        case slowNod = "slowNod"           // 慢慢点头 - 深思熟虑型
        case quickRaise = "quickRaise"     // 快速加注 - 激进型
        case hesitantCall = "hesitantCall" // 犹豫跟注 - 跟注站
        case confidentCheck = "confidentCheck" // 自信过牌
        case angryThrow = "angryThrow"    // 愤怒拍桌 - tilt后
        case smugSmile = "smugSmile"      // 轻蔑微笑 - 赢牌时
        case shrug = "shrug"               // 耸肩 - 无所谓
    }
    
    /// Returns signature action based on player ID and action type
    func signatureAction(for actionType: String, isRaising: Bool, isCalling: Bool, isChecking: Bool) -> SignatureAction {
        switch id {
        case "rock":
            return .shrug
        case "maniac":
            return isRaising ? .quickRaise : .none
        case "calling_station":
            return isCalling ? .hesitantCall : .none
        case "shark":
            return isChecking ? .confidentCheck : .none
        case "fox":
            return .smugSmile
        case "tilt_david":
            return currentTilt > 0.5 ? .angryThrow : .none
        case "academic":
            return .slowNod
        default:
            return .none
        }
    }
    
    // MARK: - Commentary System
    
    /// Returns a random commentary line based on player ID and action
    func commentary(for actionType: String) -> String? {
        let commentaries: [String: [String]] = [
            "maniac": [
                "哈哈，这把我要拿下！",
                "All-in! 来吧！",
                "怕了吧？",
                "跟我玩？奉陪到底！"
            ],
            "rock": [
                "这牌没法玩",
                "弃",
                "嗯..."
            ],
            "calling_station": [
                "我看看",
                "我跟",
                "哎呀我就知道你要搞我",
                "再跟一手"
            ],
            "tilt_david": [
                "你有种！",
                "来啊！谁怕谁！",
                "我跟你拼了！",
                "别高兴太早！"
            ],
            "fox": [
                "有意思",
                "呵呵"
            ],
            "shark": [
                "不错",
                "跟我玩这套？"
            ]
        ]
        
        guard let lines = commentaries[id] else {
            return nil
        }
        
        // Only show commentary sometimes (30% chance)
        guard Double.random(in: 0...1) < 0.3 else {
            return nil
        }
        
        return lines.randomElement()
    }
}
