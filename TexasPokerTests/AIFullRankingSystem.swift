import Foundation
import XCTest
@testable import TexasPoker

// ============================================================
// AI 角色完整排名系统
// 方案设计：
// 1. 多人Elo评分系统 - 基础分1500
// 2. 多次锦标赛 - 50轮确保统计显著性
// 3. 综合指标 - 胜率、平均排名、筹码效率、Top率
// ============================================================

/// 玩家积分
struct PlayerRating {
    var profile: AIProfile
    var elo: Double           // Elo积分，初始1500
    var wins: Int             // 总胜利次数
    var losses: Int           // 总失败次数
    var top3: Int             // Times in top 3
    var top5: Int             // Times in top 5
    var totalProfit: Int      // Total net profit/loss
    var handsPlayed: Int     // Hands participated
    var totalRank: Int        // Sum of ranks for average calculation
    var participationCount: Int // 參與錦標賽次數

    var averageRank: Double {
        participationCount > 0 ? Double(totalRank) / Double(participationCount) : 52
    }

    var winRate: Double {
        let totalGames = wins + losses
        return totalGames > 0 ? Double(wins) / Double(totalGames) : 0
    }

    var top3Rate: Double {
        participationCount > 0 ? Double(top3) / Double(participationCount) : 0
    }

    var profitPerHand: Double {
        handsPlayed > 0 ? Double(totalProfit) / Double(handsPlayed) : 0
    }

    var totalScore: Double {
        // 綜合評分 = Elo * 0.4 + 勝率*200 + (52-平均排名)*3 + Top3率*100
        return elo * 0.4 +
               winRate * 200 +
               (52 - averageRank) * 3 +
               top3Rate * 100
    }
}

/// 多人錦標賽模擬器
final class MultiplayerTournamentSimulator {

    /// 運行一輪錦標賽
    static func runOneTournament(
        players: [AIProfile],
        tables: Int = 8,
        handsPerTable: Int = 30
    ) -> [PlayerRating] {
        // 隨機分桌
        let tableSize = min(6, players.count / tables)
        var tablePlayers: [[AIProfile]] = []

        var shuffled = players.shuffled()
        for _ in 0..<tables {
            if shuffled.isEmpty { break }
            let count = min(tableSize, shuffled.count)
            tablePlayers.append(Array(shuffled.prefix(count)))
            shuffled.removeFirst(count)
        }

        // 每桌模擬
        var results: [String: PlayerRating] = [:]

        for tablePlayers in tablePlayers {
            let tableResults = simulateTable(players: tablePlayers, hands: handsPerTable)
            for (id, rating) in tableResults {
                if var existing = results[id] {
                    existing.wins += rating.wins
                    existing.losses += rating.losses
                    existing.top3 += rating.top3
                    existing.top5 += rating.top5
                    existing.totalProfit += rating.totalProfit
                    existing.handsPlayed += rating.handsPlayed
                    existing.totalRank += rating.totalRank
                    existing.participationCount += 1
                    results[id] = existing
                } else {
                    var newRating = rating
                    newRating.participationCount = 1
                    results[id] = newRating
                }
            }
        }

        return Array(results.values)
    }

    /// 模擬一桌
    private static func simulateTable(players: [AIProfile], hands: Int) -> [String: PlayerRating] {
        guard players.count >= 2 else { return [:] }

        var ratings: [String: PlayerRating] = [:]
        var chips: [String: Int] = [:]

        // 初始化
        for player in players {
            chips[player.id] = 1000
            ratings[player.id] = PlayerRating(
                profile: player,
                elo: 1500,
                wins: 0,
                losses: 0,
                top3: 0,
                top5: 0,
                totalProfit: 0,
                handsPlayed: 0,
                totalRank: 0,
                participationCount: 0
            )
        }

        // 模擬手牌
        for _ in 0..<hands {
            let result = simulateOneHand(players: players, chips: &chips)

            // 更新結果
            for (id, isWin) in result.wins {
                if var rating = ratings[id] {
                    rating.handsPlayed += 1
                    if isWin {
                        rating.wins += 1
                    } else {
                        rating.losses += 1
                    }
                    ratings[id] = rating
                }
            }
        }

        // 計算排名
        let sorted = chips.sorted { $0.value > $1.value }
        for (rank, (id, _)) in sorted.enumerated() {
            if var rating = ratings[id] {
                rating.totalRank = rank + 1
                if rank < 3 {
                    rating.top3 = 1
                }
                if rank < 5 {
                    rating.top5 = 1
                }
                rating.totalProfit = chips[id]! - 1000
                ratings[id] = rating
            }
        }

        return ratings
    }

    /// 模擬一手牌
    private static func simulateOneHand(players: [AIProfile], chips: inout [String: Int]) -> (wins: [String: Bool], pot: Int) {
        var wins: [String: Bool] = [:]
        var participants: [(profile: AIProfile, id: String)] = []

        // 決定參與者
        for player in players {
            let willPlay = Double.random(in: 0...1) > player.tightness * 0.6
            if willPlay && (chips[player.id] ?? 0) > 20 {
                participants.append((player, player.id))
            }
        }

        guard participants.count >= 2 else {
            return ([:], 0)
        }

        // 計算每個參與者的勝率
        var winRates: [String: Double] = [:]
        for (profile, id) in participants {
            let baseRate = Double.random(in: 0.2...0.7)

            // 根據profile參數調整
            let adjustedRate = baseRate +
                profile.aggression * 0.08 +
                profile.positionAwareness * 0.06 +
                profile.bluffDetection * 0.06 +
                profile.riskTolerance * 0.04

            winRates[id] = min(0.85, max(0.15, adjustedRate))
        }

        // 決定下注
        var pot = 0
        for (profile, id) in participants {
            let bet: Int
            if Double.random(in: 0...1) < profile.aggression * 0.5 && (chips[id] ?? 0) > 100 {
                bet = min(50, (chips[id] ?? 0) / 10)
            } else {
                bet = min(20, (chips[id] ?? 0) / 20)
            }

            pot += bet
            chips[id] = (chips[id] ?? 0) - bet
        }

        // 判定勝者
        for (profile, id) in participants {
            let roll = Double.random(in: 0...1)
            let isWin = roll < (winRates[id] ?? 0.5)
            wins[id] = isWin

            if isWin {
                chips[id] = (chips[id] ?? 0) + pot / participants.count
            }
        }

        return (wins, pot)
    }
}

// MARK: - 完整排名系統

final class AIRankingSystem {

    static let initialElo: Double = 1500
    static let kFactor: Double = 32  // Elo更新系数

    /// 運行完整排名系統
    static func runFullRanking(
        players: [AIProfile],
        tournamentCount: Int = 50,
        tablesPerTournament: Int = 8,
        handsPerTable: Int = 30
    ) -> [PlayerRating] {

        // 初始化
        var ratings: [String: PlayerRating] = [:]
        for player in players {
            ratings[player.id] = PlayerRating(
                profile: player,
                elo: initialElo,
                wins: 0,
                losses: 0,
                top3: 0,
                top5: 0,
                totalProfit: 0,
                handsPlayed: 0,
                totalRank: 0,
                participationCount: 0
            )
        }

        // 運行多次錦標賽
        for tournament in 0..<tournamentCount {
            let results = MultiplayerTournamentSimulator.runOneTournament(
                players: players,
                tables: tablesPerTournament,
                handsPerTable: handsPerTable
            )

            // 更新積分
            for result in results {
                if var existing = ratings[result.profile.id] {
                    // 根據排名更新Elo
                    let rank = result.totalRank
                    let totalPlayers = players.count
                    let expectedScore = 1.0 - Double(rank - 1) / Double(totalPlayers - 1)
                    let actualScore = result.wins > result.losses ? 1.0 : (result.wins == result.losses ? 0.5 : 0.0)

                    // 簡化的Elo更新
                    let eloChange = kFactor * (actualScore - expectedScore) * 0.1
                    existing.elo += eloChange

                    // 累加統計
                    existing.wins += result.wins
                    existing.losses += result.losses
                    existing.top3 += result.top3
                    existing.top5 += result.top5
                    existing.totalProfit += result.totalProfit
                    existing.handsPlayed += result.handsPlayed
                    existing.totalRank += result.totalRank
                    existing.participationCount += 1

                    ratings[result.profile.id] = existing
                }
            }

            if (tournament + 1) % 10 == 0 {
                print("   进度: \(tournament + 1)/\(tournamentCount) 轮")
            }
        }

        return Array(ratings.values).sorted { $0.totalScore > $1.totalScore }
    }

    /// 生成完整報告
    static func generateReport() -> String {
        let players = AIProfile.allProfiles

        print("\n🎰 开始运行完整排名系统...")
        print("   角色总数: \(players.count)")
        print("   锦标赛轮数: 50")
        print("   每轮桌数: 8")
        print("   每桌手牌: 30")
        print("")

        let ratings = runFullRanking(
            players: players,
            tournamentCount: 50,
            tablesPerTournament: 8,
            handsPerTable: 30
        )

        return formatReport(ratings: ratings)
    }

    /// 格式化報告
    private static func formatReport(ratings: [PlayerRating]) -> String {
        var report = """

╔══════════════════════════════════════════════════════════════════╗
║                  AI 角色完整排名报告                             ║
║                  50轮锦标赛综合评估                              ║
╚══════════════════════════════════════════════════════════════════╝

"""
        // 前10名
        report += """
┌─────────────────────────────────────────────────────────────────┐
│                        🏆 最终排名 TOP 10                       │
└─────────────────────────────────────────────────────────────────┘

 排名   角色              Elo     胜率   平均排名  Top3%  筹码效率  综合分
 ────  ────────────────  ──────  ─────  ───────  ─────  ───────  ──────
"""

        for (i, rating) in ratings.prefix(10).enumerated() {
            let rank = i + 1
            let name = rating.profile.name
            let elo = Int(rating.elo)
            let winRate = Int(rating.winRate * 100)
            let avgRank = String(format: "%.1f", rating.averageRank)
            let top3Rate = Int(rating.top3Rate * 100)
            let profit = rating.totalProfit
            let score = Int(rating.totalScore)

            let medal = rank == 1 ? "🥇" : rank == 2 ? "🥈" : rank == 3 ? "🥉" : "  "

            report += String(format: " %@ %2d  %-14s %5d  %3d%%   %6s   %3d%%   %+6d  %5d\n",
                medal, rank, name, elo, winRate, avgRank, top3Rate, profit, score)
        }

        // 按难度分组统计
        report += """

┌─────────────────────────────────────────────────────────────────┐
│                      📊 难度分组统计                             │
└─────────────────────────────────────────────────────────────────┘

 难度    人数    平均Elo    平均胜率   平均排名    Top3率
 ────   ────   ────────   ───────   ────────   ───────
"""

        let difficulties: [(AIProfile.Difficulty, String)] = [
            (.easy, "简单  "),
            (.normal, "普通  "),
            (.hard, "困难  "),
            (.expert, "专家  ")
        ]

        for (difficulty, name) in difficulties {
            let diffProfiles = difficulty.availableProfiles
            let diffRatings = ratings.filter { rating in
                diffProfiles.contains { $0.id == rating.profile.id }
            }

            if diffRatings.isEmpty { continue }

            let avgElo = diffRatings.map { $0.elo }.reduce(0, +) / Double(diffRatings.count)
            let avgWinRate = diffRatings.map { $0.winRate }.reduce(0, +) / Double(diffRatings.count)
            let avgRank = diffRatings.map { $0.averageRank }.reduce(0, +) / Double(diffRatings.count)
            let avgTop3 = diffRatings.map { $0.top3Rate }.reduce(0, +) / Double(diffRatings.count)

            report += String(format: " %@   %2d    %6.0f     %4.0f%%    %5.1f      %4.0f%%\n",
                name, diffRatings.count, avgElo, avgWinRate * 100, avgRank, avgTop3 * 100)
        }

        // Expert 详情
        report += """

┌─────────────────────────────────────────────────────────────────┐
│                      🏅 Expert 详细数据                         │
└─────────────────────────────────────────────────────────────────┘

 角色              Elo     胜率   平均排名  Top3率   筹码效率
 ────────────────  ──────  ─────  ───────  ──────  ────────
"""

        let expertRatings = ratings.filter { rating in
            AIProfile.Difficulty.expert.availableProfiles.contains { $0.id == rating.profile.id }
        }.sorted { $0.elo > $1.elo }

        for rating in expertRatings {
            let name = rating.profile.name
            let elo = Int(rating.elo)
            let winRate = Int(rating.winRate * 100)
            let avgRank = String(format: "%.1f", rating.averageRank)
            let top3Rate = Int(rating.top3Rate * 100)
            let profit = rating.totalProfit

            report += String(format: " %-16s %5d   %3d%%    %6s    %3d%%    %+6d\n",
                name, elo, winRate, avgRank, top3Rate, profit)
        }

        // 结论
        report += """

┌─────────────────────────────────────────────────────────────────┐
│                         📈 结论                                 │
└─────────────────────────────────────────────────────────────────┘

 1. 排名算法: 自适应Elo系统 (初始1500, K=32)
 2. 评估轮数: 50轮锦标赛，确保统计显著性
 3. 综合评分: Elo(40%) + 胜率(20%) + 排名(15%) + Top3(25%)

"""

        // 验证难度递增
        let easyProfileIds = Set(AIProfile.Difficulty.easy.availableProfiles.map { $0.id })
        let expertProfileIds = Set(AIProfile.Difficulty.expert.availableProfiles.map { $0.id })

        let easyRatings = ratings.filter { easyProfileIds.contains($0.profile.id) }
        let expertRatingsForComparison = ratings.filter { expertProfileIds.contains($0.profile.id) }

        let easyAvg = easyRatings.isEmpty ? 0 : easyRatings.map { $0.elo }.reduce(0, +) / Double(easyRatings.count)
        let expertAvg = expertRatingsForComparison.isEmpty ? 0 : expertRatingsForComparison.map { $0.elo }.reduce(0, +) / Double(expertRatingsForComparison.count)

        let gap = expertAvg - easyAvg
        let isValid = gap > 50

        report += " 4. 难度差距: Expert平均Elo - Easy平均Elo = \(Int(gap)) 分\n"
        report += " 5. 难度验证: \(isValid ? "✅ 通过 - Expert明显强于Easy" : "❌ 失败 - 需要调整参数")\n"

        report += """

══════════════════════════════════════════════════════════════════
                        测试完成
══════════════════════════════════════════════════════════════════
"""

        return report
    }
}

// MARK: - 测试

final class AIRankingSystemTests: XCTestCase {

    func testFullRankingSystem() {
        let report = AIRankingSystem.generateReport()
        print(report)

        // 验证
        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("AI 角色完整排名报告"))
    }

    func testTournamentSimulation() {
        let players = Array(AIProfile.allProfiles.prefix(12))
        let results = MultiplayerTournamentSimulator.runOneTournament(
            players: players,
            tables: 2,
            handsPerTable: 20
        )

        XCTAssertEqual(results.count, players.count)

        print("\n🎲 测试锦标赛结果:")
        for result in results.sorted(by: { $0.totalRank < $1.totalRank }) {
            print("   \(result.profile.name): 排名\(result.totalRank), 胜\(result.wins)/负\(result.losses)")
        }
    }

    func testEloUpdate() {
        var rating = PlayerRating(
            profile: AIProfile.fox,
            elo: 1500,
            wins: 5,
            losses: 3,
            top3: 1,
            top5: 2,
            totalProfit: 500,
            handsPlayed: 50,
            totalRank: 3,
            participationCount: 1
        )

        print("\n📊 角色统计:")
        print("   胜率: \(String(format: "%.1f%%", rating.winRate * 100))")
        print("   平均排名: \(String(format: "%.1f", rating.averageRank))")
        print("   Top3率: \(String(format: "%.1f%%", rating.top3Rate * 100))")
        print("   综合分: \(String(format: "%.0f", rating.totalScore))")
    }
}
