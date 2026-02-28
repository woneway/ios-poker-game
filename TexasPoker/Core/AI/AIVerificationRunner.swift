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
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let evaluator = AITournamentEvaluator(config: AITournamentEvaluator.TournamentConfig(
                playerCount: self.selectedProfiles.count,
                games: config.tournamentCount,
                startingChips: config.startingChips,
                maxHandsPerGame: config.handsPerTournament
            ))
            
            for profile in self.selectedProfiles {
                evaluator.profilesMap[profile.name] = profile
            }
            
            for i in 1...config.tournamentCount {
                if self.isCancelled { 
                    break 
                }
                
                do {
                    _ = evaluator.runSingleGameForProgress(profiles: self.selectedProfiles)
                } catch {
                    print("Error running game: \(error)")
                    break
                }
                
                let partialResults = evaluator.runEvaluationWithProfiles(self.selectedProfiles)
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
            
            if !self.isCancelled {
                let evaluatorResults = evaluator.runEvaluationWithProfiles(self.selectedProfiles)
                let totalPlayers = self.selectedProfiles.count
                
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
