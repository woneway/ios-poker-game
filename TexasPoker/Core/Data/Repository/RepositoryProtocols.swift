import Foundation
import CoreData

protocol PlayerRepositoryProtocol {
    func fetchAllPlayers() async throws -> [Player]
    func fetchPlayer(byId id: UUID) async throws -> Player?
    func savePlayer(_ player: Player) async throws
    func deletePlayer(byId id: UUID) async throws
}

protocol GameRepositoryProtocol {
    func fetchGameHistory(limit: Int) async throws -> [GameRecord]
    func saveGameRecord(_ record: GameRecord) async throws
    func deleteGameRecord(byId id: UUID) async throws
}

protocol StatisticsRepositoryProtocol {
    func fetchPlayerStats(playerId: String, gameMode: GameMode) async throws -> PlayerStats?
    func fetchAllPlayerStats(gameMode: GameMode) async throws -> [String: PlayerStats]
    func savePlayerStats(_ stats: PlayerStats) async throws
}

protocol SettingsRepositoryProtocol {
    func fetchSettings() -> GameSettings
    func saveSettings(_ settings: GameSettings) throws
}

protocol HandHistoryRepositoryProtocol {
    func fetchHandHistory(gameMode: GameMode?, limit: Int) async throws -> [HandHistoryEntity]
    func saveHandHistory(_ hand: HandHistoryEntity) async throws
    func fetchActions(forHandId handId: UUID) async throws -> [ActionEntity]
}
