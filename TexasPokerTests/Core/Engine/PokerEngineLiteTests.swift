import XCTest
@testable import TexasPoker

final class PokerEngineLiteTests: XCTestCase {

    func testEngineCreation() {
        // 测试引擎创建
        let profiles = Array(AIProfile.allProfiles.prefix(3))
        let engine = PokerEngineLite(profiles: profiles, startingChips: 1000)

        XCTAssertEqual(engine.getRankings().count, 3)
        XCTAssertTrue(engine.getRankings().allSatisfy { $0.chips == 1000 })
    }

    func testRunHandCompletes() {
        // 测试runHand能够正常完成
        let profiles = Array(AIProfile.allProfiles.prefix(3))
        let engine = PokerEngineLite(profiles: profiles, startingChips: 1000)

        // 运行一手牌
        engine.runHand()

        // 验证手牌已结束
        XCTAssertTrue(engine.isHandOver)
    }

    func testMultipleHands() {
        // 测试多手牌
        let profiles = Array(AIProfile.allProfiles.prefix(3))
        let engine = PokerEngineLite(profiles: profiles, startingChips: 1000)

        for _ in 0..<10 {
            engine.runHand()
            XCTAssertTrue(engine.isHandOver)
        }

        // 验证仍有玩家有筹码
        let rankings = engine.getRankings()
        XCTAssertGreaterThan(rankings.count, 0)
    }

    func testAllInScenario() {
        // 测试allIn场景 - 这是之前导致问题的关键场景
        let profiles = Array(AIProfile.allProfiles.prefix(3))
        let engine = PokerEngineLite(profiles: profiles, startingChips: 100)

        // 运行多手牌直到有玩家破产
        var iterations = 0
        while iterations < 50 {
            engine.runHand()
            let rankings = engine.getRankings()
            if rankings.count <= 1 {
                break
            }
            iterations += 1
        }

        // 验证不会无限循环
        XCTAssertLessThan(iterations, 50)
    }

    func testSmallBlindAllIn() {
        // 测试小盲全下的场景
        let profiles = Array(AIProfile.allProfiles.prefix(2))
        let engine = PokerEngineLite(profiles: profiles, startingChips: 100, smallBlind: 10, bigBlind: 20)

        // 运行一手牌
        engine.runHand()

        XCTAssertTrue(engine.isHandOver)
    }

    func testVerificationScenario() {
        // 模拟验证场景
        let profiles = AIProfile.Difficulty.easy.availableProfiles
        guard profiles.count >= 2 else { return }

        let engine = PokerEngineLite(profiles: profiles, startingChips: 1000, smallBlind: 10, bigBlind: 20)

        // 运行50手牌
        for _ in 0..<50 {
            engine.runHand()
            let rankings = engine.getRankings()
            if rankings.count <= 1 {
                break
            }
        }

        // 验证没有无限循环
        let rankings = engine.getRankings()
        XCTAssertGreaterThan(rankings.count, 0)
    }

    func testAll52Players() {
        // 测试所有52个玩家的情况
        let profiles = AIProfile.allProfiles
        guard profiles.count >= 2 else { return }

        let engine = PokerEngineLite(profiles: profiles, startingChips: 1000, smallBlind: 10, bigBlind: 20)

        // 运行10手牌
        for _ in 0..<10 {
            engine.runHand()
            XCTAssertTrue(engine.isHandOver)
        }

        // 验证没有无限循环
        let rankings = engine.getRankings()
        XCTAssertGreaterThan(rankings.count, 0)
    }

    func testAllPlayersWithLowChips() {
        // 测试所有玩家筹码较低的情况
        let profiles = AIProfile.allProfiles
        guard profiles.count >= 2 else { return }

        let engine = PokerEngineLite(profiles: profiles, startingChips: 100, smallBlind: 10, bigBlind: 20)

        // 运行多手牌直到有人破产
        var iterations = 0
        while iterations < 100 {
            engine.runHand()
            let rankings = engine.getRankings()
            if rankings.count <= 1 {
                break
            }
            iterations += 1
        }

        // 验证不会无限循环
        XCTAssertLessThan(iterations, 100)
    }
}
