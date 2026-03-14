import Foundation
import CoreData

/// 记录AI玩家输赢，用于资金管理
private func recordAIResult(playerId: String, profit: Int) {
    if profit > 0 {
        AIBankrollManager.shared.recordWin(playerId, amount: profit)
    } else if profit < 0 {
        AIBankrollManager.shared.recordLoss(playerId, amount: -profit)
    }
}

// 使用自定义确定性随机数生成器（替代 SeededRandomNumberGenerator）
private struct DeterministicRandom {
    private static var seed: UInt64 = 0
    private static var isSeeded = false
    
    static func seed(_ newSeed: UInt64) {
        seed = newSeed
        isSeeded = true
    }
    
    static func reset() {
        isSeeded = false
    }
    
    static func random(in range: ClosedRange<Int>) -> Int {
        if isSeeded {
            // 简单的线性同余生成器
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let diff = range.upperBound - range.lowerBound + 1
            return range.lowerBound + Int(seed % UInt64(diff))
        } else {
            return Int.random(in: range)
        }
    }
    
    static func randomBool(probability: Double) -> Bool {
        if isSeeded {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed % 1000000) / 1000000.0 < probability
        } else {
            return Double.random(in: 0...1) < probability
        }
    }
    
    static func randomElement<T>(from array: [T]) -> T? {
        if isSeeded, !array.isEmpty {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return array[Int(seed % UInt64(array.count))]
        } else {
            return array.randomElement()
        }
    }
}

/// 管理现金游戏（Cash Game）的核心逻辑
/// 包括 AI 买入、补码、入场和离场管理
struct CashGameManager {

    // MARK: - 全局状态

    /// 全局系统池，存储离场 AI 的筹码，用于新 AI 入场时循环使用
    /// 这样可以保持游戏中总筹码量的平衡
    private static var systemChipsPool: Int = 0
    
    /// 芯片池最大容量（防止无限积累）
    private static let maxSystemPoolSize = 100000
    
    /// 追踪每个 AIProfile 的入场次数，用于生成唯一的 entryIndex
    /// Key: AIProfile.id (如 "rock", "fox")
    /// Value: 入场次数（下次入场时应该使用的 index）
    private static var profileEntryCounts: [String: Int] = [:]

    // MARK: - 测试辅助（仅 DEBUG）

    #if DEBUG
    /// 测试辅助：随机数生成器（可设置种子以实现确定性测试）
    private static var randomGenerator: CashGameRandomGenerator = .system

    /// 测试辅助：随机数来源
    enum CashGameRandomGenerator {
        case system
        case seeded(UInt64)

        func random(in range: ClosedRange<Int>) -> Int {
            switch self {
            case .system:
                return Int.random(in: range)
            case .seeded(let seed):
                DeterministicRandom.seed(seed)
                return DeterministicRandom.random(in: range)
            }
        }

        func randomBool(probability: Double) -> Bool {
            switch self {
            case .system:
                return Double.random(in: 0...1) < probability
            case .seeded(let seed):
                DeterministicRandom.seed(seed)
                return DeterministicRandom.randomBool(probability: probability)
            }
        }

        func randomElement<T>(from array: [T]) -> T? {
            switch self {
            case .system:
                return array.randomElement()
            case .seeded(let seed):
                DeterministicRandom.seed(seed)
                return DeterministicRandom.randomElement(from: array)
            }
        }
    }

    /// 测试辅助：设置随机数生成器
    static func debugSetRandomGenerator(_ generator: CashGameRandomGenerator) {
        randomGenerator = generator
    }

    /// 测试辅助：重置为系统随机数
    static func debugResetRandomGenerator() {
        randomGenerator = .system
        DeterministicRandom.reset()
    }
    #endif

    // MARK: - AI 买入金额

    /// 生成随机的 AI 买入金额
    /// 范围: [config.bigBlind * 40, config.maxBuyIn]
    static func randomAIBuyIn(config: CashGameConfig) -> Int {
        let minBuyIn = config.bigBlind * 40
        let maxBuyIn = config.maxBuyIn

        #if DEBUG
        return randomGenerator.random(in: minBuyIn...maxBuyIn)
        #else
        return Int.random(in: minBuyIn...maxBuyIn)
        #endif
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

    // MARK: - 系统池重置

    /// 重置系统池（在新游戏开始时调用）
    /// 解决跨游戏会话状态污染问题
    static func resetSystemPool() {
        systemChipsPool = 0
        profileEntryCounts = [:]  // 重置入场计数器
        AIPlayerBankrollManager.shared.resetAllEntryIndexes()  // 重置 UserDefaults 中的 entryIndex
    }

    // MARK: - entryIndex 生成

    /// 为指定 AIProfile 生成唯一的入场序号
    /// - Parameter profile: AIProfile 实例
    /// - Returns: 该 profile 的入场序号（从 1 开始递增）
    static func generateEntryIndex(for profile: AIProfile) -> Int {
        let profileId = profile.id
        let currentCount = profileEntryCounts[profileId] ?? 0
        let newIndex = currentCount + 1
        profileEntryCounts[profileId] = newIndex
        return newIndex
    }

    // MARK: - 测试辅助

    #if DEBUG
    /// 测试辅助：获取当前系统池状态
    static var debugSystemChipsPool: Int {
        return systemChipsPool
    }

    /// 测试辅助：设置系统池金额（用于确定性测试）
    static func debugSetSystemChipsPool(_ amount: Int) {
        systemChipsPool = min(amount, maxSystemPoolSize)
    }

    /// 测试辅助：获取当前 entryIndex 计数
    static var debugProfileEntryCounts: [String: Int] {
        return profileEntryCounts
    }

    /// 测试辅助：重置 entryIndex 计数（用于确定性测试）
    static func debugResetProfileEntryCounts() {
        profileEntryCounts = [:]
    }
    #endif

    // MARK: - AI 入场（概率驱动）

    /// 检查并执行 AI 入场
    /// - 每个空位独立按 50% 概率补入
    /// - 活跃玩家 < 3 时强制补入
    /// - 优先尝试让有 bankroll 的 AI 玩家重新加入
    /// - 其次使用系统池中的筹码，保持经济平衡
    static func checkAIEntries(
        players: inout [Player],
        config: CashGameConfig,
        difficulty: AIProfile.Difficulty,
        profileId: String
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

        for seatIndex in emptySeatIndices {
            // 强制补入或 50% 概率补入
            #if DEBUG
            let shouldEnter = shouldForceFill || randomGenerator.randomBool(probability: 0.5)
            #else
            let shouldEnter = shouldForceFill || Double.random(in: 0...1) < 0.5
            #endif

            if shouldEnter {
                // 只尝试重新加入已有AI玩家，不生成新玩家
                // 因为AIProfile和AI玩家是一一对应的，游戏过程中不产生新玩家
                if let rejoinedPlayer = findRejoinableAIPlayer(
                    players: players,
                    config: config,
                    profileId: profileId
                ) {
                    TournamentManager.replaceEliminatedPlayer(
                        at: seatIndex,
                        with: rejoinedPlayer,
                        players: &players
                    )
                    enteredPlayers.append(rejoinedPlayer)
                }
                // 如果没有可重新加入的玩家，不生成新玩家，直接跳过此空位
            }
        }

        return enteredPlayers
    }

    /// 检查并执行 AI 离场
    /// - 筹码 > maxBuyIn * 1.5 时 10% 概率离场
    /// - 筹码 < maxBuyIn * 0.3 时 20% 概率离场
    /// - 人类玩家不离场
    /// - 离场时将剩余筹码添加回 AI 的 bankroll
    /// - 同时将部分筹码放入系统池，供新玩家使用
    static func checkAIDepartures(
        players: inout [Player],
        config: CashGameConfig,
        profileId: String
    ) -> [Player] {
        var departedPlayers: [Player] = []

        for i in 0..<players.count {
            var player = players[i]

            // 人类玩家不离场
            guard !player.isHuman else { continue }

            // 只处理活跃状态的玩家
            guard player.status == .active else { continue }

            // 筹码 > maxBuyIn * 1.5 时 10% 概率离场
            if player.chips > config.maxBuyIn * 3 / 2 {
                #if DEBUG
                let shouldDepart = randomGenerator.randomBool(probability: 0.1)
                #else
                let shouldDepart = Double.random(in: 0...1) < 0.1
                #endif

                if shouldDepart {
                    // 将筹码放入系统池（而不是直接丢弃）
                    let departingChips = player.chips
                    
                    // 将剩余筹码添加回 AI 的 bankroll
                    if let aiProfileId = player.aiProfile?.id {
                        let _ = AIPlayerBankrollManager.shared.updateBankroll(
                            profileId: profileId,
                            aiProfileId: aiProfileId,
                            delta: departingChips
                        )
                    }
                    
                    // 修复：检查是否超过最大值，如果是则只添加最大可容纳的金额
                    let chipsToAdd = min(departingChips, maxSystemPoolSize - systemChipsPool)
                    systemChipsPool += chipsToAdd
                    let overflowChips = departingChips - chipsToAdd

                    player.chips = 0
                    players[i].chips = 0
                    players[i].status = .sittingOut
                    departedPlayers.append(player)
                }
            }
            // 筹码 < maxBuyIn * 0.3 时 20% 概率离场
            else if player.chips < config.maxBuyIn * 3 / 10 {
                #if DEBUG
                let shouldDepart = randomGenerator.randomBool(probability: 0.2)
                #else
                let shouldDepart = Double.random(in: 0...1) < 0.2
                #endif

                if shouldDepart {
                    // 将筹码放入系统池
                    let departingChips = player.chips
                    
                    // 将剩余筹码添加回 AI 的 bankroll
                    if let aiProfileId = player.aiProfile?.id {
                        let _ = AIPlayerBankrollManager.shared.updateBankroll(
                            profileId: profileId,
                            aiProfileId: aiProfileId,
                            delta: departingChips
                        )
                    }
                    
                    // 修复：检查是否超过最大值，如果是则只添加最大可容纳的金额
                    let chipsToAdd = min(departingChips, maxSystemPoolSize - systemChipsPool)
                    systemChipsPool += chipsToAdd
                    let overflowChips = departingChips - chipsToAdd

                    player.chips = 0
                    players[i].chips = 0
                    players[i].status = .sittingOut
                    departedPlayers.append(player)
                }
            }
        }

        return departedPlayers
    }
    
    /// 获取系统池中的可用筹码（用于新玩家买入）
    /// - Returns: 系统池中的筹码数量
    static func getSystemChips() -> Int {
        return systemChipsPool
    }
    
    /// 从系统池中取出指定数量的筹码
    /// - Parameter amount: 要取出的数量
    /// - Returns: 实际取出的数量
    static func drawSystemChips(amount: Int) -> Int {
        let drawn = min(amount, systemChipsPool)
        systemChipsPool -= drawn
        return drawn
    }
    
    // MARK: - AI Player Rejoin Logic
    
    /// 检查是否有可重新加入的 AI 玩家
    /// 优先尝试让之前离开的 AI 玩家重新加入
    /// - Parameters:
    ///   - players: 当前玩家列表
    ///   - config: 现金游戏配置
    /// - Returns: 可重新加入的 AI 玩家（如果有）
    static func findRejoinableAIPlayer(
        players: [Player],
        config: CashGameConfig,
        profileId: String
    ) -> Player? {
        let minBuyIn = config.bigBlind * 40
        
        // 遍历所有预设 AI 玩家，检查是否有 bankroll 且不在当前游戏中
        for profile in AIProfile.allPresets {
            let bankroll = AIPlayerBankrollManager.shared.getBankroll(
                profileId: profileId,
                aiProfileId: profile.id
            )
            
            // 检查资金是否足够买入
            guard bankroll >= minBuyIn else { continue }
            
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
            
            // 计算买入金额（不能超过 bankroll 和最大买入）
            let maxBuyIn = min(bankroll, config.maxBuyIn)
            let buyInAmount: Int
            if systemChipsPool >= minBuyIn {
                buyInAmount = drawSystemChips(amount: randomAIBuyIn(config: config))
            } else {
                buyInAmount = randomAIBuyIn(config: config)
            }
            let finalBuyIn = min(buyInAmount, maxBuyIn)
            
            // 从 bankroll 中扣除买入金额
            if let _ = AIPlayerBankrollManager.shared.deductBuyIn(
                profileId: profileId,
                aiProfileId: profile.id,
                buyInAmount: finalBuyIn
            ) {
                return Player(
                    name: profile.name,
                    chips: finalBuyIn,
                    isHuman: false,
                    aiProfile: profile,
                    entryIndex: entryIndex
                )
            }
        }
        
        return nil
    }
    
    /// 检查玩家资金是否足够加入现金游戏
    /// - Parameters:
    ///   - bankroll: 玩家当前资金
    ///   - config: 现金游戏配置
    /// - Returns: 验证是否通过
    static func validateBankrollForCashGame(bankroll: Int, config: CashGameConfig) -> Bool {
        let minBuyIn = config.bigBlind * 40
        return bankroll >= minBuyIn
    }
}
