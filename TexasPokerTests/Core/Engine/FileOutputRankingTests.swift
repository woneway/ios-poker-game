import XCTest
import os.log
@testable import TexasPoker

/// 验证排名结果测试 - 写入文件版本
final class FileOutputRankingTests: XCTestCase {

    func testAll52PlayersRankingToFile() {
        let profiles = AIProfile.allProfiles

        let sep = String(repeating: "=", count: 60)
        var output = ""
        output += "\n" + sep + "\n"
        output += "52人AI验证排名测试\n"
        output += sep + "\n"
        output += "玩家数量: \(profiles.count)\n"
        output += "初始筹码: 1000\n"
        output += "盲注: 10/20\n"
        output += "手牌数: 30\n"
        output += sep + "\n"

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

        output += "\n" + sep + "\n"
        output += "前20名排名结果\n"
        output += sep + "\n"

        for (index, player) in finalRankings.prefix(20).enumerated() {
            let medal = index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "  "
            output += "\(medal) \(index + 1). \(player.name): \(player.chips) 筹码\n"
        }

        if finalRankings.count > 20 {
            output += "\n... 还有 \(finalRankings.count - 20) 名玩家\n"
        }

        output += "\n" + sep + "\n"

        // 使用os_log输出到系统日志
        os_log("%{public}@", log: .default, type: .info, output)

        // 写入文件
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("verification_ranking.txt")

        do {
            try output.write(to: fileURL, atomically: true, encoding: .utf8)
            os_log("文件已写入: %{public}@", log: .default, type: .info, fileURL.path)
        } catch {
            os_log("写入文件失败: %{public}@", log: .default, type: .error, error.localizedDescription)
        }

        XCTAssertGreaterThan(finalRankings.count, 0)
    }
}
