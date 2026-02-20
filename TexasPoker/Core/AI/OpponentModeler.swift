import Foundation

/// 记录玩家行动用于模式识别
func recordBettingPattern(playerId: String, handNumber: Int, street: Street, action: PlayerAction, potSize: Int) {
    BettingPatternRecognizer.shared.recordAction(
        playerId: playerId,
        handNumber: handNumber,
        street: street,
        action: action,
        potSize: potSize
    )
}

/// 获取对手下注模式
func getBettingPattern(for playerId: String) -> BettingPattern {
    return BettingPatternRecognizer.shared.recognizePattern(for: playerId)
}

/// 记录手牌用于读牌
func recordHandForReading(playerId: String, communityCards: [Card], street: Street, recentActions: [PlayerAction]) {
    _ = HandReadingSystem.shared.readHand(
        playerId: playerId,
        communityCards: communityCards,
        street: street,
        recentActions: recentActions
    )
}

/// 获取对手手牌解读
func getHandReading(for playerId: String, at street: Street) -> HandReading? {
    return HandReadingSystem.shared.getReading(for: playerId, at: street)
}

/// 策略调整建议
struct StrategyAdjustment {
    var stealFreqBonus: Double      // 偷盲频率调整
    var bluffFreqAdjust: Double     // 诈唬频率调整
    var valueSizeAdjust: Double     // 价值下注尺寸调整
    var callDownAdjust: Double      // 跟注范围调整
    
    static var balanced: StrategyAdjustment {
        StrategyAdjustment(
            stealFreqBonus: 0.0,
            bluffFreqAdjust: 0.0,
            valueSizeAdjust: 0.0,
            callDownAdjust: 0.0
        )
    }
    
    func combine(with trend: TrendData?) -> StrategyAdjustment {
        guard let trend = trend else { return self }
        
        var adjusted = self
        
        switch trend.trend {
        case .improving:
            adjusted.bluffFreqAdjust -= 0.1
            adjusted.callDownAdjust += 0.1
        case .declining:
            adjusted.bluffFreqAdjust += 0.1
            adjusted.callDownAdjust -= 0.1
        case .stable:
            break
        }
        
        return adjusted
    }
}

class OpponentModeler {
    
    /// 分类对手风格
    static func classifyStyle(vpip: Double, pfr: Double, af: Double) -> PlayerStyle {
        // 样本量不足
        if vpip == 0 && pfr == 0 { return .unknown }
        
        // Rock: 超紧超凶
        if vpip < 20 && pfr < 15 && af > 2.5 {
            return .rock
        }
        
        // Fish: 松被动（跟注站）
        if vpip > 45 && pfr < 15 && af < 1.5 {
            return .fish
        }
        
        // LAG: 松凶
        if vpip >= 30 && vpip <= 45 && pfr >= 25 && pfr <= 35 && af >= 3.0 {
            return .lag
        }
        
        // TAG: 紧凶（默认）
        if vpip >= 20 && vpip <= 30 && pfr >= 15 && pfr <= 25 && af >= 2.0 && af <= 3.0 {
            return .tag
        }
        
        // 边界情况：根据 VPIP 主导分类
        if vpip < 25 { return .tag }
        if vpip > 40 { return .fish }
        return .tag
    }
    
    /// 从统计推断对手策略剧本
    static func inferPlaybook(from stats: PlayerStats, confidence: StatisticsConfidence?) -> StrategyPlaybook {
        let vpip = stats.vpip
        let pfr = stats.pfr
        let af = stats.af
        
        guard confidence?.isReliable == true else { return .standard }
        
        if af > 3.0 && vpip > 35 {
            return .aggressive
        } else if af < 1.5 && vpip > 40 {
            return .callingStation
        } else if vpip < 20 && af > 2.5 {
            return .tight
        } else if vpip > 45 {
            return .loose
        } else if stats.threeBet > 10 && af > 2.5 {
            return .bluffy
        }
        
        return .standard
    }
    
    /// 获取综合策略调整（结合风格 + 趋势）
    static func getComprehensiveAdjustment(
        style: PlayerStyle,
        stats: PlayerStats,
        confidence: StatisticsConfidence?
    ) -> StrategyAdjustment {
        var adjustment = getStrategyAdjustment(style: style)
        
        let inferredPlaybook = inferPlaybook(from: stats, confidence: confidence)
        
        switch inferredPlaybook {
        case .bluffy:
            adjustment.bluffFreqAdjust += 0.3
        case .callingStation:
            adjustment.callDownAdjust += 0.2
        case .tight:
            adjustment.bluffFreqAdjust -= 0.2
        case .aggressive:
            adjustment.valueSizeAdjust += 0.2
        case .passive:
            adjustment.callDownAdjust -= 0.2
        case .loose, .standard:
            break
        }
        
        return adjustment
    }
    
    /// 获取策略调整建议
    static func getStrategyAdjustment(style: PlayerStyle) -> StrategyAdjustment {
        switch style {
        case .rock:
            return StrategyAdjustment(
                stealFreqBonus: 0.30,      // +30% 偷盲
                bluffFreqAdjust: -0.50,    // -50% 诈唬
                valueSizeAdjust: -0.25,    // 价值下注用小尺寸
                callDownAdjust: -0.30      // 快速弃牌
            )
        case .tag:
            return StrategyAdjustment.balanced
        case .lag:
            return StrategyAdjustment(
                stealFreqBonus: -0.10,
                bluffFreqAdjust: -0.30,
                valueSizeAdjust: 0.30,     // 价值下注用大尺寸
                callDownAdjust: 0.20       // 扩大跟注范围
            )
        case .fish:
            return StrategyAdjustment(
                stealFreqBonus: 0.0,
                bluffFreqAdjust: -0.70,    // 几乎不诈唬
                valueSizeAdjust: 0.40,     // 价值下注最大化
                callDownAdjust: -0.20
            )
        case .unknown:
            return StrategyAdjustment.balanced
        }
    }
}
