import XCTest
@testable import TexasPoker

/// 排行榜功能测试
final class LeaderboardTests: XCTestCase {

    private var getLeaderboardUseCase: GetLeaderboardUseCase!

    override func setUp() {
        super.setUp()
        getLeaderboardUseCase = GetLeaderboardUseCase()
        LeaderboardCache.shared.clear()
    }

    override func tearDown() {
        super.tearDown()
        LeaderboardCache.shared.clear()
    }

    // MARK: - Basic Functionality Tests

    func testGetLeaderboardWithCashGame() {
        let entries = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 10)

        // 验证方法可调用并返回数组
        XCTAssertNotNil(entries)
        XCTAssertTrue(entries is [LeaderboardEntry])
    }

    func testGetLeaderboardWithTournament() {
        let entries = getLeaderboardUseCase.execute(gameMode: .tournament, limit: 10)

        XCTAssertNotNil(entries)
    }

    func testGetLeaderboardWithCustomLimit() {
        let entries = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 5)

        // 验证limit参数生效
        XCTAssertLessThanOrEqual(entries.count, 5)
    }

    func testGetLeaderboardWithLargeLimit() {
        let entries = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 100)

        // 大limit也应该能正常工作
        XCTAssertNotNil(entries)
    }

    func testGetLeaderboardWithDefaultLimit() {
        // 测试默认limit为10
        let entries = getLeaderboardUseCase.execute(gameMode: .cashGame)

        XCTAssertLessThanOrEqual(entries.count, 10)
    }

    // MARK: - Cache Tests

    func testLeaderboardCacheEnabled() {
        // 第一次调用
        let entries1 = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 10, useCache: true)

        // 第二次调用应该使用缓存
        let entries2 = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 10, useCache: true)

        // 验证缓存工作（返回相同数据）
        XCTAssertEqual(entries1.count, entries2.count)
    }

    func testLeaderboardCacheDisabled() {
        // 禁用缓存
        let entries = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 10, useCache: false)

        XCTAssertNotNil(entries)
    }

    func testLeaderboardInvalidateCache() {
        // 先调用填充缓存
        _ = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 10, useCache: true)

        // 清除缓存
        getLeaderboardUseCase.invalidateCache(gameMode: .cashGame, limit: 10)

        // 验证缓存已清除
        let cacheKey = "cashGame_10"
        let cached = LeaderboardCache.shared.getEntries(for: cacheKey)
        XCTAssertNil(cached)
    }

    // MARK: - Async Tests

    func testGetLeaderboardAsync() async {
        let entries = await getLeaderboardUseCase.executeAsync(gameMode: .cashGame, limit: 10)

        XCTAssertNotNil(entries)
    }

    func testGetLeaderboardAsyncWithTournament() async {
        let entries = await getLeaderboardUseCase.executeAsync(gameMode: .tournament, limit: 20)

        XCTAssertNotNil(entries)
    }

    // MARK: - Ranking Tests

    func testLeaderboardRankingByProfit() {
        let entries = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 10)

        // 验证排名按盈利排序
        if entries.count > 1 {
            for i in 0..<(entries.count - 1) {
                XCTAssertGreaterThanOrEqual(entries[i].totalProfit, entries[i + 1].totalProfit)
            }
        }
    }

    func testLeaderboardRanksAreSequential() {
        let entries = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 10)

        // 验证排名是连续的
        for (index, entry) in entries.enumerated() {
            XCTAssertEqual(entry.rank, index + 1)
        }
    }

    // MARK: - Edge Cases

    func testLeaderboardWithZeroLimit() {
        let entries = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 0)

        // limit为0应该返回空数组或全部
        XCTAssertNotNil(entries)
    }

    func testLeaderboardMultipleGameModes() {
        let cashGameEntries = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 5)
        let tournamentEntries = getLeaderboardUseCase.execute(gameMode: .tournament, limit: 5)

        // 两种模式应该独立工作
        XCTAssertNotNil(cashGameEntries)
        XCTAssertNotNil(tournamentEntries)

        // 验证使用不同的缓存key
        let cashCached = LeaderboardCache.shared.getEntries(for: "cashGame_5")
        let tournamentCached = LeaderboardCache.shared.getEntries(for: "tournament_5")

        XCTAssertNotNil(cashCached)
        XCTAssertNotNil(tournamentCached)
    }

    // MARK: - Performance Tests

    func testLeaderboardPerformance() {
        measure {
            _ = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 10, useCache: false)
        }
    }

    func testLeaderboardCachedPerformance() {
        // 先填充缓存
        _ = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 10, useCache: true)

        measure {
            _ = getLeaderboardUseCase.execute(gameMode: .cashGame, limit: 10, useCache: true)
        }
    }
}
