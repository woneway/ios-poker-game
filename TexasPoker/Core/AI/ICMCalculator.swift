import Foundation

/// 筹码类别
enum StackCategory {
    case big        // 大筹码 (>1.5x 平均)
    case medium     // 中筹码 (0.7-1.5x 平均)
    case short      // 小筹码 (<0.7x 平均)
}

/// ICM 情况分析
struct ICMSituation {
    let isBubble: Bool
    let myChips: Int
    let avgChips: Int
    let stackRatio: Double
    let playersRemaining: Int
    let payoutSpots: Int
    
    var stackCategory: StackCategory {
        if stackRatio > 1.5 { return .big }
        if stackRatio < 0.7 { return .short }
        return .medium
    }
    
    var pressure: Double {
        let bubbleFactor = isBubble ? 1.5 : 1.0
        switch stackCategory {
        case .big: return 0.2 * bubbleFactor
        case .medium: return -0.15 * bubbleFactor
        case .short: return -0.3 * bubbleFactor
        }
    }
}

/// ICM 策略调整
struct ICMStrategyAdjustment {
    let vpipAdjust: Double
    let aggressionAdjust: Double
    let stealBonus: Double
    let description: String
}

class ICMCalculator {
    
    /// 分析 ICM 情况
    static func analyze(
        myChips: Int,
        allChips: [Int],
        payoutStructure: [Double]
    ) -> ICMSituation {
        
        let totalChips = allChips.reduce(0, +)
        let avgChips = totalChips / allChips.count
        let stackRatio = Double(myChips) / Double(avgChips)
        
        let playersRemaining = allChips.count
        let payoutSpots = payoutStructure.count
        let isBubble = playersRemaining == payoutSpots + 1
        
        return ICMSituation(
            isBubble: isBubble,
            myChips: myChips,
            avgChips: avgChips,
            stackRatio: stackRatio,
            playersRemaining: playersRemaining,
            payoutSpots: payoutSpots
        )
    }
    
    /// 获取 ICM 策略调整
    static func getStrategyAdjustment(situation: ICMSituation) -> ICMStrategyAdjustment {
        
        let pressure = situation.pressure
        
        switch situation.stackCategory {
        case .big:
            return ICMStrategyAdjustment(
                vpipAdjust: 0.20 * pressure,
                aggressionAdjust: 0.30 * pressure,
                stealBonus: 0.25 * pressure,
                description: "大筹码：利用筹码压力"
            )
            
        case .medium:
            return ICMStrategyAdjustment(
                vpipAdjust: -0.15 * abs(pressure),
                aggressionAdjust: -0.10 * abs(pressure),
                stealBonus: -0.10 * abs(pressure),
                description: "中筹码：保守进钱圈"
            )
            
        case .short:
            return ICMStrategyAdjustment(
                vpipAdjust: 0.25 * abs(pressure),
                aggressionAdjust: 0.40 * abs(pressure),
                stealBonus: 0.0,
                description: "小筹码：Push-or-fold 策略"
            )
        }
    }
}
