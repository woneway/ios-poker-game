import Foundation
import XCTest
@testable import TexasPoker

/// ============================================================
/// AI 大乱斗测试 - 所有角色同场竞技
/// ============================================================

/// 模拟完整牌局
final class AIBattleSimulator {

    struct PlayerResult {
        let profile: AIProfile
        var chips: Int
        var handsPlayed: Int
        var handsWon: Int
        var totalBet: Int
        var totalWon: Int
    }

    struct BattleResult {
        let totalHands: Int
        let playerResults: [PlayerResult]
        let winner: AIProfile
        let top3: [AIProfile]
    }

    /// 运行大乱斗 - 所有角色同场竞技
    static func runBattleRoyale(
        players: [AIProfile],
        startingChips: Int = 1000,
        hands: Int = 100
    ) -> BattleResult {
        var playerResults = players.map { PlayerResult(
            profile: $0,
            chips: startingChips,
            handsPlayed: 0,
            handsWon: 0,
            totalBet: 0,
            totalWon: 0
        )}

        // 模拟每一手牌
        for _ in 0..<hands {
            // 发公共牌
            let community = dealCommunityCards()

            // 每个玩家决策
            for i in 0..<playerResults.count {
                let result = simulateHand(
                    player: playerResults[i],
                    community: community,
                    opponents: playerResults.filter { $0.profile.id != playerResults[i].profile.id }
                )
                playerResults[i] = result
            }
        }

        // 排序
        playerResults.sort { $0.chips > $1.chips }

        let winner = playerResults.first!.profile
        let top3 = Array(playerResults.prefix(3).map { $0.profile })

        return BattleResult(
            totalHands: hands,
            playerResults: playerResults,
            winner: winner,
            top3: top3
        )
    }

    /// 发公共牌
    private static func dealCommunityCards() -> [Card] {
        // 简化：随机生成公共牌
        // 实际应该用真实的Deck
        var cards: [Card] = []

        // Flop
        for _ in 0..<3 {
            let rank = Rank.allCases.randomElement()!
            let suit = Suit.allCases.randomElement()!
            cards.append(Card(rank: rank, suit: suit))
        }

        // Turn
        let turnRank = Rank.allCases.randomElement()!
        let turnSuit = Suit.allCases.randomElement()!
        cards.append(Card(rank: turnRank, suit: turnSuit))

        // River
        let riverRank = Rank.allCases.randomElement()!
        let riverSuit = Suit.allCases.randomElement()!
        cards.append(Card(rank: riverRank, suit: riverSuit))

        return cards
    }

    /// 模拟一手牌
    private static func simulateHand(
        player: PlayerResult,
        community: [Card],
        opponents: [PlayerResult]
    ) -> PlayerResult {
        var result = player
        result.handsPlayed += 1

        // 简化决策：
        // 1. 根据profile参数决定是否参与
        // 2. 根据手牌强度决定下注多少

        // 随机手牌
        let holeCards = [
            Card(rank: Rank.allCases.randomElement()!, suit: Suit.allCases.randomElement()!),
            Card(rank: Rank.allCases.randomElement()!, suit: Suit.allCases.randomElement()!)
        ]

        // 估算手牌强度
        let handStrength = estimateHandStrength(holeCards: holeCards, community: community)

        // 根据profile参数决定行动
        let profile = player.profile
        let willPlay = Double.random(in: 0...1) > profile.tightness
        let willRaise = Double.random(in: 0...1) < profile.aggression

        if willPlay {
            // 决定下注
            let betSize: Int
            if willRaise && handStrength > 0.6 {
                betSize = 50 // 价值下注
            } else if handStrength < 0.3 && Double.random(in: 0...1) < profile.bluffFreq {
                betSize = 30 // 诈雏
            } else {
                betSize = 20 // 标准化下注
            }

            // 考虑位置
            let positionMultiplier = 1.0 + (profile.positionAwareness * 0.2)
            let adjustedBet = Int(Double(betSize) * positionMultiplier)

            result.totalBet += min(adjustedBet, result.chips)

            // 胜率计算
            let winChance = calculateWinChance(
                profile: profile,
                handStrength: handStrength,
                opponentCount: opponents.count
            )

            if Double.random(in: 0...1) < winChance {
                // 赢
                let win = adjustedBet * opponents.count
                result.chips += win
                result.totalWon += win
                result.handsWon += 1
            } else {
                // 输
                result.chips -= adjustedBet
            }
        }

        // 确保筹码不为负
        result.chips = max(0, result.chips)

        return result
    }

    /// 估算手牌强度
    private static func estimateHandStrength(holeCards: [Card], community: [Card]) -> Double {
        guard holeCards.count == 2 else { return 0.5 }

        // 简化：基于牌面
        let ranks = holeCards.map { $0.rank.rawValue }
        let suits = holeCards.map { $0.suit }

        // 高对
        if ranks[0] >= 12 || ranks[1] >= 12 {
            return 0.75
        }

        // 同花连张
        if suits[0] == suits[1] && abs(ranks[0] - ranks[1]) <= 2 {
            return 0.60
        }

        // 中等对子
        if ranks[0] >= 8 || ranks[1] >= 8 {
            return 0.55
        }

        // 随机
        return Double.random(in: 0.2...0.5)
    }

    /// 计算胜率
    private static func calculateWinChance(
        profile: AIProfile,
        handStrength: Double,
        opponentCount: Int
    ) -> Double {
        // 基础胜率
        var baseWinChance = handStrength

        // 侵略性加成
        baseWinChance += profile.aggression * 0.05

        // 位置意识加成 (如果有位置优势)
        baseWinChance += profile.positionAwareness * 0.03

        // 读牌能力加成
        baseWinChance += profile.bluffDetection * 0.03

        // 风险承受调整
        baseWinChance += (profile.riskTolerance - 0.5) * 0.02

        // 对手数量调整 (对手越多，获胜概率降低)
        let opponentPenalty = Double(opponentCount - 1) * 0.08
        baseWinChance -= opponentPenalty

        return min(0.95, max(0.05, baseWinChance))
    }
}

// MARK: - 大乱斗测试

final class AIBattleRoyaleTests: XCTestCase {

    /// 测试1: 四个难度级别大乱斗
    func testDifficultyBattleRoyale() {
        print("\n" + "="*60)
        print("🎰 难度大乱斗 - 每个难度选3人，100手牌")
        print("="*60)

        let easyPlayers = Array(AIProfile.Difficulty.easy.availableProfiles.prefix(3))
        let normalPlayers = Array(AIProfile.Difficulty.normal.availableProfiles.prefix(3))
        let hardPlayers = Array(AIProfile.Difficulty.hard.availableProfiles.prefix(3))
        let expertPlayers = Array(AIProfile.Difficulty.expert.availableProfiles.prefix(3))

        let allPlayers = easyPlayers + normalPlayers + hardPlayers + expertPlayers

        let result = AIBattleSimulator.runBattleRoyale(
            players: allPlayers,
            startingChips: 1000,
            hands: 100
        )

        printResult(result, groupBy: true)
    }

    /// 测试2: Expert 角色内部 PK
    func testExpertBattleRoyale() {
        print("\n" + "="*60)
        print("🏆 Expert 角色内部PK - 12人，200手牌")
        print("="*60)

        let expertPlayers = AIProfile.Difficulty.expert.availableProfiles

        let result = AIBattleSimulator.runBattleRoyale(
            players: expertPlayers,
            startingChips: 1000,
            hands: 200
        )

        printExpertResult(result)
    }

    /// 测试3: 所有角色大乱斗
    func testAllCharacterBattleRoyale() {
        print("\n" + "="*60)
        print("🌍 所有角色大乱斗 - \(AIProfile.allProfiles.count)人，100手牌")
        print("="*60)

        let result = AIBattleSimulator.runBattleRoyale(
            players: AIProfile.allProfiles,
            startingChips: 1000,
            hands: 100
        )

        printFullResult(result)
    }

    /// 测试4: 特定风格对决
    func testStyleMatchup() {
        print("\n" + "="*60)
        print("⚔️ 风格对决 - Tight vs Loose")
        print("="*60)

        // Tight 风格
        let tightPlayers: [AIProfile] = [.rock, .nitSteve, .tightMary]

        // Loose 风格
        let loosePlayers: [AIProfile] = [.maniac, .callingStation, .pureFish]

        // Tight vs Loose
        var result1 = AIBattleSimulator.runBattleRoyale(
            players: tightPlayers,
            startingChips: 1000,
            hands: 100
        )

        var result2 = AIBattleSimulator.runBattleRoyale(
            players: loosePlayers,
            startingChips: 1000,
            hands: 100
        )

        print("Tight 风格 (石头、史蒂夫、玛丽):")
        printResult(result1, groupBy: false)

        print("\nLoose 风格 (疯子、跟注站、纯鱼):")
        printResult(result2, groupBy: false)
    }

    // MARK: - 结果打印

    private func printResult(_ result: AIBattleSimulator.BattleResult, groupBy: Bool) {
        print("\n🏆 冠军: \(result.winner.name)")
        print("\n🥈🥉 Top 3:")
        for (i, profile) in result.top3.enumerated() {
            let medal = i == 0 ? "🥇" : i == 1 ? "🥈" : "🥉"
            print("   \(medal) \(profile.name)")
        }

        print("\n📊 完整排名:")
        for (i, playerResult) in result.playerResults.enumerated() {
            let rank = i + 1
            let winRate = playerResult.handsPlayed > 0 ?
                Double(playerResult.handsWon) / Double(playerResult.handsPlayed) * 100 : 0

            print(String(format: "   %2d. %-12s 筹码:%6d  胜率:%5.1f%%  参与:%3d手",
                rank,
                playerResult.profile.name,
                playerResult.chips,
                winRate,
                playerResult.handsPlayed
            ))
        }
    }

    private func printExpertResult(_ result: AIBattleSimulator.BattleResult) {
        print("\n🏆 冠军: \(result.winner.name)")

        print("\n📊 Expert 排名 (200手牌):")
        for (i, playerResult) in result.playerResults.enumerated() {
            let rank = i + 1
            let winRate = playerResult.handsPlayed > 0 ?
                Double(playerResult.handsWon) / Double(playerResult.handsPlayed) * 100 : 0

            print(String(format: "   %2d. %-16s 筹码:%6d  胜率:%5.1f%%",
                rank,
                playerResult.profile.name,
                playerResult.chips,
                winRate
            ))
        }
    }

    private func printFullResult(_ result: AIBattleSimulator.BattleResult) {
        print("\n🏆 冠军: \(result.winner.name)")

        // 只显示前20名
        print("\n📊 前20名:")
        for (i, playerResult) in result.playerResults.prefix(20).enumerated() {
            let rank = i + 1
            print(String(format: "   %2d. %-16s 筹码:%6d",
                rank,
                playerResult.profile.name,
                playerResult.chips
            ))
        }

        // 统计各难度平均排名
        let difficulties: [(AIProfile.Difficulty, String)] = [
            (.easy, "简单"),
            (.normal, "普通"),
            (.hard, "困难"),
            (.expert, "专家")
        ]

        print("\n📈 难度平均排名:")
        for (difficulty, name) in difficulties {
            let profiles = difficulty.availableProfiles
            var totalRank = 0
            var count = 0

            for profile in profiles {
                if let index = result.playerResults.firstIndex(where: { $0.profile.id == profile.id }) {
                    totalRank += index + 1
                    count += 1
                }
            }

            let avgRank = count > 0 ? Double(totalRank) / Double(count) : 0
            print("   \(name): 平均排名 \(String(format: "%.1f", avgRank)) (\(count)人)")
        }
    }
}

// MARK: - 扩展：胜率统计

extension AIBattleSimulator {

    /// 统计不同难度级别的胜率
    static func calculateDifficultyWinRates(
        players: [AIProfile],
        hands: Int = 100,
        iterations: Int = 10
    ) -> [AIProfile.Difficulty: (wins: Int, avgRank: Double)] {

        var difficultyWins: [AIProfile.Difficulty: Int] = [:]
        var difficultyRanks: [AIProfile.Difficulty: [Int]] = [:]

        for _ in 0..<iterations {
            let result = runBattleRoyale(players: players, startingChips: 1000, hands: hands)

            // 统计冠军
            // 需要知道冠军属于哪个难度
            // 这里简化处理
        }

        return [:]
    }
}
