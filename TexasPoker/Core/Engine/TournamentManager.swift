import Foundation

/// 管理锦标赛模式的盲注升级、前注和配置
struct TournamentManager {
    
    /// 应用锦标赛配置到引擎参数
    /// - Parameters:
    ///   - config: 锦标赛配置
    ///   - players: 玩家列表
    ///   - resetPlayers: 是否重置玩家筹码（默认为false，仅在游戏开始时设为true）
    static func applyConfig(
        _ config: TournamentConfig,
        players: inout [Player],
        resetPlayers: Bool = false
    ) -> (smallBlind: Int, bigBlind: Int, ante: Int) {
        guard !config.blindSchedule.isEmpty else {
            return (10, 20, 0)
        }
        let firstLevel = config.blindSchedule[0]

        // 仅在游戏开始时（resetPlayers=true）才重置玩家筹码
        if resetPlayers {
            for i in 0..<players.count {
                players[i].chips = config.startingChips
            }
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
        
        let profiles = AIProfile.randomTournamentEntry(
            difficulty: difficulty,
            stage: stage,
            averageStack: config.startingChips
        )
        
        guard let profile = profiles.randomElement() else { return nil }
        
        return Player(
            name: profile.name,
            chips: config.startingChips,
            isHuman: false,
            aiProfile: profile,
            entryIndex: 1
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

        // 使用通用方法处理名称去重
        let finalName = makeUniqueName(baseName: newPlayer.name, existingNames: Set(players.map { $0.name }))

        let playerToAdd = Player(
            name: finalName,
            chips: newPlayer.chips,
            isHuman: false,
            aiProfile: newPlayer.aiProfile,
            entryIndex: newPlayer.entryIndex > 0 ? newPlayer.entryIndex : 1
        )

        players.append(playerToAdd)

        return playerToAdd
    }

    // MARK: - 通用辅助方法

    /// 生成唯一的玩家名称（处理重复）
    /// - Parameters:
    ///   - baseName: 基础名称
    ///   - existingNames: 已有名称集合
    /// - Returns: 不重复的唯一名称
    static func makeUniqueName(baseName: String, existingNames: Set<String>) -> String {
        var finalName = baseName
        var counter = 2

        while existingNames.contains(finalName) {
            finalName = "\(baseName)\(counter)"
            counter += 1
        }

        return finalName
    }

    // MARK: - AI Dynamic Entry (called from endHand)
    
    /// 检查并执行 AI 入场，返回新入场的玩家列表
    static func checkAndAddAIEntries(
        players: inout [Player],
        handNumber: Int,
        gameMode: GameMode,
        difficulty: AIProfile.Difficulty,
        config: TournamentConfig?,
        currentBlindLevel: Int,
        profileId: String
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
        
        // 优先尝试重新加入已有 AI 玩家
        if let rejoinedPlayer = findRejoinableTournamentAIPlayer(
            players: players,
            config: config,
            profileId: profileId,
            rebuyChips: rebuyChips
        ) {
            replaceEliminatedPlayer(at: seatIndex, with: rejoinedPlayer, players: &players)
            newEntries.append(rejoinedPlayer)

            return newEntries
        }
        
        // 如果没有可重新加入的玩家，生成新的随机 AI 玩家
        if let newPlayer = generateRandomEntry(
            difficulty: difficulty,
            config: config,
            handNumber: handNumber
        ) {
            // 使用 rebuy 筹码而非默认筹码
            let existingNames = Set(players.map { $0.name })

            // 使用通用方法处理名称去重
            let finalName = makeUniqueName(baseName: newPlayer.name, existingNames: existingNames)

            // 获取下一个入场序号
            if let aiProfile = newPlayer.aiProfile {
                let entryIndex = AIPlayerBankrollManager.shared.getNextEntryIndex(
                    profileId: profileId,
                    aiProfileId: aiProfile.id
                )
                
                // 从 bankroll 中扣除买入费用
                if let _ = AIPlayerBankrollManager.shared.deductBuyIn(
                    profileId: profileId,
                    aiProfileId: aiProfile.id,
                    buyInAmount: config.buyIn
                ) {
                    let entryPlayer = Player(
                        name: finalName,
                        chips: rebuyChips,
                        isHuman: false,
                        aiProfile: aiProfile,
                        entryIndex: entryIndex
                    )

                    replaceEliminatedPlayer(at: seatIndex, with: entryPlayer, players: &players)
                    newEntries.append(entryPlayer)
                }
            }
        }
        
        return newEntries
    }
    
    // MARK: - Tournament Rejoin Logic
    
    /// 查找可以重新加入的锦标赛 AI 玩家
    static func findRejoinableTournamentAIPlayer(
        players: [Player],
        config: TournamentConfig,
        profileId: String,
        rebuyChips: Int
    ) -> Player? {
        let buyIn = config.buyIn
        
        for profile in AIProfile.allPresets {
            let bankroll = AIPlayerBankrollManager.shared.getBankroll(
                profileId: profileId,
                aiProfileId: profile.id
            )
            
            // 检查 bankroll 是否足够支付买入费用
            guard bankroll >= buyIn else { continue }
            
            // 检查是否已在游戏中
            let isInGame = players.contains { player in
                player.aiProfile?.id == profile.id && player.status != .eliminated
            }
            guard !isInGame else { continue }
            
            // 获取下一个入场序号
            let entryIndex = AIPlayerBankrollManager.shared.getNextEntryIndex(
                profileId: profileId,
                aiProfileId: profile.id
            )
            
            // 扣除买入费用
            if let _ = AIPlayerBankrollManager.shared.deductBuyIn(
                profileId: profileId,
                aiProfileId: profile.id,
                buyInAmount: buyIn
            ) {
                return Player(
                    name: profile.name,
                    chips: rebuyChips,
                    isHuman: false,
                    aiProfile: profile,
                    entryIndex: entryIndex
                )
            }
        }
        
        return nil
    }
    
    /// 检查玩家资金是否足够参加锦标赛
    static func validateBankrollForTournament(bankroll: Int, buyIn: Int) -> Bool {
        return bankroll >= buyIn
    }
}
