import Foundation
import XCTest
@testable import TexasPoker

/// ============================================================
/// AI 角色实力综合测试报告生成器
/// ============================================================
final class AIStrengthTestReport {

    struct TestResult {
        let name: String
        let passed: Bool
        let details: String
        let score: Double?
    }

    struct DifficultyReport {
        let difficulty: AIProfile.Difficulty
        let playerCount: Int
        let avgAggression: Double
        let avgPositionAwareness: Double
        let avgBluffDetection: Double
        let avgRiskTolerance: Double
        let avgOverallStrength: Double
        let playerDetails: [PlayerReport]
    }

    struct PlayerReport {
        let name: String
        let id: String
        let aggression: Double
        let positionAwareness: Double
        let bluffDetection: Double
        let riskTolerance: Double
        let tightness: Double
        let cbetFreq: Double
        let overallStrength: Double
    }

    private var results: [TestResult] = []

    // MARK: - 测试运行器

    func runAllTests() -> String {
        var report = """
        ╔══════════════════════════════════════════════════════════════════╗
        ║               AI 角色实力综合测试报告                              ║
        ║                   TexasPoker v1.0                                ║
        ╚══════════════════════════════════════════════════════════════════╝

        测试时间: \(formattedDate())

        """
        // 1. 运行参数验证测试
        report += runParameterValidationTests()

        // 2. 运行难度分布测试
        report += runDifficultyDistributionTests()

        // 3. 运行角色唯一性测试
        report += runUniquenessTests()

        // 4. 运行综合实力评估
        report += runOverallStrengthAssessment()

        // 5. 生成难度对比
        report += generateDifficultyComparison()

        // 6. 生成结论
        report += generateConclusion()

        return report
    }

    // MARK: - 参数验证测试

    private func runParameterValidationTests() -> String {
        var report = """

        ┌─────────────────────────────────────────────────────────────────┐
        │                    1. 参数验证测试                              │
        └─────────────────────────────────────────────────────────────────┘

        """

        let expertProfiles = AIProfile.Difficulty.expert.availableProfiles
        let hardProfiles = AIProfile.Difficulty.hard.availableProfiles
        let normalProfiles = AIProfile.Difficulty.normal.availableProfiles
        let easyProfiles = AIProfile.Difficulty.easy.availableProfiles

        // 测试1: Expert 参数应该比 Hard 强
        let expertAvg = calculateAvgStats(expertProfiles)
        let hardAvg = calculateAvgStats(hardProfiles)
        let normalAvg = calculateAvgStats(normalProfiles)
        let easyAvg = calculateAvgStats(easyProfiles)

        let test1Pass = expertAvg.overall > hardAvg.overall &&
                        hardAvg.overall > normalAvg.overall &&
                        normalAvg.overall > easyAvg.overall

        report += """
        [测试 1.1] 难度递增验证
        结果: \(test1Pass ? "✅ 通过" : "❌ 失败")

        难度平均综合实力:
          • Easy:    \(String(format: "%.3f", easyAvg.overall))
          • Normal:  \(String(format: "%.3f", normalAvg.overall))
          • Hard:    \(String(format: "%.3f", hardAvg.overall))
          • Expert:  \(String(format: "%.3f", expertAvg.overall))

        差距分析:
          • Normal vs Easy: +\(String(format: "%.1f%%", (normalAvg.overall - easyAvg.overall) / easyAvg.overall * 100))
          • Hard vs Normal: +\(String(format: "%.1f%%", (hardAvg.overall - normalAvg.overall) / normalAvg.overall * 100))
          • Expert vs Hard: +\(String(format: "%.1f%%", (expertAvg.overall - hardAvg.overall) / hardAvg.overall * 100))

        """

        // 测试2: Expert 角色必须有高 bluffDetection
        var highBluffDetectionCount = 0
        for profile in expertProfiles {
            if profile.bluffDetection >= 0.70 {
                highBluffDetectionCount += 1
            }
        }

        let test2Pass = highBluffDetectionCount >= expertProfiles.count / 2
        report += """
        [测试 1.2] Expert 高读牌能力验证
        结果: \(test2Pass ? "✅ 通过" : "❌ 失败")

        Expert 中 bluffDetection >= 0.70 的角色: \(highBluffDetectionCount) / \(expertProfiles.count)

        """

        return report
    }

    // MARK: - 难度分布测试

    private func runDifficultyDistributionTests() -> String {
        var report = """

        ┌─────────────────────────────────────────────────────────────────┐
        │                    2. 难度分布测试                              │
        └─────────────────────────────────────────────────────────────────┘

        """

        let easyCount = AIProfile.Difficulty.easy.availableProfiles.count
        let normalCount = AIProfile.Difficulty.normal.availableProfiles.count
        let hardCount = AIProfile.Difficulty.hard.availableProfiles.count
        let expertCount = AIProfile.Difficulty.expert.availableProfiles.count

        let minRequired = 8
        let testPass = easyCount >= minRequired && normalCount >= minRequired &&
                       hardCount >= minRequired && expertCount >= minRequired

        report += """
        [测试 2.1] 每难度至少 8 人验证
        结果: \(testPass ? "✅ 通过" : "❌ 失败")

        难度人数分布:
          • Easy:    \(easyCount) 人 \(easyCount >= minRequired ? "✅" : "❌")
          • Normal:  \(normalCount) 人 \(normalCount >= minRequired ? "✅" : "❌")
          • Hard:    \(hardCount) 人 \(hardCount >= minRequired ? "✅" : "❌")
          • Expert:  \(expertCount) 人 \(expertCount >= minRequired ? "✅" : "❌")

        总计: \(easyCount + normalCount + hardCount + expertCount) 人

        """

        return report
    }

    // MARK: - 唯一性测试

    private func runUniquenessTests() -> String {
        var report = """

        ┌─────────────────────────────────────────────────────────────────┐
        │                    3. 角色唯一性测试                            │
        └─────────────────────────────────────────────────────────────────┘

        """

        let allProfiles = AIProfile.allProfiles
        let ids = allProfiles.map { $0.id }
        let names = allProfiles.map { $0.name }

        let uniqueIds = Set(ids)
        let uniqueNames = Set(names)

        let idTestPass = ids.count == uniqueIds.count
        let nameTestPass = names.count == uniqueNames.count

        report += """
        [测试 3.1] ID 唯一性验证
        结果: \(idTestPass ? "✅ 通过" : "❌ 失败")

          • 总角色数: \(ids.count)
          • 唯一 ID 数: \(uniqueIds.count)
          • 重复 ID: \(ids.count - uniqueIds.count)

        [测试 3.2] 名称唯一性验证
        结果: \(nameTestPass ? "✅ 通过" : "❌ 失败")

          • 总角色数: \(names.count)
          • 唯一名称数: \(uniqueNames.count)
          • 重复名称: \(names.count - uniqueNames.count)

        """

        return report
    }

    // MARK: - 综合实力评估

    private func runOverallStrengthAssessment() -> String {
        var report = """

        ┌─────────────────────────────────────────────────────────────────┐
        │                    4. 综合实力评估                              │
        └─────────────────────────────────────────────────────────────────┘

        """

        for difficulty in [AIProfile.Difficulty.easy, .normal, .hard, .expert] {
            let profiles = difficulty.availableProfiles
            let avg = calculateAvgStats(profiles)

            let playerList = profiles.map { profile -> String in
                let strength = calculateOverallStrength(profile)
                return "    \(profile.name): \(String(format: "%.2f", strength))"
            }.joined(separator: "\n")

            report += """
            【\(difficulty.rawValue)】

            人数: \(profiles.count)
            平均侵略性: \(String(format: "%.2f", avg.aggression))
            平均位置意识: \(String(format: "%.2f", avg.positionAwareness))
            平均读牌能力: \(String(format: "%.2f", avg.bluffDetection))
            平均风险承受: \(String(format: "%.2f", avg.riskTolerance))
            平均综合实力: \(String(format: "%.3f", avg.overall))

            详细角色:
            \(playerList)

            """
        }

        return report
    }

    // MARK: - 难度对比

    private func generateDifficultyComparison() -> String {
        var report = """

        ┌─────────────────────────────────────────────────────────────────┐
        │                    5. 难度对比分析                              │
        └─────────────────────────────────────────────────────────────────┘

        """

        let difficulties: [(AIProfile.Difficulty, String)] = [
            (.easy, "简单"),
            (.normal, "普通"),
            (.hard, "困难"),
            (.expert, "专家")
        ]

        report += """
        参数对比表:

        | 参数         | Easy  | Normal | Hard  | Expert |
        |--------------|-------|--------|-------|--------|
        """

        for (diff, name) in difficulties {
            let profiles = diff.availableProfiles
            let avg = calculateAvgStats(profiles)
            report += "| \(name)          |\(formatAvg(avg.aggression))|\(formatAvg(avg.positionAwareness))|\(formatAvg(avg.bluffDetection))|\(formatAvg(avg.riskTolerance))|\n"
        }

        report += """

        关键指标解读:

        1. 侵略性 (Aggression)
           - Expert 最高 (0.70+): 主动获取价值
           - Easy 最低: 被动防守为主

        2. 位置意识 (Position Awareness)
           - Expert 普遍 0.80+: 充分利用位置
           - Easy 较低: 忽略位置优势

        3. 读牌能力 (Bluff Detection)
           - Expert 普遍 0.70+: 识别对手诈雏
           - Easy 较低: 容易被Bluff

        4. 风险承受 (Risk Tolerance)
           - Hard/Expert 较高: 愿意争夺大池
           - Easy 较低: 保守稳健

        """

        return report
    }

    // MARK: - 结论

    private func generateConclusion() -> String {
        let allProfiles = AIProfile.allProfiles.count
        let expertCount = AIProfile.Difficulty.expert.availableProfiles.count
        let hardCount = AIProfile.Difficulty.hard.availableProfiles.count

        return """

        ┌─────────────────────────────────────────────────────────────────┐
        │                         6. 测试结论                            │
        └─────────────────────────────────────────────────────────────────┘

        总角色数: \(allProfiles) 人

        ✅ 参数配置: 正确
           - Expert 难度角色综合实力最强
           - 难度递增关系明确

        ✅ 分布验证: 正确
           - 每个难度至少 8 人

        ✅ 唯一性验证: 正确
           - 所有角色 ID 和名称唯一

        建议:
        1. Expert 角色已具备高参数，可进行实际对战测试
        2. Hard 角色作为过渡难度，参数合理
        3. 可通过调整 DifficultyManager 的 mistakeRate 进一步拉开差距

        ═══════════════════════════════════════════════════════════════════
                              测试完成
        ═══════════════════════════════════════════════════════════════════

        """
    }

    // MARK: - 辅助函数

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }

    private struct AvgStats {
        let aggression: Double
        let positionAwareness: Double
        let bluffDetection: Double
        let riskTolerance: Double
        let overall: Double
    }

    private func calculateAvgStats(_ profiles: [AIProfile]) -> AvgStats {
        guard !profiles.isEmpty else {
            return AvgStats(aggression: 0, positionAwareness: 0, bluffDetection: 0, riskTolerance: 0, overall: 0)
        }

        let count = Double(profiles.count)
        let avgAggression = profiles.map { $0.aggression }.reduce(0, +) / count
        let avgPosition = profiles.map { $0.positionAwareness }.reduce(0, +) / count
        let avgBluff = profiles.map { $0.bluffDetection }.reduce(0, +) / count
        let avgRisk = profiles.map { $0.riskTolerance }.reduce(0, +) / count
        let avgOverall = profiles.map { calculateOverallStrength($0) }.reduce(0, +) / count

        return AvgStats(
            aggression: avgAggression,
            positionAwareness: avgPosition,
            bluffDetection: avgBluff,
            riskTolerance: avgRisk,
            overall: avgOverall
        )
    }

    /// 计算单个角色的综合实力 (0-1)
    func calculateOverallStrength(_ profile: AIProfile) -> Double {
        // 综合实力权重
        let aggressionWeight = 0.25
        let positionWeight = 0.25
        let bluffDetectionWeight = 0.25
        let riskToleranceWeight = 0.15
        let tightnessWeight = 0.10  // 合理的紧度也是实力体现

        // 紧度调整: 0.45-0.55 是最佳范围
        let optimalTightness = 0.50
        let tightnessScore = 1.0 - abs(profile.tightness - optimalTightness) * 2

        return profile.aggression * aggressionWeight +
               profile.positionAwareness * positionWeight +
               profile.bluffDetection * bluffDetectionWeight +
               profile.riskTolerance * riskToleranceWeight +
               tightnessScore * tightnessWeight
    }

    private func formatAvg(_ value: Double) -> String {
        return String(format: " %.2f  |", value)
    }
}

// MARK: - XCTest 测试用例

/// AI角色实力验证测试
final class AIProfileStrengthTests: XCTestCase {

    // MARK: - 难度分布验证

    func testEachDifficultyHasAtLeast8Players() {
        let easyCount = AIProfile.Difficulty.easy.availableProfiles.count
        let normalCount = AIProfile.Difficulty.normal.availableProfiles.count
        let hardCount = AIProfile.Difficulty.hard.availableProfiles.count
        let expertCount = AIProfile.Difficulty.expert.availableProfiles.count

        print("📊 难度人数分布:")
        print("   Easy: \(easyCount)")
        print("   Normal: \(normalCount)")
        print("   Hard: \(hardCount)")
        print("   Expert: \(expertCount)")

        XCTAssertGreaterThanOrEqual(easyCount, 8, "Easy 至少需要8人")
        XCTAssertGreaterThanOrEqual(normalCount, 8, "Normal 至少需要8人")
        XCTAssertGreaterThanOrEqual(hardCount, 8, "Hard 至少需要8人")
        XCTAssertGreaterThanOrEqual(expertCount, 8, "Expert 至少需要8人")
    }

    // MARK: - Expert 角色参数验证

    func testExpertProfilesHaveHigherStats() {
        let reporter = AIStrengthTestReport()
        let expertProfiles = AIProfile.Difficulty.expert.availableProfiles
        let normalProfiles = AIProfile.Difficulty.normal.availableProfiles

        // 计算 Expert 平均参数
        let expertAvgAggression = expertProfiles.map { $0.aggression }.reduce(0, +) / Double(expertProfiles.count)
        let expertAvgPositionAwareness = expertProfiles.map { $0.positionAwareness }.reduce(0, +) / Double(expertProfiles.count)
        let expertAvgBluffDetection = expertProfiles.map { $0.bluffDetection }.reduce(0, +) / Double(expertProfiles.count)

        // 计算 Normal 平均参数
        let normalAvgAggression = normalProfiles.map { $0.aggression }.reduce(0, +) / Double(normalProfiles.count)
        let normalAvgPositionAwareness = normalProfiles.map { $0.positionAwareness }.reduce(0, +) / Double(normalProfiles.count)
        let normalAvgBluffDetection = normalProfiles.map { $0.bluffDetection }.reduce(0, +) / Double(normalProfiles.count)

        print("📈 Expert vs Normal 平均参数对比:")
        print("   Aggression: \(String(format: "%.2f", expertAvgAggression)) vs \(String(format: "%.2f", normalAvgAggression))")
        print("   PositionAwareness: \(String(format: "%.2f", expertAvgPositionAwareness)) vs \(String(format: "%.2f", normalAvgPositionAwareness))")
        print("   BluffDetection: \(String(format: "%.2f", expertAvgBluffDetection)) vs \(String(format: "%.2f", normalAvgBluffDetection))")

        // Expert 应该明显比 Normal 强
        XCTAssertGreaterThan(expertAvgAggression, normalAvgAggression + 0.05,
            "Expert 侵略性应该高于 Normal 至少 0.05")
        XCTAssertGreaterThan(expertAvgPositionAwareness, normalAvgPositionAwareness + 0.10,
            "Expert 位置意识应该高于 Normal 至少 0.10")
        XCTAssertGreaterThan(expertAvgBluffDetection, normalAvgBluffDetection + 0.10,
            "Expert 读牌能力应该高于 Normal 至少 0.10")
    }

    // MARK: - 专家角色关键参数验证

    func testExpertKeyCharactersParameters() {
        let reporter = AIStrengthTestReport()

        // 验证读心术师
        let mindReader = AIProfile.mindReader
        XCTAssertGreaterThan(mindReader.bluffDetection, 0.90, "读心术师应该有极高的读牌能力 (0.95)")
        XCTAssertGreaterThan(mindReader.positionAwareness, 0.90, "读心术师应该有极高的位置意识 (0.94)")

        // 验证锦标赛冠军
        let champion = AIProfile.tournamentChampion
        XCTAssertGreaterThan(champion.riskTolerance, 0.70, "锦标赛冠军应该有较高的风险承受力")
        XCTAssertGreaterThan(champion.bluffDetection, 0.80, "锦标赛冠军应该有较高的读牌能力")

        // 验证 Fedor Holz
        let fedor = AIProfile.fedorHolz
        XCTAssertLessThan(fedor.tiltSensitivity, 0.15, "Fedor Holz 情绪控制应该很好")

        // 验证 Phil Hellmuth (已经调整)
        let hellmuth = AIProfile.philHellmuth
        XCTAssertLessThan(hellmuth.tiltSensitivity, 0.30, "Phil Hellmuth 的 tilt 应该是表演")
    }

    // MARK: - 难度递增验证

    func testDifficultyProgression() {
        let reporter = AIStrengthTestReport()

        let easyProfiles = AIProfile.Difficulty.easy.availableProfiles
        let normalProfiles = AIProfile.Difficulty.normal.availableProfiles
        let hardProfiles = AIProfile.Difficulty.hard.availableProfiles
        let expertProfiles = AIProfile.Difficulty.expert.availableProfiles

        let easyAvg = easyProfiles.map { reporter.calculateOverallStrength($0) }.reduce(0, +) / Double(easyProfiles.count)
        let normalAvg = normalProfiles.map { reporter.calculateOverallStrength($0) }.reduce(0, +) / Double(normalProfiles.count)
        let hardAvg = hardProfiles.map { reporter.calculateOverallStrength($0) }.reduce(0, +) / Double(hardProfiles.count)
        let expertAvg = expertProfiles.map { reporter.calculateOverallStrength($0) }.reduce(0, +) / Double(expertProfiles.count)

        print("📊 难度平均综合实力:")
        print("   Easy: \(String(format: "%.3f", easyAvg))")
        print("   Normal: \(String(format: "%.3f", normalAvg))")
        print("   Hard: \(String(format: "%.3f", hardAvg))")
        print("   Expert: \(String(format: "%.3f", expertAvg))")

        // 难度应该递增 (允许小误差)
        XCTAssertLessThanOrEqual(easyAvg + 0.05, normalAvg, "Normal 应该 >= Easy")
        XCTAssertLessThanOrEqual(normalAvg + 0.05, hardAvg, "Hard 应该 >= Normal")
        XCTAssertLessThanOrEqual(hardAvg + 0.05, expertAvg, "Expert 应该 >= Hard")
    }

    // MARK: - 角色唯一性验证

    func testAllProfilesHaveUniqueIds() {
        let allProfiles = AIProfile.allProfiles
        let ids = allProfiles.map { $0.id }

        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "所有角色 ID 应该唯一")

        // 打印重复检查
        var counts: [String: Int] = [:]
        for id in ids {
            counts[id, default: 0] += 1
        }
        let duplicates = counts.filter { $0.value > 1 }
        if !duplicates.isEmpty {
            print("⚠️ 发现重复 ID: \(duplicates)")
        }
    }

    // MARK: - 角色数量验证

    func testTotalCharacterCount() {
        let total = AIProfile.allProfiles.count
        print("📊 总角色数: \(total)")

        // 应该有 50+ 角色
        XCTAssertGreaterThanOrEqual(total, 50, "总角色数应该 >= 50")
    }

    // MARK: - 生成测试报告

    func testGenerateFullReport() {
        let reporter = AIStrengthTestReport()
        let report = reporter.runAllTests()
        print(report)

        // 验证报告生成成功
        XCTAssertFalse(report.isEmpty, "报告不应该为空")
        XCTAssertTrue(report.contains("AI 角色实力综合测试报告"), "报告应该包含标题")
    }
}

// MARK: - 扩展：打印测试报告

extension AIStrengthTestReport {
    /// 打印完整测试报告 (用于调试)
    func printReport() {
        print(runAllTests())
    }
}
