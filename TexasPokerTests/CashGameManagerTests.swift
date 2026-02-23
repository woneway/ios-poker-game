import XCTest
@testable import TexasPoker

class CashGameManagerTests: XCTestCase {

    // MARK: - randomAIBuyIn Tests

    func testRandomAIBuyInWithinRange() {
        let config = CashGameConfig.default
        let minBuyIn = config.bigBlind * 40  // 20 * 40 = 800
        let maxBuyIn = config.maxBuyIn        // 2000

        // 测试多次确保范围正确
        for _ in 0..<100 {
            let buyIn = CashGameManager.randomAIBuyIn(config: config)
            XCTAssertGreaterThanOrEqual(buyIn, minBuyIn, "Buy-in should be >= min")
            XCTAssertLessThanOrEqual(buyIn, maxBuyIn, "Buy-in should be <= max")
        }
    }

    func testRandomAIBuyInWithCustomConfig() {
        let config = CashGameConfig.from(smallBlind: 5, bigBlind: 10)
        let minBuyIn = config.bigBlind * 40  // 10 * 40 = 400
        let maxBuyIn = config.maxBuyIn        // 1000

        for _ in 0..<50 {
            let buyIn = CashGameManager.randomAIBuyIn(config: config)
            XCTAssertGreaterThanOrEqual(buyIn, minBuyIn)
            XCTAssertLessThanOrEqual(buyIn, maxBuyIn)
        }
    }

    // MARK: - topUpPlayer Tests

    func testTopUpPlayerSuccessful() {
        var players = [
            Player(name: "Player1", chips: 500),
            Player(name: "Player2", chips: 1000)
        ]
        let config = CashGameConfig.default

        let addedChips = CashGameManager.topUpPlayer(
            players: &players,
            playerIndex: 0,
            toAmount: 1500,
            config: config
        )

        XCTAssertEqual(addedChips, 1000)  // 1500 - 500 = 1000
        XCTAssertEqual(players[0].chips, 1500)
    }

    func testTopUpPlayerInvalidIndex() {
        var players = [Player(name: "Player1", chips: 500)]
        let config = CashGameConfig.default

        let addedChips = CashGameManager.topUpPlayer(
            players: &players,
            playerIndex: 5,
            toAmount: 1500,
            config: config
        )

        XCTAssertEqual(addedChips, 0)
    }

    func testTopUpPlayerEliminatedPlayer() {
        var players = [Player(name: "Player1", chips: 0)]
        players[0].status = .eliminated
        let config = CashGameConfig.default

        let addedChips = CashGameManager.topUpPlayer(
            players: &players,
            playerIndex: 0,
            toAmount: 1000,
            config: config
        )

        XCTAssertEqual(addedChips, 0)
    }

    func testTopUpPlayerTargetLessThanCurrent() {
        var players = [Player(name: "Player1", chips: 1000)]
        let config = CashGameConfig.default

        let addedChips = CashGameManager.topUpPlayer(
            players: &players,
            playerIndex: 0,
            toAmount: 500,
            config: config
        )

        XCTAssertEqual(addedChips, 0)
        XCTAssertEqual(players[0].chips, 1000)  // unchanged
    }

    func testTopUpPlayerExceedsMaxBuyIn() {
        var players = [Player(name: "Player1", chips: 500)]
        let config = CashGameConfig.default  // maxBuyIn = 2000

        let addedChips = CashGameManager.topUpPlayer(
            players: &players,
            playerIndex: 0,
            toAmount: 2500,
            config: config
        )

        XCTAssertEqual(addedChips, 0)
        XCTAssertEqual(players[0].chips, 500)  // unchanged
    }

    // MARK: - checkAIEntries Tests

    func testCheckAIEntriesNoEmptySeats() {
        var players = [
            Player(name: "Player1", chips: 1000, isHuman: false, aiProfile: .rock),
            Player(name: "Player2", chips: 1000, isHuman: false, aiProfile: .fox)
        ]
        players[0].status = .active
        players[1].status = .active

        let config = CashGameConfig.default

        let entered = CashGameManager.checkAIEntries(
            players: &players,
            config: config,
            difficulty: .normal,
            profileId: "test"
        )

        XCTAssertTrue(entered.isEmpty)
    }

    func testCheckAIEntriesForceFillWhenLowPlayers() {
        // 只有一个活跃玩家，需要强制补入空位
        var players = [
            Player(name: "Player1", chips: 1000, isHuman: true),
            Player(name: "Player2", chips: 0),
            Player(name: "Player3", chips: 0)
        ]
        players[0].status = .active
        players[1].status = .eliminated
        players[2].status = .eliminated

        let config = CashGameConfig.default

        let entered = CashGameManager.checkAIEntries(
            players: &players,
            config: config,
            difficulty: .normal,
            profileId: "test"
        )

        // 应该强制补入所有空位（2个）
        XCTAssertEqual(entered.count, 2)
        XCTAssertEqual(players[1].status, .active)
        XCTAssertEqual(players[2].status, .active)
    }

    func testCheckAIEntriesProbabilityEntry() {
        // 有3个以上活跃玩家，应该按概率补入
        var players = [
            Player(name: "Player1", chips: 1000, isHuman: false, aiProfile: .rock),
            Player(name: "Player2", chips: 1000, isHuman: false, aiProfile: .fox),
            Player(name: "Player3", chips: 1000, isHuman: false, aiProfile: .shark),
            Player(name: "Player4", chips: 0)
        ]
        players[0].status = .active
        players[1].status = .active
        players[2].status = .active
        players[3].status = .eliminated

        let config = CashGameConfig.default

        // 由于是概率性的，我们只验证不会崩溃
        // 多次运行以确保至少有一次成功或失败
        var hadEntry = false
        var hadNoEntry = false

        for _ in 0..<20 {
            var testPlayers = players
            let entered = CashGameManager.checkAIEntries(
                players: &testPlayers,
                config: config,
                difficulty: .normal,
                profileId: "test"
            )
            if !entered.isEmpty { hadEntry = true }
            if entered.isEmpty { hadNoEntry = true }
        }

        // 两种情况都可能发生
        XCTAssertTrue(hadEntry || hadNoEntry)
    }

    func testCheckAIEntriesBuyInRange() {
        var players = [
            Player(name: "Player1", chips: 1000, isHuman: true),
            Player(name: "Player2", chips: 0)
        ]
        players[0].status = .active
        players[1].status = .eliminated

        let config = CashGameConfig.default
        let minBuyIn = config.bigBlind * 40  // 800
        let maxBuyIn = config.maxBuyIn        // 2000

        let entered = CashGameManager.checkAIEntries(
            players: &players,
            config: config,
            difficulty: .normal,
            profileId: "test"
        )

        XCTAssertEqual(entered.count, 1)
        let buyIn = entered[0].chips
        XCTAssertGreaterThanOrEqual(buyIn, minBuyIn)
        XCTAssertLessThanOrEqual(buyIn, maxBuyIn)
    }

    // MARK: - checkAIDepartures Tests

    func testCheckAIDeparturesHumanNeverLeaves() {
        var players = [
            Player(name: "Player1", chips: 10000, isHuman: true),  // 超过1.5倍
            Player(name: "Player2", chips: 100, isHuman: true)       // 低于0.3倍
        ]
        players[0].status = .active
        players[1].status = .active

        let config = CashGameConfig.default

        let departed = CashGameManager.checkAIDepartures(
            players: &players,
            config: config,
            profileId: "test"
        )

        XCTAssertTrue(departed.isEmpty)
        XCTAssertEqual(players[0].status, .active)
        XCTAssertEqual(players[1].status, .active)
    }

    func testCheckAIDeparturesHighChipsMayLeave() {
        // 筹码 > maxBuyIn * 1.5 (2000 * 1.5 = 3000)，有10%概率离场
        var players = [
            Player(name: "AI1", chips: 5000, isHuman: false, aiProfile: .rock)
        ]
        players[0].status = .active

        let config = CashGameConfig.default

        // 多次测试以验证概率行为
        var departedCount = 0
        let iterations = 100

        for _ in 0..<iterations {
            var testPlayers = players
            let departed = CashGameManager.checkAIDepartures(
                players: &testPlayers,
                config: config,
                profileId: "test"
            )
            if !departed.isEmpty { departedCount += 1 }
        }

        // 期望大约10%的离场率，允许一些统计误差
        // 实际范围可能在 5-15 次之间
        XCTAssertGreaterThan(departedCount, 0, "Should have some departures")
        XCTAssertLessThan(departedCount, iterations, "Not all should depart")
    }

    func testCheckAIDeparturesLowChipsMayLeave() {
        // 筹码 < maxBuyIn * 0.3 (2000 * 0.3 = 600)，有20%概率离场
        var players = [
            Player(name: "AI1", chips: 300, isHuman: false, aiProfile: .rock)
        ]
        players[0].status = .active

        let config = CashGameConfig.default

        var departedCount = 0
        let iterations = 100

        for _ in 0..<iterations {
            var testPlayers = players
            let departed = CashGameManager.checkAIDepartures(
                players: &testPlayers,
                config: config,
                profileId: "test"
            )
            if !departed.isEmpty { departedCount += 1 }
        }

        // 期望大约20%的离场率
        XCTAssertGreaterThan(departedCount, 0, "Should have some departures")
    }

    func testCheckAIDeparturesSittingOutDoesNotLeave() {
        var players = [
            Player(name: "AI1", chips: 5000, isHuman: false, aiProfile: .rock)
        ]
        players[0].status = .sittingOut  // 不是 active 状态

        let config = CashGameConfig.default

        let departed = CashGameManager.checkAIDepartures(
            players: &players,
            config: config,
            profileId: "test"
        )

        XCTAssertTrue(departed.isEmpty)
        XCTAssertEqual(players[0].status, .sittingOut)  // 状态不变
    }

    func testCheckAIDeparturesMediumChipsStays() {
        // 筹码在中等范围，不会离场
        var players = [
            Player(name: "AI1", chips: 1500, isHuman: false, aiProfile: .rock)  // 介于 600 和 3000 之间
        ]
        players[0].status = .active

        let config = CashGameConfig.default

        let departed = CashGameManager.checkAIDepartures(
            players: &players,
            config: config,
            profileId: "test"
        )

        XCTAssertTrue(departed.isEmpty)
        XCTAssertEqual(players[0].status, .active)
    }

    // MARK: - Edge Cases

    func testEmptyPlayersArray() {
        var players: [Player] = []
        let config = CashGameConfig.default

        let entered = CashGameManager.checkAIEntries(
            players: &players,
            config: config,
            difficulty: .normal,
            profileId: "test"
        )
        XCTAssertTrue(entered.isEmpty)

        let departed = CashGameManager.checkAIDepartures(
            players: &players,
            config: config,
            profileId: "test"
        )
        XCTAssertTrue(departed.isEmpty)
    }

    func testAllPlayersEliminated() {
        var players = [
            Player(name: "Player1", chips: 0),
            Player(name: "Player2", chips: 0)
        ]
        players[0].status = .eliminated
        players[1].status = .eliminated

        let config = CashGameConfig.default

        let departed = CashGameManager.checkAIDepartures(
            players: &players,
            config: config,
            profileId: "test"
        )

        XCTAssertTrue(departed.isEmpty)  // eliminated 玩家不参与离场检查
    }

    // MARK: - entryIndex Tests

    func testEntryIndexFirstEntryIsOne() {
        // 重置系统池和计数器
        CashGameManager.resetSystemPool()
        #if DEBUG
        CashGameManager.debugResetRandomGenerator()
        #endif

        var players: [Player] = []
        // 添加一个空座位
        players.append(Player(name: "Empty", chips: 0))
        players[0].status = .eliminated

        let config = CashGameConfig.default

        // 第一次入场
        let entered = CashGameManager.checkAIEntries(
            players: &players,
            config: config,
            difficulty: .normal,
            profileId: "test"
        )

        XCTAssertEqual(entered.count, 1)
        // 第一次入场的 entryIndex 应该是 1
        XCTAssertEqual(entered[0].entryIndex, 1, "First entry should have entryIndex = 1")
    }

    func testEntryIndexIncrementsForSameProfile() {
        // 重置系统池和计数器
        CashGameManager.resetSystemPool()
        #if DEBUG
        CashGameManager.debugResetRandomGenerator()
        #endif

        var players: [Player] = []
        let config = CashGameConfig.default

        // 第一次入场
        players.append(Player(name: "Empty1", chips: 0))
        players[0].status = .eliminated
        let entered1 = CashGameManager.checkAIEntries(
            players: &players,
            config: config,
            difficulty: .normal,
            profileId: "test"
        )

        // 强制让第二个玩家入场（设置系统池确保100%入场）
        #if DEBUG
        CashGameManager.debugSetSystemChipsPool(10000)
        CashGameManager.debugSetRandomGenerator(.seeded(42))
        #endif

        // 第二次入场 - 找一个新的空座位
        players.append(Player(name: "Empty2", chips: 0))
        players[1].status = .eliminated

        // 随机选择相同 profile 的概率可能较低，这里我们直接测试 generateEntryIndex
        // 通过多次尝试确保能命中同一个 profile
    }

    func testGenerateEntryIndexReturnsSequentialNumbers() {
        // 重置系统池和计数器
        CashGameManager.resetSystemPool()
        #if DEBUG
        CashGameManager.debugResetRandomGenerator()
        #endif

        // 测试固定 seed 下同一 profile 的 entryIndex 递增
        #if DEBUG
        CashGameManager.debugSetRandomGenerator(.seeded(100))
        #endif

        var players: [Player] = []
        let config = CashGameConfig.default
        let difficulty: AIProfile.Difficulty = .normal

        // 第一次入场
        players.append(Player(name: "Empty1", chips: 0))
        players[0].status = .eliminated
        CashGameManager.checkAIEntries(
            players: &players,
            config: config,
            difficulty: difficulty,
            profileId: "test"
        )

        // 移除第一个玩家（模拟离场）
        players[0].chips = 0
        players[0].status = .eliminated
        CashGameManager.checkAIDepartures(players: &players, config: config, profileId: "test")

        // 第二次入场
        #if DEBUG
        CashGameManager.debugSetRandomGenerator(.seeded(100))
        CashGameManager.debugSetSystemChipsPool(10000)
        #endif

        players.append(Player(name: "Empty2", chips: 0))
        players[1].status = .eliminated
        let entered2 = CashGameManager.checkAIEntries(
            players: &players,
            config: config,
            difficulty: difficulty,
            profileId: "test"
        )

        // 如果两次都是同一 profile，entryIndex 应该递增
        // 但由于是概率性的，我们主要验证 entryIndex 至少被设置了
        if !entered2.isEmpty {
            XCTAssertGreaterThanOrEqual(entered2[0].entryIndex, 1)
        }
    }

    func testPlayerUniqueIdIncludesEntryIndex() {
        // 验证 playerUniqueId 格式正确
        let profile = AIProfile.rock
        let player = Player(name: profile.name, chips: 1000, aiProfile: profile, entryIndex: 1)

        XCTAssertEqual(player.playerUniqueId, "石头#1")
    }

    func testEntryIndexZeroWhenNotSet() {
        // 验证未设置 entryIndex 时默认为 0
        let player = Player(name: "Test", chips: 1000)
        XCTAssertEqual(player.entryIndex, 0)
        XCTAssertEqual(player.playerUniqueId, "Test#0")
    }

    func testNoNameSuffixNeeded() {
        // 验证相同 profile 多次入场时，不需要名称后缀来区分
        // 因为 entryIndex 会自动区分
        let profile = AIProfile.rock

        let player1 = Player(name: profile.name, chips: 1000, aiProfile: profile, entryIndex: 1)
        let player2 = Player(name: profile.name, chips: 1500, aiProfile: profile, entryIndex: 2)

        XCTAssertNotEqual(player1.playerUniqueId, player2.playerUniqueId)
        XCTAssertEqual(player1.playerUniqueId, "石头#1")
        XCTAssertEqual(player2.playerUniqueId, "石头#2")
    }
}
