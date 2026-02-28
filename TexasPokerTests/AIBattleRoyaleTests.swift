import Foundation
import XCTest
@testable import TexasPoker

/// ============================================================
/// AI 大乱斗测试 - 所有角色同场竞技
/// 优化版本：使用真实Deck和HandEvaluator
/// ============================================================

/// 增强版模拟完整牌局 - 使用真实扑克引擎
final class EnhancedAIBattleSimulator {

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

    /// 运行大乱斗 - 使用真实Deck发牌
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
            // 使用真实Deck发公共牌
            let community = dealCommunityCardsReal()

            // 每个玩家决策
            for i in 0..<playerResults.count {
                let result = simulateHandReal(
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

    /// 使用真实Deck发公共牌
    private static func dealCommunityCardsReal() -> [Card] {
        var deck = Deck()
        deck.reset()

        // Flop (3张)
        let flop = deck.deal(count: 3)
        // Turn (1张)
        let turn = deck.deal(count: 1)
        // River (1张)
        let river = deck.deal(count: 1)

        return flop + turn + river
    }

    /// 使用真实手牌和HandEvaluator模拟一手牌
    private static func simulateHandReal(
        player: PlayerResult,
        community: [Card],
        opponents: [PlayerResult]
    ) -> PlayerResult {
        var result = player
        result.handsPlayed += 1

        // 创建真实的手牌
        var deck = Deck()
        deck.reset()

        // 发两张手牌
        let holeCards = deck.deal(count: 2)

        // 使用HandEvaluator评估手牌强度
        let (category, kickers) = HandEvaluator.evaluate(holeCards: holeCards, communityCards: community)

        // 将评估结果转换为手牌强度 (0.0 - 1.0)
        let handStrength = categoryToStrength(category: category, kickers: kickers, community: community)

        // 根据profile参数决定行动
        let profile = player.profile

        // 决定是否参与：基于tightness和手牌强度
        let willPlay = handStrength > (1.0 - profile.tightness) * 0.5

        if willPlay && result.chips > 0 {
            // 决定下注金额
            let betSize: Int
            if handStrength > 0.7 {
                // 强牌价值下注
                betSize = min(Int(Double(result.chips) * 0.15), result.chips)
            } else if handStrength < 0.3 && Double.random(in: 0...1) < profile.bluffFreq {
                // 弱牌诈雏下注
                betSize = min(Int(Double(result.chips) * 0.1), result.chips)
            } else if community.isEmpty {
                // 翻牌前标准加注
                betSize = min(Int(Double(result.chips) * 0.1), result.chips)
            } else {
                // 持续下注
                betSize = min(Int(Double(result.chips) * 0.08), result.chips)
            }

            // 位置加成
            let positionMultiplier = 1.0 + (profile.positionAwareness * 0.2)
            let adjustedBet = max(1, Int(Double(betSize) * positionMultiplier))
            let actualBet = min(adjustedBet, result.chips)

            result.totalBet += actualBet

            // 计算胜率（简化版，使用HandEvaluator结果和Monte Carlo概念）
            let winChance = calculateWinChanceReal(
                profile: profile,
                handStrength: handStrength,
                opponentCount: opponents.count,
                community: community
            )

            if Double.random(in: 0...1) < winChance {
                // 赢
                let win = actualBet * max(1, opponents.count)
                result.chips += win
                result.totalWon += win
                result.handsWon += 1
            } else {
                // 输
                result.chips -= actualBet
            }
        }

        // 确保筹码不为负
        result.chips = max(0, result.chips)

        return result
    }

    /// 将HandEvaluator的category转换为0-1的手牌强度
    private static func categoryToStrength(category: Int, kickers: [Int], community: [Card]) -> Double {
        var strength = Double(category) / 8.0 // 8是StraightFlush的最高category

        // 考虑kickers
        if let highestKicker = kickers.first {
            strength += Double(highestKicker) / 130.0 // 13种Rank
        }

        // 翻牌后有顺子/同花听牌加成
        if community.count >= 3 && community.count < 5 {
            // 简单检查听牌
            let hasFlushDraw = checkFlushDraw(community: community)
            let hasStraightDraw = checkStraightDraw(community: community)
            if hasFlushDraw || hasStraightDraw {
                strength += 0.15
            }
        }

        return min(1.0, max(0.0, strength))
    }

    private static func checkFlushDraw(community: [Card]) -> Bool {
        var suitCounts: [Suit: Int] = [:]
        for card in community {
            suitCounts[card.suit, default: 0] += 1
        }
        return suitCounts.values.contains(4)
    }

    private static func checkStraightDraw(community: [Card]) -> Bool {
        // 简化实现
        return false
    }

    /// 计算真实胜率
    private static func calculateWinChanceReal(
        profile: AIProfile,
        handStrength: Double,
        opponentCount: Int,
        community: [Card]
    ) -> Double {
        // 基础胜率基于HandEvaluator评估
        var baseWinChance = handStrength

        // 侵略性加成
        baseWinChance += profile.aggression * 0.05

        // 位置意识加成
        baseWinChance += profile.positionAwareness * 0.03

        // 读牌能力加成
        baseWinChance += profile.bluffDetection * 0.03

        // 风险承受调整
        baseWinChance += (profile.riskTolerance - 0.5) * 0.02

        // 难度系数（基于difficulty属性）
        let mistakeRate = getMistakeRate(for: profile)
        baseWinChance *= (1.0 - mistakeRate * 0.3)

        // 对手数量调整
        let opponentPenalty = Double(max(0, opponentCount - 1)) * 0.08
        baseWinChance -= opponentPenalty

        return min(0.95, max(0.05, baseWinChance))
    }

    /// 获取AI的错误率
    private static func getMistakeRate(for profile: AIProfile) -> Double {
        // 根据profile参数估算错误率
        // 紧凶型错误率低，松弱型错误率高
        let baseError = 0.15 // 基础错误率

        // tightness越高，错误率越低
        let tightnessEffect = (profile.tightness - 0.5) * 0.1

        // aggression越高，可能错误率越高（激进导致更多错误）
        let aggressionEffect = (profile.aggression - 0.5) * 0.05

        // positionAwareness高，错误率低
        let positionEffect = (1.0 - profile.positionAwareness) * 0.05

        // bluffDetection高，错误率低
        let detectionEffect = (1.0 - profile.bluffDetection) * 0.05

        return max(0.0, min(0.5, baseError - tightnessEffect + aggressionEffect + positionEffect + detectionEffect))
    }
}

// MARK: - 大乱斗测试

final class AIBattleRoyaleTests: XCTestCase {

    /// 测试1: 四个难度级别大乱斗
    func testDifficultyBattleRoyale() {
        print("\n" + String(repeating: "=", count: 60))
        print("🎰 难度大乱斗 - 每个难度选3人，100手牌")
        print(String(repeating: "=", count: 60))

        let easyPlayers = Array(AIProfile.Difficulty.easy.availableProfiles.prefix(3))
        let normalPlayers = Array(AIProfile.Difficulty.normal.availableProfiles.prefix(3))
        let hardPlayers = Array(AIProfile.Difficulty.hard.availableProfiles.prefix(3))
        let expertPlayers = Array(AIProfile.Difficulty.expert.availableProfiles.prefix(3))

        let allPlayers = easyPlayers + normalPlayers + hardPlayers + expertPlayers

        let result = EnhancedAIBattleSimulator.runBattleRoyale(
            players: allPlayers,
            startingChips: 1000,
            hands: 100
        )

        printResult(result, groupBy: true)
    }

    /// 测试2: Expert 角色内部 PK
    func testExpertBattleRoyale() {
        print("\n" + String(repeating: "=", count: 60))
        print("🏆 Expert 角色内部PK - 12人，200手牌")
        print(String(repeating: "=", count: 60))

        let expertPlayers = AIProfile.Difficulty.expert.availableProfiles

        let result = EnhancedAIBattleSimulator.runBattleRoyale(
            players: expertPlayers,
            startingChips: 1000,
            hands: 200
        )

        printExpertResult(result)
    }

    /// 测试3: 所有角色大乱斗
    func testAllCharacterBattleRoyale() {
        print("\n" + String(repeating: "=", count: 60))
        print("🌍 所有角色大乱斗 - \(AIProfile.allProfiles.count)人，100手牌")
        print(String(repeating: "=", count: 60))

        let result = EnhancedAIBattleSimulator.runBattleRoyale(
            players: AIProfile.allProfiles,
            startingChips: 1000,
            hands: 100
        )

        printFullResult(result)
    }

    /// 测试4: 特定风格对决
    func testStyleMatchup() {
        print("\n" + String(repeating: "=", count: 60))
        print("⚔️ 风格对决 - Tight vs Loose")
        print(String(repeating: "=", count: 60))

        // Tight 风格
        let tightPlayers: [AIProfile] = [.rock, .nitSteve, .tightMary]

        // Loose 风格
        let loosePlayers: [AIProfile] = [.maniac, .callingStation, .pureFish]

        // Tight vs Loose
        var result1 = EnhancedAIBattleSimulator.runBattleRoyale(
            players: tightPlayers,
            startingChips: 1000,
            hands: 100
        )

        var result2 = EnhancedAIBattleSimulator.runBattleRoyale(
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

    private func printResult(_ result: EnhancedAIBattleSimulator.BattleResult, groupBy: Bool) {
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

    private func printExpertResult(_ result: EnhancedAIBattleSimulator.BattleResult) {
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

    private func printFullResult(_ result: EnhancedAIBattleSimulator.BattleResult) {
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

extension EnhancedAIBattleSimulator {

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

// MARK: - 向后兼容别名

/// 向后兼容：旧名称作为新模拟器的别名
typealias AIBattleSimulator = EnhancedAIBattleSimulator

// MARK: - 统计显著性验证模块

/// 统计验证工具 - 用于验证测试结果的统计显著性
struct StatisticalValidator {

    /// 计算置信区间
    static func confidenceInterval(values: [Double], confidenceLevel: Double = 0.95) -> (lower: Double, upper: Double)? {
        guard values.count > 1 else { return nil }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count - 1)
        let stdDev = sqrt(variance)

        // Z-score for 95% confidence = 1.96
        let zScore = confidenceLevel == 0.95 ? 1.96 : 1.645
        let marginOfError = zScore * stdDev / sqrt(Double(values.count))

        return (mean - marginOfError, mean + marginOfError)
    }

    /// 检查两组结果是否有统计显著性差异
    static func hasSignificantDifference(groupA: [Double], groupB: [Double]) -> Bool {
        guard let meanA = groupA.reduce(0, +) as Double?,
              let meanB = groupB.reduce(0, +) as Double? else {
            return false
        }

        let avgA = meanA / Double(groupA.count)
        let avgB = meanB / Double(groupB.count)

        // 计算标准误差
        let varianceA = groupA.map { pow($0 - avgA, 2) }.reduce(0, +) / Double(groupA.count - 1)
        let varianceB = groupB.map { pow($0 - avgB, 2) }.reduce(0, +) / Double(groupB.count - 1)
        let stdError = sqrt(varianceA / Double(groupA.count) + varianceB / Double(groupB.count))

        guard stdError > 0 else { return false }

        let tStatistic = abs(avgA - avgB) / stdError

        // 简化的t检验（假设自由度足够大）
        return tStatistic > 1.96 // 95%置信度
    }

    /// 计算效应量（Cohen's d）
    static func cohensD(groupA: [Double], groupB: [Double]) -> Double {
        let meanA = groupA.reduce(0, +) / Double(groupA.count)
        let meanB = groupB.reduce(0, +) / Double(groupB.count)

        let varianceA = groupA.map { pow($0 - meanA, 2) }.reduce(0, +) / Double(groupA.count - 1)
        let varianceB = groupB.map { pow($0 - meanB, 2) }.reduce(0, +) / Double(groupB.count - 1)

        let pooledStdDev = sqrt((varianceA + varianceB) / 2)

        guard pooledStdDev > 0 else { return 0 }

        return (meanA - meanB) / pooledStdDev
    }
}
