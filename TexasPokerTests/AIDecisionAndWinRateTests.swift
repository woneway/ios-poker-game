import Foundation
import XCTest
@testable import TexasPoker

/// ============================================================
/// AI 决策模拟测试 - 模拟实际对局场景测试AI决策质量
/// ============================================================

/// 模拟决策场景
struct DecisionScenario {
    let description: String
    var profile: AIProfile
    let holeCards: [Card]
    let communityCards: [Card]
    let street: Street
    let potSize: Int
    let betToFace: Int
    let stackSize: Int
    let isPFR: Bool
    var seatOffset: Int

    /// 期望的决策类型 (用于验证)
    var expectedActionType: ActionType?

    enum ActionType {
        case raise
        case call
        case fold
        case check
    }
}

/// 决策模拟器
final class AIDecisionSimulator {

    /// 模拟AI在特定场景下的决策
    static func simulateDecision(scenario: DecisionScenario) -> String {
        let profile = scenario.profile

        // 1. 计算手牌强度 (简化版)
        let handStrength = estimateHandStrength(
            holeCards: scenario.holeCards,
            communityCards: scenario.communityCards,
            street: scenario.street
        )

        // 2. 计算赔率
        let potOdds: Double
        if scenario.betToFace > 0 && scenario.potSize > 0 {
            potOdds = Double(scenario.betToFace) / Double(scenario.potSize + scenario.betToFace)
        } else {
            potOdds = 0
        }

        // 3. 根据profile做决策
        let decision = makeProfileBasedDecision(
            profile: profile,
            handStrength: handStrength,
            potOdds: potOdds,
            scenario: scenario
        )

        return decision
    }

    /// 估算手牌强度 - 使用真实HandEvaluator
    private static func estimateHandStrength(
        holeCards: [Card],
        communityCards: [Card],
        street: Street
    ) -> Double {
        guard holeCards.count == 2 else { return 0.5 }

        // Flop前：使用Chen公式
        if communityCards.isEmpty {
            let chen = DecisionEngine.chenFormula(holeCards)
            return DecisionEngine.chenToNormalized(chen)
        }

        // 翻牌后：使用真实HandEvaluator
        let (category, kickers) = HandEvaluator.evaluate(holeCards: holeCards, communityCards: communityCards)

        // 将牌型category转换为0-1的手牌强度
        // category: 8=StraightFlush, 7=Quads, 6=FullHouse, 5=Flush, 4=Straight,
        //           3=Trips, 2=TwoPair, 1=Pair, 0=HighCard
        var strength = Double(category) / 8.0

        // 考虑kickers
        if let highestKicker = kickers.first {
            strength += Double(highestKicker) / 130.0
        }

        // 听牌加成（翻牌后）
        if communityCards.count >= 3 {
            if checkFlushDraw(holeCards: holeCards, community: communityCards) {
                strength += 0.15
            }
            if checkStraightDraw(holeCards: holeCards, community: communityCards) {
                strength += 0.12
            }
        }

        return min(1.0, max(0.0, strength))
    }

    /// 检查同花听牌
    private static func checkFlushDraw(holeCards: [Card], community: [Card]) -> Bool {
        let allCards = holeCards + community
        var suitCounts: [Suit: Int] = [:]
        for card in allCards {
            suitCounts[card.suit, default: 0] += 1
        }
        return suitCounts.values.contains(4)
    }

    /// 检查顺子听牌
    private static func checkStraightDraw(holeCards: [Card], community: [Card]) -> Bool {
        let allRanks = (holeCards + community).map { Int($0.rank.rawValue) }.sorted()
        var uniqueRanks = Array(Set(allRanks)).sorted()

        // 检查是否有4张连续的牌
        var consecutive = 1
        for i in 1..<uniqueRanks.count {
            if uniqueRanks[i] == uniqueRanks[i-1] + 1 {
                consecutive += 1
                if consecutive >= 4 {
                    return true
                }
            } else {
                consecutive = 1
            }
        }

        return false
    }

    /// 基于Profile做决策
    private static func makeProfileBasedDecision(
        profile: AIProfile,
        handStrength: Double,
        potOdds: Double,
        scenario: DecisionScenario
    ) -> String {
        // 无人下注
        if scenario.betToFace == 0 {
            // 检查是否应该bet
            let shouldBet = handStrength > (1.0 - profile.effectiveTightness) * 0.8

            if shouldBet {
                return "bet"
            } else {
                return "check"
            }
        }

        // 面对下注
        let effectiveBluffFreq = profile.effectiveBluffFreq
        let shouldCall = handStrength > potOdds
        let shouldRaise = handStrength > 0.75

        // 考虑bluff
        let isBluffSituation = handStrength < 0.35 && potOdds < 0.25

        if shouldRaise && !isBluffSituation {
            return "raise"
        } else if shouldCall || (isBluffSituation && Double.random(in: 0...1) < effectiveBluffFreq) {
            return "call"
        } else {
            return "fold"
        }
    }
}

// MARK: - 决策模拟测试

final class AIDecisionSimulationTests: XCTestCase {

    func testDecisionSimulationWithDifferentProfiles() {
        // 场景：翻牌圈，面对下注

        let commonScenario = DecisionScenario(
            description: "翻牌圈面对下注",
            profile: AIProfile.fox, // 默认
            holeCards: [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades)],
            communityCards: [
                Card(rank: .ten, suit: .spades),
                Card(rank: .seven, suit: .hearts),
                Card(rank: .two, suit: .clubs)
            ],
            street: .flop,
            potSize: 100,
            betToFace: 30,
            stackSize: 1000,
            isPFR: false,
            seatOffset: 4
        )

        // 测试不同profile的决策差异
        let profiles: [(AIProfile, String)] = [
            (AIProfile.rock, "Rock - 应该紧"),
            (AIProfile.maniac, "Maniac - 应该激进"),
            (AIProfile.callingStation, "Calling Station - 应该跟注"),
            (AIProfile.fox, "Fox - 平衡")
        ]

        for (profile, name) in profiles {
            var scenario = commonScenario
            scenario.profile = profile

            let decision = AIDecisionSimulator.simulateDecision(scenario: scenario)
            print("[\(name)] 决策: \(decision)")
        }
    }

    func testBluffDetectionDifferences() {
        // 场景：河牌圈，对手可能诈雏

        let scenario = DecisionScenario(
            description: "河牌圈对手可能诈雏",
            profile: AIProfile.fox,
            holeCards: [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .hearts)],
            communityCards: [
                Card(rank: .ten, suit: .spades),
                Card(rank: .seven, suit: .hearts),
                Card(rank: .two, suit: .clubs),
                Card(rank: .jack, suit: .diamonds),
                Card(rank: .five, suit: .spades)
            ],
            street: .river,
            potSize: 200,
            betToFace: 80,
            stackSize: 500,
            isPFR: false,
            seatOffset: 5
        )

        // 高读牌能力 vs 低读牌能力
        let highDetection = AIProfile.mindReader // bluffDetection 0.95
        let lowDetection = AIProfile.newbieBob    // bluffDetection 较低

        var highScenario = scenario
        highScenario.profile = highDetection

        var lowScenario = scenario
        lowScenario.profile = lowDetection

        print("高读牌能力 (读心术师) 决策: \(AIDecisionSimulator.simulateDecision(scenario: highScenario))")
        print("低读牌能力 (新手鲍勃) 决策: \(AIDecisionSimulator.simulateDecision(scenario: lowScenario))")
    }

    func testPositionAwareness() {
        // 场景：BTN位 vs UTG位

        let scenario = DecisionScenario(
            description: "BTN位开池",
            profile: AIProfile.shark, // 高位置意识
            holeCards: [Card(rank: .seven, suit: .spades), Card(rank: .eight, suit: .hearts)],
            communityCards: [],
            street: .preFlop,
            potSize: 3,
            betToFace: 0,
            stackSize: 100,
            isPFR: true,
            seatOffset: 0 // BTN
        )

        let decision = AIDecisionSimulator.simulateDecision(scenario: scenario)
        print("Shark 在 BTN 位决策: \(decision)")

        // Shark 在 UTG 位应该更紧
        var utgScenario = scenario
        utgScenario.seatOffset = 3 // UTG
        utgScenario.profile = AIProfile.shark

        let utgDecision = AIDecisionSimulator.simulateDecision(scenario: utgScenario)
        print("Shark 在 UTG 位决策: \(utgDecision)")
    }
}

// MARK: - 胜率统计测试

final class AIWinRateStatisticsTests: XCTestCase {

    struct WinRateResult {
        let difficulty: AIProfile.Difficulty
        let totalHands: Int
        let wins: Int
        let losses: Int
        let ties: Int
        let winRate: Double
    }

    /// 模拟统计不同难度AI的胜率
    /// 注意：这是简化版模拟，实际应该运行完整对局
    func testSimulatedWinRates() {
        var results: [WinRateResult] = []

        for difficulty in [AIProfile.Difficulty.easy, .normal, .hard, .expert] {
            let result = simulateWinRate(for: difficulty, hands: 1000)
            results.append(result)

            print("📊 \(difficulty.rawValue) 模拟胜率:")
            print("   胜: \(result.wins) (\(String(format: "%.1f", result.winRate * 100))%)")
            print("   负: \(result.losses)")
            print("   平: \(result.ties)")
        }

        // 验证Expert胜率应该最高
        let expertResult = results.first { $0.difficulty == .expert }!
        let easyResult = results.first { $0.difficulty == .easy }!

        XCTAssertGreaterThan(expertResult.winRate, easyResult.winRate,
            "Expert 胜率应该高于 Easy")
    }

    private func simulateWinRate(for difficulty: AIProfile.Difficulty, hands: Int) -> WinRateResult {
        let profiles = difficulty.availableProfiles
        guard !profiles.isEmpty else {
            return WinRateResult(difficulty: difficulty, totalHands: 0, wins: 0, losses: 0, ties: 0, winRate: 0)
        }

        var wins = 0
        var losses = 0
        var ties = 0

        for _ in 0..<hands {
            // 简化模拟：
            // 1. 随机选择一个profile
            let profile = profiles.randomElement()!

            // 2. 根据profile参数计算"基础胜率"
            // 考虑: aggression, positionAwareness, bluffDetection, riskTolerance
            let baseWinChance = 0.40 + (profile.aggression * 0.10) +
                               (profile.positionAwareness * 0.08) +
                               (profile.bluffDetection * 0.08) +
                               (profile.riskTolerance * 0.04)

            // 3. 考虑难度系数 (mistakeRate)
            let mistakeRate = difficultyMistakeRate(difficulty)
            let effectiveWinChance = baseWinChance * (1.0 - mistakeRate * 0.5)

            // 4. 随机波动
            let actualWinChance = effectiveWinChance + Double.random(in: -0.15...0.15)

            // 5. 判定输赢
            let roll = Double.random(in: 0...1)
            if roll < actualWinChance {
                wins += 1
            } else if roll < actualWinChance + 0.08 {
                ties += 1
            } else {
                losses += 1
            }
        }

        let winRate = Double(wins) / Double(hands)

        return WinRateResult(
            difficulty: difficulty,
            totalHands: hands,
            wins: wins,
            losses: losses,
            ties: ties,
            winRate: winRate
        )
    }

    private func difficultyMistakeRate(_ difficulty: AIProfile.Difficulty) -> Double {
        switch difficulty {
        case .easy: return 0.25
        case .normal: return 0.10
        case .hard: return 0.03
        case .expert: return 0.0
        }
    }

    /// 统计特定牌型在不同难度下的表现
    func testHandTypePerformance() {
        print("\n📊 特定牌型表现分析 (模拟)")

        // 强牌 (AA, KK)
        print("\n【强牌 (高对)】")
        analyzeHandType(handStrength: 0.85, handName: "AA/KK")

        // 中等牌 (顶对)
        print("\n【中等牌 (顶对)】")
        analyzeHandType(handStrength: 0.65, handName: "顶对")

        // 弱牌 (中对)
        print("\n【弱牌 (中对)】")
        analyzeHandType(handStrength: 0.45, handName: "中对")

        // 听牌
        print("\n【听牌 (顺子/同花听牌)】")
        analyzeHandType(handStrength: 0.35, handName: "听牌")
    }

    private func analyzeHandType(handStrength: Double, handName: String) {
        for difficulty in [AIProfile.Difficulty.easy, .normal, .hard, .expert] {
            let profiles = difficulty.availableProfiles
            let avgCallFreq = profiles.map { $0.callDownTendency }.reduce(0, +) / Double(profiles.count)

            // 简化的决策模型
            let betSize = 50
            let potSize = 100
            let potOdds = Double(betSize) / Double(potSize + betSize)

            // 不同难度对不同牌型的处理
            let playRate: Double
            switch difficulty {
            case .easy:
                playRate = handStrength > 0.5 ? 0.7 : 0.3
            case .normal:
                playRate = handStrength > potOdds ? 0.8 : 0.2
            case .hard:
                playRate = handStrength > potOdds ? 0.9 : 0.1
            case .expert:
                playRate = handStrength > potOdds ? 0.95 : 0.05
            }

            print("   \(difficulty.rawValue): \(String(format: "%.0f%%", playRate * 100)) 入池率")
        }
    }
}
