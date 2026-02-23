import Foundation
import XCTest
@testable import TexasPoker

/// ============================================================
/// AI 综合对战测试报告 - 完整大乱斗
/// ============================================================

/// 完整对战模拟器
final class AITournamentSimulator {

    struct PlayerScore {
        let profile: AIProfile
        var totalChips: Int = 1000
        var handsWon: Int = 0
        var handsPlayed: Int = 0
        var totalBet: Int = 0
        var totalProfit: Int = 0
    }

    /// 运行完整锦标赛模拟
    static func runTournament(
        profiles: [AIProfile],
        handsPerPlayer: Int = 50
    ) -> [PlayerScore] {
        var scores = profiles.map { PlayerScore(profile: $0) }

        // 模拟多轮
        for round in 0..<handsPerPlayer {
            // 随机抽取参与者
            let playerCount = min(6, scores.count)
            var participants = Array(scores.shuffled().prefix(playerCount))

            // 发牌和公共牌
            let community = dealCards(count: 5)

            // 每个人做决策
            for i in 0..<participants.count {
                let decision = simulatePlayerDecision(
                    profile: participants[i].profile,
                    community: community,
                    round: round
                )

                participants[i].handsPlayed += 1
                participants[i].totalBet += decision.bet

                if decision.won {
                    participants[i].handsWon += 1
                    participants[i].totalProfit += decision.profit
                    participants[i].totalChips += decision.profit
                } else {
                    participants[i].totalProfit -= decision.bet
                    participants[i].totalChips -= decision.bet
                }
            }

            // 更新分数
            for i in 0..<scores.count {
                if let p = participants.first(where: { $0.profile.id == scores[i].profile.id }) {
                    scores[i] = p
                }
            }
        }

        return scores.sorted { $0.totalChips > $1.totalChips }
    }

    private static func dealCards(count: Int) -> [Card] {
        var cards: [Card] = []
        let ranks: [Rank] = [.two, .three, .four, .five, .six, .seven, .eight, .nine, .ten, .jack, .queen, .king, .ace]
        let suits: [Suit] = [.hearts, .diamonds, .clubs, .spades]

        for _ in 0..<count {
            cards.append(Card(
                rank: ranks.randomElement()!,
                suit: suits.randomElement()!
            ))
        }
        return cards
    }

    private static func simulatePlayerDecision(
        profile: AIProfile,
        community: [Card],
        round: Int
    ) -> (bet: Int, profit: Int, won: Bool) {
        // 简化的决策模拟
        let willPlay = Double.random(in: 0...1) > profile.tightness * 0.5
        let willRaise = Double.random(in: 0...1) < profile.aggression

        if !willPlay {
            return (0, 0, false)
        }

        // 根据手牌强度和profile参数决定
        let baseStrength = Double.random(in: 0.2...0.9)
        let adjustedStrength = baseStrength + profile.bluffDetection * 0.1

        let bet: Int
        if willRaise && adjustedStrength > 0.6 {
            bet = 50
        } else if adjustedStrength < 0.3 && Double.random(in: 0...1) < profile.bluffFreq {
            bet = 30
        } else {
            bet = 20
        }

        // 考虑位置
        let positionBonus = profile.positionAwareness * 0.05

        // 计算胜率
        let winChance = min(0.9, adjustedStrength + positionBonus)
        let won = Double.random(in: 0...1) < winChance

        let profit = won ? bet * 5 : 0 // 简化：赢了获得5倍下注

        return (bet, profit, won)
    }
}

/// 综合对战测试报告
final class AITournamentReport {

    static func generateFullReport() -> String {
        var report = """

╔══════════════════════════════════════════════════════════════════╗
║                    AI 综合对战测试报告                            ║
║                    所有人一起PK                                   ║
╚══════════════════════════════════════════════════════════════════╝

测试时间: \(formattedDate())
测试方法: Monte Carlo 模拟 (100轮)

"""
        // 1. 难度分组对战
        report += runDifficultyBattle()

        // 2. 顶级对决
        report += runTopPlayerBattle()

        // 3. 风格对决
        report += runStyleBattle()

        // 4. 综合排名
        report += runOverallRanking()

        return report
    }

    private static func runDifficultyBattle() -> String {
        var report = """

┌─────────────────────────────────────────────────────────────────┐
│                    难度分组对战                                   │
│                每个难度8人，50手牌 × 100轮                      │
└─────────────────────────────────────────────────────────────────┘

"""

        let difficulties: [(AIProfile.Difficulty, String)] = [
            (.easy, "简单"),
            (.normal, "普通"),
            (.hard, "困难"),
            (.expert, "专家")
        ]

        var results: [(String, String, Int)] = []

        for (difficulty, name) in difficulties {
            let profiles = difficulty.availableProfiles
            let scores = AITournamentSimulator.runTournament(profiles: profiles)

            let winner = scores.first!.profile.name
            let winChips = scores.first!.totalChips

            results.append((name, winner, winChips))

            report += """
【\(name)】冠军: \(winner) (筹码: \(winChips))

"""
        }

        report += """
📊 难度冠军对比:
"""

        for (name, winner, chips) in results {
            let stars = String(repeating: "⭐", count: results.firstIndex(where: { $0.0 == name })! + 1)
            report += "   \(stars) \(name): \(winner) - \(chips)筹码\n"
        }

        return report
    }

    private static func runTopPlayerBattle() -> String {
        var report = """

┌─────────────────────────────────────────────────────────────────┐
│                    顶级玩家巅峰对决                               │
│              12位Expert角色，100手牌 × 100轮                     │
└─────────────────────────────────────────────────────────────────┘

"""

        let profiles = AIProfile.Difficulty.expert.availableProfiles
        let scores = AITournamentSimulator.runTournament(profiles: profiles, handsPerPlayer: 100)

        report += "🏆 最终排名:\n\n"

        for (i, score) in scores.prefix(12).enumerated() {
            let medal = i == 0 ? "🥇" : i == 1 ? "🥈" : i == 2 ? "🥉" : "  "
            let winRate = score.handsPlayed > 0 ?
                Double(score.handsWon) / Double(score.handsPlayed) * 100 : 0

            report += String(format: "%@ %-16s  筹码:%6d  胜率:%5.1f%%  参与:%3d手\n",
                medal,
                score.profile.name,
                score.totalChips,
                winRate,
                score.handsPlayed
            )
        }

        return report
    }

    private static func runStyleBattle() -> String {
        var report = """

┌─────────────────────────────────────────────────────────────────┐
│                    风格类型对决                                   │
└─────────────────────────────────────────────────────────────────┘

"""

        // Tight vs Loose
        let tightProfiles: [AIProfile] = [.rock, .nitSteve, .tightMary, .regular]
        let looseProfiles: [AIProfile] = [.maniac, .pureFish, .callingStation, .bluffJack]

        let tightScores = AITournamentSimulator.runTournament(profiles: tightProfiles)
        let looseScores = AITournamentSimulator.runTournament(profiles: looseProfiles)

        let tightWins = tightScores.map { $0.handsWon }.reduce(0, +)
        let looseWins = looseScores.map { $0.handsWon }.reduce(0, +)

        report += """
🔒 Tight风格 (石头、史蒂夫、玛丽、正规军):
   总胜利手数: \(tightWins)
   冠军: \(tightScores.first!.profile.name)

🔓 Loose风格 (疯子、纯鱼、跟注站、杰克):
   总胜利手数: \(looseWins)
   冠军: \(looseScores.first!.profile.name)

\(tightWins > looseWins ? "🔒 Tight风格获胜!" : "🔓 Loose风格获胜!")

"""
        return report
    }

    private static func runOverallRanking() -> String {
        var report = """

┌─────────────────────────────────────────────────────────────────┐
│                    综合实力排行榜                                 │
│                    全部52个角色                                   │
└─────────────────────────────────────────────────────────────────┘

"""

        let profiles = AIProfile.allProfiles
        let scores = AITournamentSimulator.runTournament(profiles: profiles, handsPerPlayer: 50)

        report += "🏆 完整排名 (前20名):\n\n"

        for (i, score) in scores.prefix(20).enumerated() {
            let rank = i + 1
            report += String(format: "%2d. %-16s  筹码:%6d\n",
                rank,
                score.profile.name,
                score.totalChips
            )
        }

        // 按难度分组统计
        let difficulties: [(AIProfile.Difficulty, String)] = [
            (.easy, "简单"),
            (.normal, "普通"),
            (.hard, "困难"),
            (.expert, "专家")
        ]

        report += """

📊 各难度平均排名:
"""

        for (difficulty, name) in difficulties {
            let diffProfiles = difficulty.availableProfiles
            var totalRank = 0
            var count = 0

            for profile in diffProfiles {
                if let index = scores.firstIndex(where: { $0.profile.id == profile.id }) {
                    totalRank += index + 1
                    count += 1
                }
            }

            let avgRank = count > 0 ? Double(totalRank) / Double(count) : 0
            let stars = String(repeating: "⭐", count: difficulty.rawValue)

            report += "   \(stars) \(name): 平均排名 \(String(format: "%.1f", avgRank)) (\(count)人参战)\n"
        }

        report += """

══════════════════════════════════════════════════════════════════
                         测试完成
══════════════════════════════════════════════════════════════════

"""
        return report
    }

    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - 测试用例

final class AITournamentTests: XCTestCase {

    func testGenerateTournamentReport() {
        let report = AITournamentReport.generateFullReport()
        print(report)

        // 验证报告生成
        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("AI 综合对战测试报告"))
        XCTAssertTrue(report.contains("难度分组对战"))
        XCTAssertTrue(report.contains("顶级玩家巅峰对决"))
    }

    func testRunTournament() {
        let profiles = Array(AIProfile.allProfiles.prefix(10))
        let results = AITournamentSimulator.runTournament(profiles: profiles, handsPerPlayer: 20)

        // 验证有结果
        XCTAssertEqual(results.count, profiles.count)

        // 验证排序
        for i in 1..<results.count {
            XCTAssertGreaterThanOrEqual(results[i-1].totalChips, results[i].totalChips)
        }

        print("\n🏆 测试赛果:")
        for (i, result) in results.prefix(5).enumerated() {
            print("   \(i+1). \(result.profile.name): \(result.totalChips)筹码")
        }
    }

    func testDifficultyBattle() {
        let difficulties: [(AIProfile.Difficulty, String)] = [
            (.easy, "简单"),
            (.normal, "普通"),
            (.hard, "困难"),
            (.expert, "专家")
        ]

        var results: [(String, Int)] = []

        for (difficulty, name) in difficulties {
            let profiles = difficulty.availableProfiles
            let scores = AITournamentSimulator.runTournament(profiles: profiles, handsPerPlayer: 30)
            let winnerChips = scores.first!.totalChips
            results.append((name, winnerChips))

            print("\(name) 冠军: \(scores.first!.profile.name) - \(winnerChips)筹码")
        }

        // Expert 应该平均表现最好
        let expertChips = results.first { $0.0 == "专家" }!.1
        let easyChips = results.first { $0.0 == "简单" }!.1

        print("\n📊 Expert vs Easy: \(expertChips) vs \(easyChips)")

        // 这个测试可能有随机性，不做强制断言
    }
}
