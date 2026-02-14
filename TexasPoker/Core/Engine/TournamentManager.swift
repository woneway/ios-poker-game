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
    
    // MARK: - Rebuy System
    
    /// 计算 Rebuy 筹码（纯函数，易测试）
    /// 公式：baseChips + currentBlindLevel * 500
    static func calculateRebuyChips(
        baseChips: Int,
        currentBlindLevel: Int
    ) -> Int {
        return baseChips + currentBlindLevel * 500
    }
    
    /// 在指定座位替换已淘汰玩家（保持座位索引稳定）
    static func replaceEliminatedPlayer(
        at seatIndex: Int,
        with newPlayer: Player,
        players: inout [Player]
    ) {
        guard seatIndex >= 0 && seatIndex < players.count else { return }
        guard players[seatIndex].status == .eliminated else { return }
        players[seatIndex] = newPlayer
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
    
    // MARK: - AI Dynamic Entry (called from endHand)
    
    /// 检查并执行 AI 入场，返回新入场的玩家列表
    static func checkAndAddAIEntries(
        players: inout [Player],
        handNumber: Int,
        gameMode: GameMode,
        difficulty: AIProfile.Difficulty,
        config: TournamentConfig?,
        currentBlindLevel: Int
    ) -> [Player] {
        // 现金局逻辑已迁移到 CashGameManager
        guard gameMode == .tournament else { return [] }
        guard let config = config else { return [] }
        
        var newEntries: [Player] = []
        
        let currentCount = players.filter { $0.status != .eliminated }.count
        guard shouldTriggerRandomEntry(
            handNumber: handNumber,
            currentPlayerCount: currentCount,
            config: config
        ) else { return [] }
        
        // 找到第一个 eliminated 座位
        guard let seatIndex = players.firstIndex(where: { $0.status == .eliminated }) else {
            return []
        }
        
        let rebuyChips = calculateRebuyChips(
            baseChips: config.effectiveBaseRebuyChips,
            currentBlindLevel: currentBlindLevel
        )
        
        if let newPlayer = generateRandomEntry(
            difficulty: difficulty,
            config: config,
            handNumber: handNumber
        ) {
            // 使用 rebuy 筹码而非默认筹码
            let existingNames = Set(players.map { $0.name })
            var finalName = newPlayer.name
            var counter = 2
            while existingNames.contains(finalName) {
                finalName = "\(newPlayer.name)\(counter)"
                counter += 1
            }
            
            let entryPlayer = Player(
                name: finalName,
                chips: rebuyChips,
                isHuman: false,
                aiProfile: newPlayer.aiProfile
            )
            
            replaceEliminatedPlayer(at: seatIndex, with: entryPlayer, players: &players)
            newEntries.append(entryPlayer)
            
            #if DEBUG
            print("🎉 锦标赛新 AI \(finalName) 入场座位 \(seatIndex)，筹码: \(rebuyChips)")
            #endif
        }
        
        return newEntries
    }
}
