import XCTest
@testable import TexasPoker

/// 统计模块测试
final class StatisticsCalculatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 重置缓存
        StatisticsCache.shared.clear()
        LeaderboardCache.shared.clear()
    }

    override func tearDown() {
        super.tearDown()
        StatisticsCache.shared.clear()
        LeaderboardCache.shared.clear()
    }

    // MARK: - Statistics Cache Tests

    func testStatisticsCacheSetAndGet() {
        let cache = StatisticsCache.shared

        let stats = PlayerStats(
            playerName: "TestPlayer",
            gameMode: .cashGame,
            isHuman: true,
            totalHands: 100,
            vpip: 25.0,
            pfr: 20.0,
            af: 2.5,
            wtsd: 30.0,
            wsd: 55.0,
            threeBet: 8.0,
            handsWon: 45,
            totalWinnings: 1000,
            totalInvested: 500
        )

        cache.setStats(stats, for: "TestPlayer_cashGame_default")

        let retrieved = cache.getStats(for: "TestPlayer_cashGame_default")

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.playerName, "TestPlayer")
        XCTAssertEqual(retrieved?.totalHands, 100)
    }

    func testStatisticsCacheInvalidate() {
        let cache = StatisticsCache.shared

        let stats = PlayerStats(
            playerName: "TestPlayer",
            gameMode: .cashGame,
            isHuman: true,
            totalHands: 100,
            vpip: 25.0,
            pfr: 20.0,
            af: 2.5,
            wtsd: 30.0,
            wsd: 55.0,
            threeBet: 8.0,
            handsWon: 45,
            totalWinnings: 1000,
            totalInvested: 500
        )

        cache.setStats(stats, for: "TestPlayer_cashGame_default")
        cache.invalidate(key: "TestPlayer_cashGame_default")

        let retrieved = cache.getStats(for: "TestPlayer_cashGame_default")

        XCTAssertNil(retrieved)
    }

    func testStatisticsCacheClear() {
        let cache = StatisticsCache.shared

        let stats = PlayerStats(
            playerName: "TestPlayer",
            gameMode: .cashGame,
            isHuman: true,
            totalHands: 100,
            vpip: 25.0,
            pfr: 20.0,
            af: 2.5,
            wtsd: 30.0,
            wsd: 55.0,
            threeBet: 8.0,
            handsWon: 45,
            totalWinnings: 1000,
            totalInvested: 500
        )

        cache.setStats(stats, for: "TestPlayer1_cashGame_default")
        cache.setStats(stats, for: "TestPlayer2_cashGame_default")
        cache.clear()

        let retrieved1 = cache.getStats(for: "TestPlayer1_cashGame_default")
        let retrieved2 = cache.getStats(for: "TestPlayer2_cashGame_default")

        XCTAssertNil(retrieved1)
        XCTAssertNil(retrieved2)
    }

    // MARK: - Leaderboard Cache Tests

    func testLeaderboardCacheSetAndGet() {
        let cache = LeaderboardCache.shared

        let entries = [
            LeaderboardEntry(rank: 1, playerName: "Player1", totalHands: 100, winRate: 45.0, totalProfit: 1000),
            LeaderboardEntry(rank: 2, playerName: "Player2", totalHands: 80, winRate: 40.0, totalProfit: 500)
        ]

        cache.setEntries(entries, for: "cashGame_10")

        let retrieved = cache.getEntries(for: "cashGame_10")

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.count, 2)
        XCTAssertEqual(retrieved?.first?.playerName, "Player1")
    }

    func testLeaderboardCacheInvalidate() {
        let cache = LeaderboardCache.shared

        let entries = [
            LeaderboardEntry(rank: 1, playerName: "Player1", totalHands: 100, winRate: 45.0, totalProfit: 1000)
        ]

        cache.setEntries(entries, for: "cashGame_10")
        cache.invalidate(key: "cashGame_10")

        let retrieved = cache.getEntries(for: "cashGame_10")

        XCTAssertNil(retrieved)
    }

    // MARK: - LeaderboardEntry Tests

    func testLeaderboardEntryId() {
        let entry = LeaderboardEntry(rank: 1, playerName: "TestPlayer", totalHands: 100, winRate: 45.0, totalProfit: 1000)

        XCTAssertEqual(entry.id, "1-TestPlayer")
    }

    func testLeaderboardSorting() {
        let entries = [
            LeaderboardEntry(rank: 0, playerName: "Player3", totalHands: 50, winRate: 30.0, totalProfit: -100),
            LeaderboardEntry(rank: 0, playerName: "Player1", totalHands: 100, winRate: 45.0, totalProfit: 1000),
            LeaderboardEntry(rank: 0, playerName: "Player2", totalHands: 80, winRate: 40.0, totalProfit: 500)
        ]

        let sorted = entries.sorted { $0.totalProfit > $1.totalProfit }

        XCTAssertEqual(sorted[0].playerName, "Player1")
        XCTAssertEqual(sorted[1].playerName, "Player2")
        XCTAssertEqual(sorted[2].playerName, "Player3")
    }

    // MARK: - PlayerStats Tests

    func testPlayerStatsCreation() {
        let stats = PlayerStats(
            playerName: "TestPlayer",
            gameMode: .tournament,
            isHuman: false,
            totalHands: 50,
            vpip: 30.0,
            pfr: 25.0,
            af: 3.0,
            wtsd: 35.0,
            wsd: 60.0,
            threeBet: 10.0,
            handsWon: 20,
            totalWinnings: 500,
            totalInvested: 300
        )

        XCTAssertEqual(stats.playerName, "TestPlayer")
        XCTAssertEqual(stats.gameMode, .tournament)
        XCTAssertEqual(stats.isHuman, false)
        XCTAssertEqual(stats.totalHands, 50)
        XCTAssertEqual(stats.vpip, 30.0)
    }

    // MARK: - PlayerTendency Tests

    func testPlayerTendencyDescriptions() {
        XCTAssertEqual(PlayerTendency.lag.description, "松凶")
        XCTAssertEqual(PlayerTendency.tag.description, "紧凶")
        XCTAssertEqual(PlayerTendency.lpp.description, "紧弱")
        XCTAssertEqual(PlayerTendency.callingStation.description, "跟注站")
        XCTAssertEqual(PlayerTendency.nit.description, "岩石")
        XCTAssertEqual(PlayerTendency.abc.description, "标准型")
        XCTAssertEqual(PlayerTendency.unknown.description, "数据不足")
    }
}
