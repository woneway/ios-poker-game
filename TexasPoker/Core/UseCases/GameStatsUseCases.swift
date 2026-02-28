import Foundation

final class SaveGameStatsUseCase {
    private let statisticsCalculator: StatisticsCalculator
    private let dataAnalysisEngine: DataAnalysisEngine

    init(
        statisticsCalculator: StatisticsCalculator = .shared,
        dataAnalysisEngine: DataAnalysisEngine = .shared
    ) {
        self.statisticsCalculator = statisticsCalculator
        self.dataAnalysisEngine = dataAnalysisEngine
    }

    func execute(
        playerName: String,
        gameMode: GameMode,
        action: PlayerAction,
        won: Bool,
        amount: Int,
        profileId: String? = nil
    ) {
        statisticsCalculator.incrementalUpdate(
            playerName: playerName,
            playerUniqueId: nil,
            gameMode: gameMode,
            action: action,
            won: won,
            amount: amount,
            profileId: profileId
        )
    }

    func executeRecordHand(_ hand: DataAnalysisEngine.HandRecord) {
        dataAnalysisEngine.recordHand(hand)
    }
}

final class GetLeaderboardUseCase {
    private let statisticsCalculator: StatisticsCalculator

    init(statisticsCalculator: StatisticsCalculator = .shared) {
        self.statisticsCalculator = statisticsCalculator
    }

    func execute(gameMode: GameMode, limit: Int = 10) -> [LeaderboardEntry] {
        let allStats = statisticsCalculator.fetchAllPlayersStats(gameMode: gameMode)

        return allStats
            .map { name, stats in
                LeaderboardEntry(
                    rank: 0,
                    playerName: name,
                    totalHands: stats.totalHands,
                    winRate: stats.totalHands > 0 ? Double(stats.handsWon) / Double(stats.totalHands) * 100 : 0,
                    totalProfit: stats.totalWinnings
                )
            }
            .sorted { $0.totalProfit > $1.totalProfit }
            .prefix(limit)
            .enumerated()
            .map { index, entry in
                var updated = entry
                updated.rank = index + 1
                return updated
            }
    }
}

struct LeaderboardEntry: Identifiable {
    var id: String { "\(rank)-\(playerName)" }
    var rank: Int
    var playerName: String
    var totalHands: Int
    var winRate: Double
    var totalProfit: Int
}
