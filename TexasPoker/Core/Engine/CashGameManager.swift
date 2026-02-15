import Foundation
import Random

/// 管理现金游戏（Cash Game）的核心逻辑
/// 包括 AI 买入、补码、入场和离场管理
struct CashGameManager {

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
                var rng = SeededRandomNumberGenerator(seed: seed)
                return Int.random(in: range, using: &rng)
            }
        }

        func randomBool(probability: Double) -> Bool {
            switch self {
            case .system:
                return Double.random(in: 0...1) < probability
            case .seeded(let seed):
                var rng = SeededRandomNumberGenerator(seed: seed)
                return Double.random(in: 0...1, using: &rng) < probability
            }
        }

        func randomElement<T>(from array: [T]) -> T? {
            switch self {
            case .system:
                return array.randomElement()
            case .seeded(let seed):
                var rng = SeededRandomNumberGenerator(seed: seed)
                return array.randomElement(using: &rng)
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

        #if DEBUG
        print("🔄 CashGameManager 系统池已重置")
        #endif
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
    #endif

    // MARK: - AI 入场（概率驱动）

    /// 检查并执行 AI 入场
    /// - 每个空位独立按 50% 概率补入
    /// - 活跃玩家 < 3 时强制补入
    /// - 优先使用系统池中的筹码，保持经济平衡
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
            #if DEBUG
            let shouldEnter = shouldForceFill || randomGenerator.randomBool(probability: 0.5)
            #else
            let shouldEnter = shouldForceFill || Double.random(in: 0...1) < 0.5
            #endif

            if shouldEnter {
                // 计算买入金额：优先使用系统池，其次随机生成
                var buyInAmount: Int
                let minBuyIn = config.bigBlind * 40
                
                if systemChipsPool >= minBuyIn {
                    // 系统池有足够筹码，使用系统池
                    buyInAmount = drawSystemChips(amount: randomAIBuyIn(config: config))
                } else if systemChipsPool > 0 {
                    // 系统池部分筹码，不够的补齐
                    let systemChips = systemChipsPool
                    let neededChips = randomAIBuyIn(config: config) - systemChips
                    drawSystemChips(amount: systemChips)  // 清空系统池
                    buyInAmount = systemChips + neededChips
                } else {
                    // 系统池为空，使用随机金额
                    buyInAmount = randomAIBuyIn(config: config)
                }

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
                    
                    #if DEBUG
                    print("🎰 新玩家 \(newPlayer.name) 入场，买入 $\(buyInAmount)，系统池剩余 $\(systemChipsPool)")
                    #endif
                }
            }
        }

        return enteredPlayers
    }

    // MARK: - AI 离场

    /// 全局系统池，存储离场 AI 的筹码，用于新 AI 入场时循环使用
    /// 这样可以保持游戏中总筹码量的平衡
    private static var systemChipsPool: Int = 0
    
    /// 芯片池最大容量（防止无限积累）
    private static let maxSystemPoolSize = 100000
    
    /// 检查并执行 AI 离场
    /// - 筹码 > maxBuyIn * 1.5 时 10% 概率离场
    /// - 筹码 < maxBuyIn * 0.3 时 20% 概率离场
    /// - 人类玩家不离场
    /// - 离场时筹码放入系统池，供新玩家使用
    static func checkAIDepartures(
        players: inout [Player],
        config: CashGameConfig
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
                    if systemChipsPool < maxSystemPoolSize {
                        systemChipsPool += departingChips
                    }
                    
                    player.chips = 0
                    players[i].chips = 0
                    players[i].status = .sittingOut
                    departedPlayers.append(player)
                    
                    #if DEBUG
                    print("💰 \(player.name) 离场，回收筹码 $\(departingChips)，系统池总计 $\(systemChipsPool)")
                    #endif
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
                    if systemChipsPool < maxSystemPoolSize {
                        systemChipsPool += departingChips
                    }
                    
                    player.chips = 0
                    players[i].chips = 0
                    players[i].status = .sittingOut
                    departedPlayers.append(player)
                    
                    #if DEBUG
                    print("💰 \(player.name) 离场（输光），回收筹码 $\(departingChips)，系统池总计 $\(systemChipsPool)")
                    #endif
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

    // MARK: - Private Helpers

    /// 生成随机 AI 玩家（现金游戏版本）
    private static func generateRandomAIPlayer(
        difficulty: AIProfile.Difficulty,
        buyInAmount: Int,
        existingNames: Set<String>
    ) -> Player? {
        #if DEBUG
        let profile = randomGenerator.randomElement(from: difficulty.availableProfiles) ?? .fox
        #else
        let profile = difficulty.availableProfiles.randomElement() ?? .fox
        #endif

        // 处理名称去重：使用existingNames进行去重（已包含所有现有玩家名称）
        var finalName = profile.name
        var counter = 2
        while existingNames.contains(finalName) {
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
    /// 注意：由于是静态方法无法直接访问外部players变量，
    /// 名称去重主要通过existingNames参数在调用处处理
    private static func playersContainName(_ name: String, in players: [Player]) -> Bool {
        return players.contains { $0.name == name }
    }
}
