import XCTest
@testable import TexasPoker

/// 验证排名结果测试
final class VerificationRankingTests: XCTestCase {

    func testFullVerificationRanking() {
        // 使用少量玩家快速测试
        let profiles = Array(AIProfile.allProfiles.prefix(10))

        let sep = String(repeating: "=", count: 60)
        print("\n" + sep)
        print("AI验证排名测试")
        print(sep)
        print("玩家数量: \(profiles.count)")
        print("初始筹码: 1000")
        print("盲注: 10/20")
        print("手牌数: 50")
        print(sep)

        let engine = PokerEngineLite(profiles: profiles, startingChips: 1000, smallBlind: 10, bigBlind: 20)

        // 运行50手牌
        for hand in 1...50 {
            engine.runHand()
            let rankings = engine.getRankings()
            if rankings.count <= 1 {
                print("\n第\(hand)手: 只剩 \(rankings.count) 个玩家，提前结束")
                break
            }
            if hand % 10 == 0 {
                print("已运行 \(hand) 手牌...")
            }
        }

        // 获取最终排名
        let finalRankings = engine.getRankings()

        print("\n" + sep)
        print("最终排名结果")
        print(sep)

        for (index, player) in finalRankings.enumerated() {
            let medal = index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "  "
            print("\(medal) \(index + 1). \(player.name): \(player.chips) 筹码")
        }

        print("\n" + sep)

        XCTAssertGreaterThan(finalRankings.count, 0)
    }

    func testAll52PlayersRanking() {
        let profiles = AIProfile.allProfiles

        let sep = String(repeating: "=", count: 60)
        print("\n" + sep)
        print("52人AI验证排名测试")
        print(sep)
        print("玩家数量: \(profiles.count)")
        print("初始筹码: 1000")
        print("盲注: 10/20")
        print("手牌数: 30")
        print(sep)

        let engine = PokerEngineLite(profiles: profiles, startingChips: 1000, smallBlind: 10, bigBlind: 20)

        // 运行30手牌
        for hand in 1...30 {
            engine.runHand()
            let rankings = engine.getRankings()
            if rankings.count <= 1 {
                print("\n第\(hand)手: 只剩 \(rankings.count) 个玩家，提前结束")
                break
            }
            if hand % 10 == 0 {
                print("已运行 \(hand) 手牌...")
            }
        }

        // 获取最终排名
        let finalRankings = engine.getRankings()

        print("\n" + sep)
        print("前20名排名结果")
        print(sep)

        for (index, player) in finalRankings.prefix(20).enumerated() {
            let medal = index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "  "
            print("\(medal) \(index + 1). \(player.name): \(player.chips) 筹码")
        }

        if finalRankings.count > 20 {
            print("\n... 还有 \(finalRankings.count - 20) 名玩家")
        }

        print("\n" + sep)

        XCTAssertGreaterThan(finalRankings.count, 0)
    }
}
