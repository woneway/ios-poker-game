import Foundation

struct AIProfile: Equatable {
    let name: String
    let avatar: String           // Emoji avatar
    let description: String
    
    // Core parameters (0.0 - 1.0)
    let tightness: Double        // High = plays fewer hands (low VPIP)
    let aggression: Double       // High = raises more, calls less (PFR/VPIP)
    let bluffFreq: Double        // Probability to bet/raise with weak hand
    let foldTo3Bet: Double       // How often folds facing a re-raise
    let cbetFreq: Double         // Continuation bet frequency on flop
    let cbetTurnFreq: Double     // Turn c-bet frequency (barrel rate)
    
    // Position awareness (0.0 = ignores position, 1.0 = fully position-dependent)
    let positionAwareness: Double
    
    // Tilt sensitivity (0.0 = never tilts, 1.0 = tilts easily after bad beats)
    let tiltSensitivity: Double
    
    // Call-down tendency: how willing to call bets without strong hand (for calling stations)
    let callDownTendency: Double
    
    // Current tilt level (mutable, adjusted after each hand)
    var currentTilt: Double = 0.0
    
    // MARK: - Effective Parameters (adjusted by tilt)
    
    /// Effective tightness after tilt adjustment
    /// Tilt makes players looser (play more hands)
    var effectiveTightness: Double {
        return max(0.05, tightness - currentTilt * 0.4)
    }
    
    /// Effective aggression after tilt adjustment
    /// Tilt makes players more aggressive (raise more)
    var effectiveAggression: Double {
        return min(1.0, aggression + currentTilt * 0.3)
    }
    
    /// Effective bluff frequency after tilt adjustment
    /// Tilt increases bluffing
    var effectiveBluffFreq: Double {
        return min(0.8, bluffFreq + currentTilt * 0.25)
    }
    
    /// Effective call-down tendency after tilt
    /// Tilt increases stubbornness (calling more)
    var effectiveCallDown: Double {
        return min(1.0, callDownTendency + currentTilt * 0.2)
    }
    
    // MARK: - Position Adjustments
    
    /// VPIP adjustment based on seat position relative to dealer
    /// seatOffset: 0=BTN, 1=SB, 2=BB, 3=UTG, 4=UTG+1, 5=MP, 6=HJ, 7=CO
    func vpipAdjustment(seatOffset: Int, totalPlayers: Int) -> Double {
        guard positionAwareness > 0.1 else { return 0 }
        
        // GTO-based position adjustments
        // BTN is the best position, UTG is the worst
        let posBonus: Double
        switch seatOffset {
        case 0:  posBonus = 0.20   // BTN - widest opening range
        case 1:  posBonus = -0.05  // SB - positional disadvantage postflop
        case 2:  posBonus = 0.05   // BB - already invested, wider defense
        case 3:  posBonus = -0.18  // UTG - tightest opening range
        case 4:  posBonus = -0.14  // UTG+1
        case 5:  posBonus = -0.08  // MP
        case 6:  posBonus = 0.06   // HJ (hijack)
        case 7:  posBonus = 0.14   // CO (cutoff)
        default: posBonus = 0.0
        }
        
        return posBonus * positionAwareness
    }
    
    // MARK: - Starting Hand Strength Threshold
    
    /// Returns the minimum hand strength (0-1) to voluntarily enter the pot preflop
    /// Lower threshold = plays more hands
    func preflopThreshold(seatOffset: Int, totalPlayers: Int) -> Double {
        let base = effectiveTightness * 0.7  // 0.0 ~ 0.7
        let posAdj = vpipAdjustment(seatOffset: seatOffset, totalPlayers: totalPlayers)
        return max(0.05, min(0.9, base - posAdj))
    }
    
    // MARK: - Equatable
    
    static func == (lhs: AIProfile, rhs: AIProfile) -> Bool {
        return lhs.name == rhs.name
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
        name: "石头",
        avatar: "🪨",
        description: "只玩顶级牌，一旦入池就加注",
        tightness: 0.90,
        aggression: 0.82,      // High! Rocks raise when they play
        bluffFreq: 0.03,       // Almost never bluffs
        foldTo3Bet: 0.30,      // Low! Their range is already premium
        cbetFreq: 0.72,        // Bets flop with their strong range
        cbetTurnFreq: 0.55,    // Barrels turn with strong hands
        positionAwareness: 0.3, // Ignores position mostly - just plays premiums
        tiltSensitivity: 0.1,
        callDownTendency: 0.15  // Folds if beaten, very discipline
    )
    
    /// 2. 疯子麦克 (Maniac Mike) - Ultra-Loose-Aggressive
    /// Real stats: VPIP 55-70%, PFR 35-50%, AF 4-6
    /// Plays most hands, raises constantly, hard to read because range is so wide
    static let maniac = AIProfile(
        name: "疯子麦克",
        avatar: "🤪",
        description: "疯狂加注，什么牌都玩",
        tightness: 0.15,       // Plays ~85% of hands
        aggression: 0.90,      // Always raising
        bluffFreq: 0.42,       // Very high bluff frequency
        foldTo3Bet: 0.18,      // Rarely folds to 3-bets
        cbetFreq: 0.88,        // Almost always c-bets
        cbetTurnFreq: 0.70,    // High double-barrel rate
        positionAwareness: 0.2, // Barely cares about position
        tiltSensitivity: 0.3,
        callDownTendency: 0.40  // Will call light sometimes
    )
    
    /// 3. 跟注站安娜 (Calling Station Anna) - Loose-Passive
    /// Real stats: VPIP 50-65%, PFR 4-8%, AF 0.5-1.0
    /// Calls with anything, rarely raises, never folds a pair.
    /// The most exploitable type: just value-bet relentlessly.
    static let callingStation = AIProfile(
        name: "安娜",
        avatar: "👩",
        description: "喜欢跟注，舍不得弃牌",
        tightness: 0.30,       // Plays ~70% of hands
        aggression: 0.12,      // Almost never raises
        bluffFreq: 0.03,       // Doesn't bluff (just calls)
        foldTo3Bet: 0.15,      // Doesn't fold to 3-bets either (calls!)
        cbetFreq: 0.18,        // Rarely bets, prefers to check-call
        cbetTurnFreq: 0.10,    // Almost never fires turn
        positionAwareness: 0.1, // Ignores position
        tiltSensitivity: 0.2,
        callDownTendency: 0.85  // THE defining trait: calls down with anything
    )
    
    /// 4. 狡猾狐狸 (The Fox) - Balanced TAG (Tight-Aggressive)
    /// Real stats: VPIP 22-28%, PFR 18-24%, AF 2.5-3.5
    /// Plays a solid TAG style, mixes in some bluffs, hard to read.
    static let fox = AIProfile(
        name: "老狐狸",
        avatar: "🦊",
        description: "平衡型高手，难以读牌",
        tightness: 0.55,       // ~45% VPIP (adjusts with position)
        aggression: 0.68,      // Raises more than calls
        bluffFreq: 0.22,       // Balanced bluff frequency
        foldTo3Bet: 0.52,      // Folds weak hands, defends strong ones
        cbetFreq: 0.65,        // Standard c-bet frequency
        cbetTurnFreq: 0.45,    // Selective turn barrels
        positionAwareness: 0.80, // Very position-aware
        tiltSensitivity: 0.15,
        callDownTendency: 0.30  // Moderate - will fold weak hands to pressure
    )
    
    /// 5. 鲨鱼汤姆 (Shark Tom) - LAG Position Master
    /// Real stats: VPIP 28-35%, PFR 22-30%, AF 3-4.5
    /// Exploits position mercilessly, widens range in late position, tightens early.
    static let shark = AIProfile(
        name: "鲨鱼汤姆",
        avatar: "🦈",
        description: "位置意识极强，后位杀手",
        tightness: 0.48,       // Base ~52% VPIP, much wider IP
        aggression: 0.78,      // Very aggressive
        bluffFreq: 0.28,       // Good bluff frequency
        foldTo3Bet: 0.50,      // Balanced 3-bet defense
        cbetFreq: 0.75,        // High c-bet frequency
        cbetTurnFreq: 0.55,    // Fires turn with equity
        positionAwareness: 0.95, // Master of position
        tiltSensitivity: 0.1,
        callDownTendency: 0.25  // Disciplined
    )
    
    /// 6. 学院派艾米 (Academic Amy) - GTO Solver
    /// Plays closest to game-theory optimal strategy.
    /// Uses mathematically balanced value/bluff ratios, optimal bet sizing.
    /// Very hard to exploit, never tilts, position-aware.
    static let academic = AIProfile(
        name: "艾米",
        avatar: "🎓",
        description: "严格GTO，数学驱动，不可利用",
        tightness: 0.52,       // Slightly tight of average
        aggression: 0.62,      // Moderately aggressive
        bluffFreq: 0.25,       // GTO-balanced bluff ratio (~MDF-derived)
        foldTo3Bet: 0.48,      // Balanced 3-bet calling range
        cbetFreq: 0.60,        // Board-texture dependent (handled in engine)
        cbetTurnFreq: 0.42,    // Board-texture dependent
        positionAwareness: 0.85, // Very position-aware
        tiltSensitivity: 0.02,  // Never tilts (robot precision)
        callDownTendency: 0.35   // Calls when odds dictate
    )
    
    /// 7. 情绪玩家大卫 (Tilt David) - Dynamic: TAG → LAG-Fish under tilt
    /// Normally plays a decent TAG game, but after losing a big pot,
    /// becomes progressively more loose, aggressive, and bluff-heavy.
    static let tiltDavid = AIProfile(
        name: "大卫",
        avatar: "😤",
        description: "输钱后情绪化，容易上头",
        tightness: 0.55,       // Normal: decent TAG
        aggression: 0.55,      // Normal: moderate
        bluffFreq: 0.18,       // Normal: reasonable
        foldTo3Bet: 0.50,      // Normal: balanced
        cbetFreq: 0.58,        // Normal
        cbetTurnFreq: 0.40,    // Normal
        positionAwareness: 0.5, // Moderate position sense
        tiltSensitivity: 0.85,  // THE defining trait: extreme tilt potential
        callDownTendency: 0.30  // Normal; rises to 0.50+ when tilted
    )
    
    /// Legacy preset for backward compatibility
    static let balanced = fox
}
