import Foundation

// MARK: - ICM 配置常量

/// ICM 计算配置
enum ICMConfig {
    /// 泡沫跳跃阈值（百分比）
    enum BubbleJumpThreshold {
        static let critical: Double = 50.0   // 关键泡沫期
        static let high: Double = 30.0       // 高压力
        static let medium: Double = 15.0     // 中等压力
        static let low: Double = 5.0          // 低压力
    }

    /// 泡沫跳跃返回值
    enum BubbleJumpReturn {
        static let critical: Double = 1.0
        static let high: Double = 0.7
        static let medium: Double = 0.4
        static let low: Double = 0.2
        static let none: Double = 0.0
    }

    /// 筹码类别阈值
    enum StackThreshold {
        static let big: Double = 1.5   // >1.5x 平均 = 大筹码
        static let short: Double = 0.7  // <0.7x 平均 = 短筹码
    }
}

/// 筹码类别
enum StackCategory {
    case big        // 大筹码 (>1.5x 平均)
    case medium     // 中筹码 (0.7-1.5x 平均)
    case short      // 小筹码 (<0.7x 平均)
}

/// ICM 情况分析
struct ICMSituation {
    let isBubble: Bool
    let isNearBubble: Bool  // 接近泡沫（ITM前3-5人）
    let myChips: Int
    let avgChips: Int
    let stackRatio: Double
    let playersRemaining: Int
    let payoutSpots: Int
    let bubbleJumpFactor: Double  // 奖金跳跃因子（泡沫期压力）
    
    var stackCategory: StackCategory {
        if stackRatio > ICMConfig.StackThreshold.big { return .big }
        if stackRatio < ICMConfig.StackThreshold.short { return .short }
        return .medium
    }
    
    /// 计算ICM压力
    /// ICM效应是非线性的 - 当筹码接近淘汰线时压力急剧增加
    var pressure: Double {
        var basePressure: Double
        
        switch stackCategory {
        case .big:
            // 大筹码有优势，可以利用小筹码
            basePressure = 0.15
        case .medium:
            // 中筹码应该保守
            basePressure = -0.10
        case .short:
            // 短筹码需要冒险
            basePressure = -0.25
        }
        
        // 应用泡沫因子（奖金跳跃效应）
        let bubbleMultiplier = 1.0 + bubbleJumpFactor
        
        return basePressure * bubbleMultiplier
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
    /// - Parameters:
    ///   - myChips: 玩家当前筹码量
    ///   - allChips: 所有玩家筹码量数组
    ///   - payoutStructure: 奖金结构数组（每个位置的百分比）
    /// - Returns: ICM情况分析
    static func analyze(
        myChips: Int,
        allChips: [Int],
        payoutStructure: [Double]
    ) -> ICMSituation {
        
        let totalChips = allChips.reduce(0, +)
        // 防止除零风险：当所有筹码为 0 时，使用默认值 1
        let avgChips = totalChips > 0 ? totalChips / max(1, allChips.count) : 1
        let stackRatio = Double(myChips) / Double(avgChips)
        
        let playersRemaining = allChips.count
        let payoutSpots = payoutStructure.count
        
        // 泡沫期检测
        let isBubble = playersRemaining == payoutSpots + 1
        
        // 接近泡沫期：距离ITM还有3-5人
        let isNearBubble = playersRemaining <= payoutSpots + 5 && playersRemaining > payoutSpots
        
        // 计算奖金跳跃因子
        // 当玩家筹码接近淘汰线时，奖金跳跃最大
        let bubbleJumpFactor = calculateBubbleJumpFactor(
            myChips: myChips,
            allChips: allChips,
            playersRemaining: playersRemaining,
            payoutSpots: payoutSpots,
            payoutStructure: payoutStructure
        )
        
        return ICMSituation(
            isBubble: isBubble,
            isNearBubble: isNearBubble,
            myChips: myChips,
            avgChips: avgChips,
            stackRatio: stackRatio,
            playersRemaining: playersRemaining,
            payoutSpots: payoutSpots,
            bubbleJumpFactor: bubbleJumpFactor
        )
    }
    
    /// 计算泡沫期奖金跳跃因子
    /// 当玩家筹码刚好在淘汰线附近时，压力最大
    private static func calculateBubbleJumpFactor(
        myChips: Int,
        allChips: [Int],
        playersRemaining: Int,
        payoutSpots: Int,
        payoutStructure: [Double]
    ) -> Double {
        guard playersRemaining > payoutSpots, !payoutStructure.isEmpty else {
            return 0.0
        }

        // 计算当前排名：第 11 名泡沫 = playersRemaining = 10, payoutSpots = 3
        // 排名 = payoutSpots + 1 - (剩余人数 - payoutSpots) = payoutSpots + 1 - (playersRemaining - payoutSpots)
        // 简化：currentPlace = payoutSpots + 1 - (playersRemaining - payoutSpots) = 2 * payoutSpots + 1 - playersRemaining
        let currentPlace = payoutSpots + 1 - (playersRemaining - payoutSpots)
        let nextPlace = currentPlace + 1   // 被淘汰后的名次

        let currentPayout: Double
        let nextPayout: Double

        // 安全获取奖金（索引从 0 开始）
        if currentPlace >= 1 && currentPlace <= payoutStructure.count {
            currentPayout = payoutStructure[currentPlace - 1]
        } else {
            currentPayout = 0.0
        }

        if nextPlace >= 1 && nextPlace <= payoutStructure.count {
            nextPayout = payoutStructure[nextPlace - 1]
        } else {
            nextPayout = 0.0
        }

        // 奖金跳跃 = (当前奖金 - 下一名奖金) / 下一名奖金
        // 使用相对增长确保为正数
        let jumpAmount: Double
        if nextPayout > 0 {
            jumpAmount = (currentPayout - nextPayout) / nextPayout * 100.0  // 转换为百分比
        } else {
            jumpAmount = currentPayout > 0 ? 100.0 : 0.0
        }

        // 使用配置常量
        if jumpAmount > ICMConfig.BubbleJumpThreshold.critical {
            return min(1.0, jumpAmount / 100.0)  // 最大1.0
        } else if jumpAmount > ICMConfig.BubbleJumpThreshold.high {
            return ICMConfig.BubbleJumpReturn.high
        } else if jumpAmount > ICMConfig.BubbleJumpThreshold.medium {
            return ICMConfig.BubbleJumpReturn.medium
        } else if jumpAmount > ICMConfig.BubbleJumpThreshold.low {
            return ICMConfig.BubbleJumpReturn.low
        }

        return ICMConfig.BubbleJumpReturn.none
    }
    
    /// 获取 ICM 策略调整
    static func getStrategyAdjustment(situation: ICMSituation) -> ICMStrategyAdjustment {
        
        let pressure = situation.pressure
        
        switch situation.stackCategory {
        case .big:
            // 大筹码：利用位置优势，偷盲更积极
            return ICMStrategyAdjustment(
                vpipAdjust: 0.15 * (1.0 + pressure),
                aggressionAdjust: 0.25 * (1.0 + pressure),
                stealBonus: 0.20 * (1.0 + pressure),
                description: "大筹码：利用筹码压力偷盲"
            )
            
        case .medium:
            // 中筹码：保守，保护排名
            let cautionFactor = situation.isNearBubble ? 1.5 : 1.0
            return ICMStrategyAdjustment(
                vpipAdjust: -0.12 * cautionFactor,
                aggressionAdjust: -0.08 * cautionFactor,
                stealBonus: -0.05 * cautionFactor,
                description: situation.isNearBubble ? "接近泡沫：保守进圈" : "中筹码：标准策略"
            )
            
        case .short:
            // 短筹码：push-or-fold策略
            // 越短越激进
            let desperation = max(0.0, 1.0 - situation.stackRatio)
            return ICMStrategyAdjustment(
                vpipAdjust: 0.20 + desperation * 0.15,
                aggressionAdjust: 0.35 + desperation * 0.20,
                stealBonus: desperation * 0.10,  // 短筹码偷盲更有价值
                description: "短筹码：Push-or-Fold 策略"
            )
        }
    }
}
