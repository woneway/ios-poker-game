import XCTest
import Foundation
@testable import TexasPoker

/// 验证排名结果测试 - 文件输出版本
final class DirectPrintRankingTests: XCTestCase {

    func test52PlayersRankingPrint() {
        let profiles = AIProfile.allProfiles

        var output = """
        ============================================================
        52人AI验证排名测试
        ============================================================
        玩家数量: \(profiles.count)
        初始筹码: 1000
        盲注: 10/20
        手牌数: 30
        ============================================================

        """

        let engine = PokerEngineLite(profiles: profiles, startingChips: 1000, smallBlind: 10, bigBlind: 20)

        // 运行30手牌
        for hand in 1...30 {
            engine.runHand()
            let rankings = engine.getRankings()
            if rankings.count <= 1 {
                output += "\n第\(hand)手: 只剩 \(rankings.count) 个玩家，提前结束\n"
                break
            }
            if hand % 10 == 0 {
                output += "已运行 \(hand) 手牌...\n"
            }
        }

        // 获取最终排名
        let finalRankings = engine.getRankings()

        output += "\n============================================================\n"
        output += "前20名排名结果\n"
        output += "============================================================\n"

        for (index, player) in finalRankings.prefix(20).enumerated() {
            let medal = index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "  "
            output += "\(medal) \(index + 1). \(player.name): \(player.chips) 筹码\n"
        }

        if finalRankings.count > 20 {
            output += "\n... 还有 \(finalRankings.count - 20) 名玩家\n"
        }

        output += "\n============================================================\n"

        // 写入到固定路径
        let filePath = "/tmp/ranking_result.txt"
        do {
            try output.write(toFile: filePath, atomically: true, encoding: .utf8)
            NSLog("结果已写入: \(filePath)")
        } catch {
            NSLog("写入失败: \(error.localizedDescription)")
        }

        XCTAssertGreaterThan(finalRankings.count, 0)
    }
}
