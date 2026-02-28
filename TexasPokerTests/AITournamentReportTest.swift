import XCTest
@testable import TexasPoker

final class AITournamentReportTest: XCTestCase {

    func test52PlayerTournament() {
        let evaluator = AITournamentEvaluator(
            config: AITournamentEvaluator.TournamentConfig(
                playerCount: 52,
                games: 10,
                startingChips: 1000,
                maxHandsPerGame: 20
            )
        )

        print("\n" + String(repeating: "=", count: 70))
        print("🎰 52人AI牌手实力评估 - 使用真实PokerEngine")
        print("配置: 52人, 10场比赛, 初始1000筹码, 每场100手牌")
        print(String(repeating: "=", count: 70))

        let startTime = Date()
        let results = evaluator.runEvaluation()
        let elapsed = Date().timeIntervalSince(startTime)

        print("\n评估完成! 耗时: \(Int(elapsed))秒")

        let report = evaluator.generateReport(results: results)

        let reportPath = URL(fileURLWithPath: "/tmp/AI_Tournament_Report_52.txt")

        do {
            try report.write(to: reportPath, atomically: true, encoding: .utf8)
            print("\n✅ 报告已保存至: \(reportPath.path)")
        } catch {
            print("\n⚠️ 保存失败: \(error)")
        }

        print(report)
    }
}
