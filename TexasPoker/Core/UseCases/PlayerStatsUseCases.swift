import Foundation

final class GetPlayerStatsUseCase {
    private let repository: StatisticsRepositoryProtocol

    init(repository: StatisticsRepositoryProtocol = CoreDataRepository.shared) {
        self.repository = repository
    }

    func execute(playerId: String, gameMode: GameMode) async throws -> PlayerStats {
        guard let stats = try await repository.fetchPlayerStats(playerId: playerId, gameMode: gameMode) else {
            return PlayerStats(
                playerName: playerId,
                gameMode: gameMode,
                isHuman: playerId == "Hero",
                totalHands: 0,
                vpip: 0,
                pfr: 0,
                af: 0,
                wtsd: 0,
                wsd: 0,
                threeBet: 0,
                handsWon: 0,
                totalWinnings: 0,
                totalInvested: 0
            )
        }
        return stats
    }
}

final class GetAllPlayersStatsUseCase {
    private let repository: StatisticsRepositoryProtocol

    init(repository: StatisticsRepositoryProtocol = CoreDataRepository.shared) {
        self.repository = repository
    }

    func execute(gameMode: GameMode) async throws -> [String: PlayerStats] {
        try await repository.fetchAllPlayerStats(gameMode: gameMode)
    }
}

final class SavePlayerStatsUseCase {
    private let repository: StatisticsRepositoryProtocol

    init(repository: StatisticsRepositoryProtocol = CoreDataRepository.shared) {
        self.repository = repository
    }

    func execute(stats: PlayerStats) async throws {
        try await repository.savePlayerStats(stats)
    }
}

final class GetAllPlayerNamesUseCase {
    private let statisticsCalculator: StatisticsCalculator

    init(statisticsCalculator: StatisticsCalculator = .shared) {
        self.statisticsCalculator = statisticsCalculator
    }

    func execute(gameMode: GameMode) -> [String] {
        statisticsCalculator.fetchAllPlayerNames(gameMode: gameMode)
    }
}

final class GetHandHistoryUseCase {
    private let statisticsCalculator: StatisticsCalculator

    init(statisticsCalculator: StatisticsCalculator = .shared) {
        self.statisticsCalculator = statisticsCalculator
    }

    func execute(playerName: String, gameMode: GameMode) -> [StatisticsCalculator.HandHistorySummary] {
        statisticsCalculator.fetchHandHistoriesForPlayer(playerName: playerName, gameMode: gameMode)
    }
}

final class GetPlayerStatsForViewUseCase {
    private let statisticsCalculator: StatisticsCalculator

    init(statisticsCalculator: StatisticsCalculator = .shared) {
        self.statisticsCalculator = statisticsCalculator
    }

    func execute(playerName: String, gameMode: GameMode) -> PlayerStats? {
        statisticsCalculator.calculateStats(playerName: playerName, gameMode: gameMode)
    }
}
