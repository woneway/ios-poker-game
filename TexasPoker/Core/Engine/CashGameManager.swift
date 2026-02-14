import Foundation

/// 管理现金游戏（Cash Game）的核心逻辑
/// 包括 AI 买入、补码、入场和离场管理
struct CashGameManager {

    // MARK: - AI 买入金额

    /// 生成随机的 AI 买入金额
    /// 范围: [config.bigBlind * 40, config.maxBuyIn]
    static func randomAIBuyIn(config: CashGameConfig) -> Int {
        let minBuyIn = config.bigBlind * 40
        let maxBuyIn = config.maxBuyIn
        return Int.random(in: minBuyIn...maxBuyIn)
    }

    // MARK: - 补码

    /// 为玩家补码
    /// - Returns: 实际补码金额，如果参数无效返回 0
    static func topUpPlayer(
        players: inout [Player],
        playerIndex: Int,
        toAmount: Int,
        config: CashGameConfig
    ) -> Int {
        guard playerIndex >= 0 && playerIndex < players.count else { return 0 }
        guard players[playerIndex].status != .eliminated else { return 0 }

        let currentChips = players[playerIndex].chips
        guard toAmount > currentChips else { return 0 }
        guard toAmount <= config.maxBuyIn else { return 0 }

        let addedChips = toAmount - currentChips
        players[playerIndex].chips = toAmount
        return addedChips
    }

    // MARK: - AI 入场（概率驱动）

    /// 检查并执行 AI 入场
    /// - 每个空位独立按 50% 概率补入
    /// - 活跃玩家 < 3 时强制补入
    static func checkAIEntries(
        players: inout [Player],
        config: CashGameConfig,
        difficulty: AIProfile.Difficulty
    ) -> [Player] {
        // 找到所有空座位（eliminated 状态）
        var emptySeatIndices: [Int] = []
        for i in 0..<players.count {
            if players[i].status == .eliminated {
                emptySeatIndices.append(i)
            }
        }

        // 没有空座位，直接返回
        guard !emptySeatIndices.isEmpty else { return [] }

        // 计算当前活跃玩家数（排除 eliminated）
        let activePlayerCount = players.filter { $0.status != .eliminated }.count

        // 活跃玩家数 < 3 时强制补入所有空位
        let shouldForceFill = activePlayerCount < 3

        var enteredPlayers: [Player] = []
        let existingNames = Set(players.compactMap { $0.aiProfile?.name })

        for seatIndex in emptySeatIndices {
            // 强制补入或 50% 概率补入
            if shouldForceFill || Double.random(in: 0...1) < 0.5 {
                // 生成随机买入金额
                let buyInAmount = randomAIBuyIn(config: config)

                // 生成随机 AI 玩家
                if let newPlayer = generateRandomAIPlayer(
                    difficulty: difficulty,
                    buyInAmount: buyInAmount,
                    existingNames: existingNames
                ) {
                    // 执行座位替换
                    TournamentManager.replaceEliminatedPlayer(
                        at: seatIndex,
                        with: newPlayer,
                        players: &players
                    )
                    enteredPlayers.append(newPlayer)
                }
            }
        }

        return enteredPlayers
    }

    // MARK: - AI 离场

    /// 检查并执行 AI 离场
    /// - 筹码 > maxBuyIn * 1.5 时 10% 概率离场
    /// - 筹码 < maxBuyIn * 0.3 时 20% 概率离场
    /// - 人类玩家不离场
    static func checkAIDepartures(
        players: inout [Player],
        config: CashGameConfig
    ) -> [Player] {
        var departedPlayers: [Player] = []

        for i in 0..<players.count {
            let player = players[i]

            // 人类玩家不离场
            guard !player.isHuman else { continue }

            // 只处理活跃状态的玩家
            guard player.status == .active else { continue }

            // 筹码 > maxBuyIn * 1.5 时 10% 概率离场
            if player.chips > config.maxBuyIn * 3 / 2 {
                if Double.random(in: 0...1) < 0.1 {
                    players[i].status = .sittingOut
                    departedPlayers.append(player)
                }
            }
            // 筹码 < maxBuyIn * 0.3 时 20% 概率离场
            else if player.chips < config.maxBuyIn * 3 / 10 {
                if Double.random(in: 0...1) < 0.2 {
                    players[i].status = .sittingOut
                    departedPlayers.append(player)
                }
            }
        }

        return departedPlayers
    }

    // MARK: - Private Helpers

    /// 生成随机 AI 玩家（现金游戏版本）
    private static func generateRandomAIPlayer(
        difficulty: AIProfile.Difficulty,
        buyInAmount: Int,
        existingNames: Set<String>
    ) -> Player? {
        let profile = difficulty.availableProfiles.randomElement() ?? .fox

        // 处理名称去重
        var finalName = profile.name
        var counter = 2
        while existingNames.contains(finalName) || playersContainName(finalName) {
            finalName = "\(profile.name)\(counter)"
            counter += 1
        }

        return Player(
            name: finalName,
            chips: buyInAmount,
            isHuman: false,
            aiProfile: profile
        )
    }

    /// 检查现有玩家列表中是否包含指定名称
    private static func playersContainName(_ name: String) -> Bool {
        // 这个方法需要访问外部的 players，可以通过参数传递或闭包捕获
        // 由于是私有辅助方法，这里返回 false，实际使用时通过 existingNames 参数处理
        return false
    }
}
