import Foundation
import SwiftUI

struct AIVerificationConfig {
    var tournamentCount: Int = 10
    var handsPerTournament: Int = 50
    var startingChips: Int = 1000
    
    static let `default` = AIVerificationConfig()
}

struct AIVerificationResult: Identifiable {
    let id = UUID()
    let profileName: String
    let expectedRank: Int
    let actualRank: Double
    let deviation: Int
    let status: VerificationStatus
    
    enum VerificationStatus: String {
        case ahead = "超前"
        case onTrack = "符合"
        case behind = "落后"
    }
}

@Observable
class AIVerificationRunner {
    var isRunning: Bool = false
    var progress: Double = 0
    var currentGame: Int = 0
    var results: [AIVerificationResult] = []
    var selectedProfiles: [AIProfile] = []
    var selectedDifficulties: Set<AIProfile.Difficulty> = [.easy]
    
    private var isCancelled = false
    
    func setSelectedDifficulties(_ difficulties: [AIProfile.Difficulty]) {
        selectedDifficulties = Set(difficulties)
        updateSelectedProfiles()
    }
    
    func toggleProfile(_ profile: AIProfile) {
        if let index = selectedProfiles.firstIndex(where: { $0.id == profile.id }) {
            selectedProfiles.remove(at: index)
        } else {
            selectedProfiles.append(profile)
        }
    }
    
    func selectAll() {
        selectedProfiles = AIProfile.allAvailableProfiles
        selectedDifficulties = Set(AIProfile.Difficulty.allCases)
    }
    
    func deselectAll() {
        selectedProfiles = []
        selectedDifficulties = []
    }
    
    private func updateSelectedProfiles() {
        var seen = Set<String>()
        var uniqueProfiles: [AIProfile] = []
        for profile in selectedDifficulties.flatMap({ $0.availableProfiles }) {
            if !seen.contains(profile.id) {
                seen.insert(profile.id)
                uniqueProfiles.append(profile)
            }
        }
        selectedProfiles = uniqueProfiles
    }
    
    func calculateExpectedRank(for profile: AIProfile, in totalPlayers: Int) -> Int {
        let score = profile.aggression * 30 + profile.positionAwareness * 20 + (1 - profile.tightness) * 15
        let normalizedScore = score / 65.0
        let expectedRank = Int((1 - normalizedScore) * Double(totalPlayers - 1)) + 1
        return max(1, min(totalPlayers, expectedRank))
    }
    
    func runVerification(config: AIVerificationConfig) {
        guard !selectedProfiles.isEmpty else { return }

        isRunning = true
        progress = 0
        currentGame = 0
        results = []
        isCancelled = false

        // 验证功能使用后台线程（PokerEngineLite线程安全）
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // 安全检查：确保配置参数合理
            guard config.tournamentCount > 0, config.handsPerTournament > 0 else {
                #if DEBUG
                print("⚠️ AIVerificationRunner: 无效的配置参数")
                #endif
                DispatchQueue.main.async {
                    self.isRunning = false
                }
                return
            }

            let evaluator = AITournamentEvaluator(config: AITournamentEvaluator.TournamentConfig(
                playerCount: self.selectedProfiles.count,
                games: config.tournamentCount,
                startingChips: config.startingChips,
                maxHandsPerGame: config.handsPerTournament
            ))

            for profile in self.selectedProfiles {
                evaluator.profilesMap[profile.name] = profile
            }

            // 初始化累积结果
            evaluator.resetCumulativeResults(for: self.selectedProfiles)

            // 每隔N场更新一次UI，减少UI更新频率和内存占用
            // 至少每5场更新一次，避免频繁UI刷新导致内存问题
            // 如果比赛场次少于5场，则只在最后更新一次
            let updateInterval = config.tournamentCount >= 5 ? max(5, config.tournamentCount / 5) : config.tournamentCount

            // 用于跟踪连续失败的次数
            var consecutiveFailures = 0
            let maxConsecutiveFailures = 3

            for i in 1...config.tournamentCount {
                if self.isCancelled {
                    break
                }

                // 运行单场比赛
                let gameResults = evaluator.runSingleGameForProgress(profiles: self.selectedProfiles)

                // 检查结果是否有效
                if gameResults.isEmpty {
                    consecutiveFailures += 1
                    #if DEBUG
                    print("⚠️ AIVerificationRunner 第\(i)场比赛结果为空")
                    #endif

                    if consecutiveFailures >= maxConsecutiveFailures {
                        #if DEBUG
                        print("⚠️ AIVerificationRunner: 连续\(maxConsecutiveFailures)场比赛失败，停止验证")
                        #endif
                        break
                    }
                    continue
                }

                consecutiveFailures = 0

                // 更新累积结果
                evaluator.updateCumulativeResults(with: gameResults)

                // 每隔N场或最后一场才更新UI
                if i % updateInterval == 0 || i == config.tournamentCount {
                    // 获取累积结果（不重新计算）
                    let partialResults = evaluator.getCumulativeResults()
                    let totalPlayers = self.selectedProfiles.count

                    var partialFinalResults: [AIVerificationResult] = []
                    for result in partialResults {
                        let expectedRank = self.calculateExpectedRank(for: result.profile, in: totalPlayers)
                        let deviation = expectedRank - Int(result.avgRank)
                        let status: AIVerificationResult.VerificationStatus
                        if deviation <= -5 { status = .ahead }
                        else if deviation >= 5 { status = .behind }
                        else { status = .onTrack }

                        partialFinalResults.append(AIVerificationResult(
                            profileName: result.profile.name,
                            expectedRank: expectedRank,
                            actualRank: result.avgRank,
                            deviation: deviation,
                            status: status
                        ))
                    }
                    partialFinalResults.sort { $0.actualRank < $1.actualRank }

                    DispatchQueue.main.async {
                        self.currentGame = i
                        self.progress = Double(i) / Double(config.tournamentCount)
                        self.results = partialFinalResults
                    }
                }
            }

            if !self.isCancelled {
                // 使用累积结果作为最终结果
                let evaluatorResults = evaluator.getCumulativeResults()
                let totalPlayers = self.selectedProfiles.count

                // 检查是否有有效结果
                guard !evaluatorResults.isEmpty else {
                    #if DEBUG
                    print("⚠️ AIVerificationRunner: 没有有效的评估结果")
                    #endif
                    DispatchQueue.main.async {
                        self.isRunning = false
                    }
                    return
                }

                var finalResults: [AIVerificationResult] = []

                for result in evaluatorResults {
                    let expectedRank = self.calculateExpectedRank(for: result.profile, in: totalPlayers)
                    let deviation = expectedRank - Int(result.avgRank)

                    let status: AIVerificationResult.VerificationStatus
                    if deviation <= -5 {
                        status = .ahead
                    } else if deviation >= 5 {
                        status = .behind
                    } else {
                        status = .onTrack
                    }

                    finalResults.append(AIVerificationResult(
                        profileName: result.profile.name,
                        expectedRank: expectedRank,
                        actualRank: result.avgRank,
                        deviation: deviation,
                        status: status
                    ))
                }

                finalResults.sort { $0.actualRank < $1.actualRank }

                DispatchQueue.main.async {
                    self.results = finalResults
                    self.isRunning = false
                    self.progress = 1.0
                }

                self.saveResults(finalResults)
            } else {
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }
    
    func stopVerification() {
        isCancelled = true
        isRunning = false
    }
    
    private func saveResults(_ results: [AIVerificationResult]) {
        let jsonData: [[String: Any]] = results.map { result in
            [
                "profile": result.profileName,
                "expected": result.expectedRank,
                "actual": result.actualRank,
                "deviation": result.deviation,
                "status": result.status.rawValue
            ]
        }
        if let data = try? JSONSerialization.data(withJSONObject: jsonData) {
            UserDefaults.standard.set(data, forKey: "AIVerificationResults")
        }
    }
}
