import XCTest
@testable import TexasPoker

/// 验证功能测试 - 打印排名结果
final class AIVerificationIntegrationTests: XCTestCase {

    func testVerificationWithAllPlayers() {
        // 使用少量玩家进行快速测试
        let profiles = Array(AIProfile.allProfiles.prefix(6))
        print("\n========== 验证测试开始 ==========")
        print("玩家数量: \(profiles.count)")
        print("玩家列表: \(profiles.map { $0.name })")

        let engine = PokerEngineLite(profiles: profiles, startingChips: 1000, smallBlind: 10, bigBlind: 20)

        // 运行10手牌
        for hand in 1...10 {
            engine.runHand()
            let rankings = engine.getRankings()

            print("\n--- 第\(hand)手牌后排名 ---")
            for (index, player) in rankings.enumerated() {
                print("\(index + 1). \(player.name): \(player.chips) 筹码")
            }

            if rankings.count <= 1 {
                print("只剩下 \(rankings.count) 个玩家，提前结束")
                break
            }
        }

        // 最终排名
        let finalRankings = engine.getRankings()
        print("\n========== 最终排名 ==========")
        for (index, player) in finalRankings.enumerated() {
            print("\(index + 1). \(player.name): \(player.chips) 筹码")
        }

        XCTAssertGreaterThan(finalRankings.count, 0)
    }

    func testVerificationWithAll52Players() {
        // 测试所有52个玩家
        let profiles = AIProfile.allProfiles
        print("\n========== 52人验证测试开始 ==========")
        print("玩家数量: \(profiles.count)")

        let engine = PokerEngineLite(profiles: profiles, startingChips: 1000, smallBlind: 10, bigBlind: 20)

        // 运行5手牌
        for hand in 1...5 {
            engine.runHand()
            let rankings = engine.getRankings()

            print("\n--- 第\(hand)手牌后 (前10名) ---")
            for (index, player) in rankings.prefix(10).enumerated() {
                print("\(index + 1). \(player.name): \(player.chips) 筹码")
            }

            if rankings.count <= 1 {
                print("只剩下 \(rankings.count) 个玩家，提前结束")
                break
            }
        }

        // 最终排名
        let finalRankings = engine.getRankings()
        print("\n========== 最终前10名 ==========")
        for (index, player) in finalRankings.prefix(10).enumerated() {
            print("\(index + 1). \(player.name): \(player.chips) 筹码")
        }

        XCTAssertGreaterThan(finalRankings.count, 0)
    }
}
