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

// MARK: - Hand Range Struct

/// Represents a player's estimated hand range
struct HandRange {
    let position: Position
    let action: PreflopAction
    let street: Street
    let rangeWidth: Double      // 0.0 to 1.0 (0% to 100% of hands)
    let description: String
}

// MARK: - Range Analyzer

/// Analyzes and estimates opponent hand ranges based on position and action
class RangeAnalyzer {
    
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
            guard let threshold = preflopRanges[position] else {
                rangeWidth = 0.20
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
            // Chen 7.0 → 30% width (1.0 - 7.0/10.0)
            // Chen 3.0 → 70% width (1.0 - 3.0/10.0)
            rangeWidth = 1.0 - (threshold / 10.0)
            
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
