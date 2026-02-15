import Foundation

/// AI 难度等级
enum DifficultyLevel: Int, CaseIterable, Codable {
    case easy = 1       // 简单 - AI会犯常见错误
    case medium = 2     // 中等 - AI基本合理，偶尔犯错
    case hard = 3       // 困难 - AI接近最优
    case expert = 4     // 专家 - 完整策略包括诈检测
    
    /// AI决策失误率 (0 = 从不犯错, 1 = 总是犯错)
    var mistakeRate: Double {
        switch self {
        case .easy: return 0.25      // 25% 的决策会犯错
        case .medium: return 0.10    // 10% 的决策会犯错
        case .hard: return 0.03      // 3% 的决策会犯错
        case .expert: return 0.0     // 不犯错
        }
    }
    
    /// 是否启用精确计算（Monte Carlo模拟次数）
    var usePreciseEquity: Bool {
        switch self {
        case .easy: return false    // 快速估算即可
        case .medium: return true    // 使用标准模拟
        case .hard: return true     // 使用更多模拟
        case .expert: return true    // 最大精度
        }
    }
    
    /// Monte Carlo 迭代次数
    var monteCarloIterations: Int {
        switch self {
        case .easy: return 100
        case .medium: return 300
        case .hard: return 500
        case .expert: return 1000
        }
    }
    
    var description: String {
        switch self {
        case .easy: return "简单 (AI 偶尔犯错)"
        case .medium: return "中等 (AI 基本合理)"
        case .hard: return "困难 (AI 接近最优)"
        case .expert: return "专家 (完整策略)"
        }
    }
}

/// 难度管理器 - 不再基于玩家胜率调整难度
/// 而是通过预设的AI失误率来控制难度
class DifficultyManager {
    
    /// 当前难度等级
    var currentDifficulty: DifficultyLevel = .medium
    
    /// 固定难度模式（不自动调整）
    var isFixedDifficulty: Bool = true
    
    /// 难度描述
    var difficultyDescription: String {
        return currentDifficulty.description
    }
    
    /// 获取当前难度的失误率
    var mistakeRate: Double {
        return currentDifficulty.mistakeRate
    }
    
    /// 手动设置难度
    func setDifficulty(_ level: DifficultyLevel) {
        currentDifficulty = level
        #if DEBUG
        print("🎯 难度设置：\(level.description)")
        #endif
    }
    
    /// 根据难度决定是否启用高级功能
    
    /// 是否使用对手建模
    func shouldUseOpponentModeling() -> Bool {
        // 专家和困难难度使用对手建模
        return currentDifficulty.rawValue >= DifficultyLevel.hard.rawValue
    }
    
    /// 是否使用范围思考
    func shouldUseRangeThinking() -> Bool {
        // 只有专家难度使用完整范围分析
        return currentDifficulty == .expert
    }
    
    /// 是否使用诈检测
    func shouldUseBluffDetection() -> Bool {
        // 专家难度使用诈检测
        return currentDifficulty == .expert
    }
    
    /// 是否使用精确equity计算
    func shouldUsePreciseEquity() -> Bool {
        return currentDifficulty.usePreciseEquity
    }
    
    /// 获取Monte Carlo迭代次数
    func getMonteCarloIterations(street: Street) -> Int {
        let baseIterations = currentDifficulty.monteCarloIterations
        // River使用更少迭代（牌已经发完）
        if street == .river {
            return baseIterations / 2
        }
        return baseIterations
    }
    
    /// 判定AI是否在此决策上犯错
    /// 使用手牌哈希来确保同一手牌结果一致（而不是真正随机）
    func shouldMakeMistake(handHash: Int) -> Bool {
        let rate = mistakeRate
        if rate <= 0 { return false }
        
        // 使用手牌哈希来产生确定的"随机"结果
        // 相同的手牌会产生相同的判断
        let hashValue = abs(handHash) % 10000
        return Double(hashValue) < (rate * 10000)
    }
}
