import Foundation

/// AI 难度等级
enum DifficultyLevel: Int, CaseIterable, Codable {
    case easy = 1       // 简单
    case medium = 2     // 中等
    case hard = 3       // 困难
    case expert = 4     // 专家
    
    var precision: Double {
        switch self {
        case .easy: return 0.60
        case .medium: return 0.80
        case .hard: return 0.95
        case .expert: return 1.00
        }
    }
    
    var targetWinRate: ClosedRange<Double> {
        switch self {
        case .easy: return 0.55...0.65
        case .medium: return 0.45...0.55
        case .hard: return 0.35...0.45
        case .expert: return 0.30...0.40
        }
    }
    
    var description: String {
        switch self {
        case .easy: return "简单 (AI 犯错多)"
        case .medium: return "中等 (AI 基本合理)"
        case .hard: return "困难 (AI 接近最优)"
        case .expert: return "专家 (完整对手建模)"
        }
    }
    
    func increase() -> DifficultyLevel {
        return DifficultyLevel(rawValue: min(4, self.rawValue + 1)) ?? self
    }
    
    func decrease() -> DifficultyLevel {
        return DifficultyLevel(rawValue: max(1, self.rawValue - 1)) ?? self
    }
}

class DifficultyManager {
    
    private var heroWinHistory: [Bool] = []
    private let maxHistory = 100
    
    var currentDifficulty: DifficultyLevel = .medium
    var isAutoDifficulty: Bool = true
    
    /// 记录一手牌结果
    func recordHand(heroWon: Bool) {
        heroWinHistory.append(heroWon)
        if heroWinHistory.count > maxHistory {
            heroWinHistory.removeFirst()
        }
        
        // 每 20 手牌检查一次
        if heroWinHistory.count % 20 == 0 && isAutoDifficulty {
            adjustDifficulty()
        }
    }
    
    /// 计算 Hero 胜率
    var heroWinRate: Double {
        guard !heroWinHistory.isEmpty else { return 0.5 }
        let wins = heroWinHistory.filter { $0 }.count
        return Double(wins) / Double(heroWinHistory.count)
    }
    
    /// 自动调整难度
    private func adjustDifficulty() {
        let winRate = heroWinRate
        
        if winRate > 0.60 {
            let newDifficulty = currentDifficulty.increase()
            if newDifficulty != currentDifficulty {
                print("🎯 难度提升：\(currentDifficulty.description) → \(newDifficulty.description)")
                currentDifficulty = newDifficulty
            }
        } else if winRate < 0.35 {
            let newDifficulty = currentDifficulty.decrease()
            if newDifficulty != currentDifficulty {
                print("🎯 难度降低：\(currentDifficulty.description) → \(newDifficulty.description)")
                currentDifficulty = newDifficulty
            }
        }
    }
    
    /// 根据难度决定是否启用高级功能
    func shouldUseOpponentModeling() -> Bool {
        return currentDifficulty.precision >= 0.80
    }
    
    func shouldUseRangeThinking() -> Bool {
        return currentDifficulty.precision >= 0.95
    }
    
    func shouldUseBluffDetection() -> Bool {
        return currentDifficulty == .expert
    }
}
