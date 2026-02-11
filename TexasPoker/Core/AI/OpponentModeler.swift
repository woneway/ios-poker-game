import Foundation

/// 策略调整建议
struct StrategyAdjustment {
    let stealFreqBonus: Double      // 偷盲频率调整
    let bluffFreqAdjust: Double     // 诈唬频率调整
    let valueSizeAdjust: Double     // 价值下注尺寸调整
    let callDownAdjust: Double      // 跟注范围调整
    
    static let balanced = StrategyAdjustment(
        stealFreqBonus: 0.0,
        bluffFreqAdjust: 0.0,
        valueSizeAdjust: 0.0,
        callDownAdjust: 0.0
    )
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
