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
    
    // MARK: - Random Entry System
    
    /// 检查是否应该触发随机入场（根据手数和淘汰率）
    static func shouldTriggerRandomEntry(
        handNumber: Int,
        currentPlayerCount: Int,
        config: TournamentConfig
    ) -> Bool {
        // 每 10 手牌有一定概率触发新玩家入场
        guard handNumber % 10 == 0 else { return false }
        
        // 桌子未满才能入场
        guard currentPlayerCount < 8 else { return false }
        
        // 锦标赛早期更频繁地有新玩家入场
        let entryProbability: Double
        switch TournamentStage.from(handNumber: handNumber, totalPlayers: config.totalEntrants) {
        case .early:
            entryProbability = 0.6
        case .middle:
            entryProbability = 0.4
        case .late:
            entryProbability = 0.2
        case .finalTable:
            entryProbability = 0.0 // 决赛桌不再入场
        }
        
        return Double.random(in: 0...1) < entryProbability
    }
    
    /// 生成新入场玩家
    static func generateRandomEntry(
        difficulty: AIProfile.Difficulty,
        config: TournamentConfig,
        handNumber: Int
    ) -> Player? {
        let stage = TournamentStage.from(handNumber: handNumber, totalPlayers: config.totalEntrants)
        
        // 计算当前平均筹码
        let averageStack = config.startingChips // 简化计算
        
        return AIProfile.randomTournamentEntry(
            difficulty: difficulty,
            stage: stage,
            averageStack: averageStack
        )
    }
    
    /// 处理玩家入场（包括名称去重）
    static func addRandomPlayer(
        to players: inout [Player],
        difficulty: AIProfile.Difficulty,
        config: TournamentConfig,
        handNumber: Int
    ) -> Player? {
        guard players.count < 8 else { return nil }
        
        guard let newPlayer = generateRandomEntry(
            difficulty: difficulty,
            config: config,
            handNumber: handNumber
        ) else { return nil }
        
        // 检查名称是否重复，如果重复则添加编号
        var finalName = newPlayer.name
        var counter = 2
        let existingNames = Set(players.map { $0.name })
        
        while existingNames.contains(finalName) {
            finalName = "\(newPlayer.name)\(counter)"
            counter += 1
        }
        
        let playerToAdd = Player(
            name: finalName,
            chips: newPlayer.chips,
            isHuman: false,
            aiProfile: newPlayer.aiProfile
        )
        
        players.append(playerToAdd)
        
        #if DEBUG
        print("🎉 新玩家 \(finalName) 入场，筹码: \(playerToAdd.chips)")
        #endif
        
        return playerToAdd
    }
}
