import Foundation

/// 管理锦标赛模式的盲注升级、前注和配置
struct TournamentManager {
    
    /// 应用锦标赛配置到引擎参数
    static func applyConfig(
        _ config: TournamentConfig,
        players: inout [Player]
    ) -> (smallBlind: Int, bigBlind: Int, ante: Int) {
        guard !config.blindSchedule.isEmpty else {
            return (10, 20, 0)
        }
        let firstLevel = config.blindSchedule[0]
        
        // Update starting chips for all players
        for i in 0..<players.count {
            players[i].chips = config.startingChips
        }
        
        return (firstLevel.smallBlind, firstLevel.bigBlind, firstLevel.ante)
    }
    
    /// 检查是否需要升级盲注等级，返回新的盲注参数（如果升级了）
    static func checkBlindLevelUp(
        config: TournamentConfig,
        currentLevel: Int,
        handsAtLevel: Int
    ) -> (newLevel: Int, handsAtLevel: Int, smallBlind: Int, bigBlind: Int, ante: Int)? {
        let newHandsAtLevel = handsAtLevel + 1
        
        guard newHandsAtLevel >= config.handsPerLevel else {
            return nil // 还没到升级的手数
        }
        
        let nextLevel = currentLevel + 1
        guard nextLevel < config.blindSchedule.count else {
            return nil // 已到最高等级
        }
        
        let level = config.blindSchedule[nextLevel]
        
        #if DEBUG
        print("🔔 Blinds increased to \(level.description)")
        #endif
        
        return (nextLevel, 0, level.smallBlind, level.bigBlind, level.ante)
    }
}
