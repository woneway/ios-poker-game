import Foundation
import CoreData

final class CoreDataRepository: PlayerRepositoryProtocol, StatisticsRepositoryProtocol, HandHistoryRepositoryProtocol {
    static let shared = CoreDataRepository()

    // Convenience accessors for other repositories
    static var gameRepository: GameRepository { GameRepository.shared }
    static var settingsRepository: SettingsRepository { SettingsRepository.shared }

    private let context: NSManagedObjectContext

    private init() {
        self.context = PersistenceController.shared.container.viewContext
    }

    func fetchAllPlayers() async throws -> [Player] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PlayerEntity")
        let results = try context.fetch(request)
        return results.compactMap { entity -> Player? in
            guard let name = entity.value(forKey: "name") as? String,
                  let chips = entity.value(forKey: "chips") as? Int else {
                return nil
            }
            return Player(
                name: name,
                chips: chips,
                isHuman: entity.value(forKey: "isHuman") as? Bool ?? false,
                aiProfile: nil,
                entryIndex: Int(entity.value(forKey: "entryIndex") as? Int32 ?? 1)
            )
        }
    }

    func fetchPlayer(byId id: UUID) async throws -> Player? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PlayerEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        let results = try context.fetch(request)
        guard let entity = results.first,
              let name = entity.value(forKey: "name") as? String,
              let chips = entity.value(forKey: "chips") as? Int else {
            return nil
        }
        return Player(
            name: name,
            chips: chips,
            isHuman: entity.value(forKey: "isHuman") as? Bool ?? false,
            aiProfile: nil,
            entryIndex: Int(entity.value(forKey: "entryIndex") as? Int32 ?? 1)
        )
    }

    func savePlayer(_ player: Player) async throws {
        let entity = NSEntityDescription.insertNewObject(forEntityName: "PlayerEntity", into: context)
        entity.setValue(UUID(), forKey: "id")
        entity.setValue(player.name, forKey: "name")
        entity.setValue(player.chips, forKey: "chips")
        entity.setValue(player.isHuman, forKey: "isHuman")
        entity.setValue(Int32(player.entryIndex), forKey: "entryIndex")
        try context.save()
    }

    func deletePlayer(byId id: UUID) async throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PlayerEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let results = try context.fetch(request)
        results.forEach { context.delete($0) }
        try context.save()
    }

    func fetchPlayerStats(playerId: String, gameMode: GameMode) async throws -> PlayerStats? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
        request.predicate = NSPredicate(
            format: "playerName == %@ AND gameMode == %@",
            playerId, gameMode.rawValue
        )
        request.fetchLimit = 1
        let results = try context.fetch(request)
        guard let entity = results.first else { return nil }
        return PlayerStats(
            playerName: entity.value(forKey: "playerName") as? String ?? "",
            gameMode: gameMode,
            isHuman: entity.value(forKey: "isHuman") as? Bool ?? false,
            totalHands: Int(entity.value(forKey: "totalHands") as? Int32 ?? 0),
            vpip: entity.value(forKey: "vpip") as? Double ?? 0,
            pfr: entity.value(forKey: "pfr") as? Double ?? 0,
            af: entity.value(forKey: "af") as? Double ?? 0,
            wtsd: entity.value(forKey: "wtsd") as? Double ?? 0,
            wsd: entity.value(forKey: "wsd") as? Double ?? 0,
            threeBet: entity.value(forKey: "threeBet") as? Double ?? 0,
            handsWon: Int(entity.value(forKey: "handsWon") as? Int32 ?? 0),
            totalWinnings: Int(entity.value(forKey: "totalWinnings") as? Int32 ?? 0),
            totalInvested: Int(entity.value(forKey: "totalInvested") as? Int32 ?? 0)
        )
    }

    func fetchAllPlayerStats(gameMode: GameMode) async throws -> [String: PlayerStats] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
        request.predicate = NSPredicate(format: "gameMode == %@", gameMode.rawValue)
        let results = try context.fetch(request)
        var statsDict: [String: PlayerStats] = [:]
        for entity in results {
            guard let playerName = entity.value(forKey: "playerName") as? String else { continue }
            statsDict[playerName] = PlayerStats(
                playerName: playerName,
                gameMode: gameMode,
                isHuman: entity.value(forKey: "isHuman") as? Bool ?? false,
                totalHands: Int(entity.value(forKey: "totalHands") as? Int32 ?? 0),
                vpip: entity.value(forKey: "vpip") as? Double ?? 0,
                pfr: entity.value(forKey: "pfr") as? Double ?? 0,
                af: entity.value(forKey: "af") as? Double ?? 0,
                wtsd: entity.value(forKey: "wtsd") as? Double ?? 0,
                wsd: entity.value(forKey: "wsd") as? Double ?? 0,
                threeBet: entity.value(forKey: "threeBet") as? Double ?? 0,
                handsWon: Int(entity.value(forKey: "handsWon") as? Int32 ?? 0),
                totalWinnings: Int(entity.value(forKey: "totalWinnings") as? Int32 ?? 0),
                totalInvested: Int(entity.value(forKey: "totalInvested") as? Int32 ?? 0)
            )
        }
        return statsDict
    }

    func savePlayerStats(_ stats: PlayerStats) async throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
        request.predicate = NSPredicate(
            format: "playerName == %@ AND gameMode == %@",
            stats.playerName, stats.gameMode.rawValue
        )
        let existing = try context.fetch(request)
        let entity = existing.first ?? NSEntityDescription.insertNewObject(
            forEntityName: "PlayerStatsEntity",
            into: context
        )
        entity.setValue(stats.playerName, forKey: "playerName")
        entity.setValue(stats.gameMode.rawValue, forKey: "gameMode")
        entity.setValue(stats.isHuman, forKey: "isHuman")
        entity.setValue(Int32(stats.totalHands), forKey: "totalHands")
        entity.setValue(stats.vpip, forKey: "vpip")
        entity.setValue(stats.pfr, forKey: "pfr")
        entity.setValue(stats.af, forKey: "af")
        entity.setValue(stats.wtsd, forKey: "wtsd")
        entity.setValue(stats.wsd, forKey: "wsd")
        entity.setValue(stats.threeBet, forKey: "threeBet")
        entity.setValue(Int32(stats.handsWon), forKey: "handsWon")
        entity.setValue(Int32(stats.totalWinnings), forKey: "totalWinnings")
        entity.setValue(Int32(stats.totalInvested), forKey: "totalInvested")
        try context.save()
    }

    func fetchHandHistory(gameMode: GameMode?, limit: Int) async throws -> [HandHistoryEntity] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "HandHistoryEntity")
        if let mode = gameMode {
            request.predicate = NSPredicate(format: "gameMode == %@", mode.rawValue)
        }
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = limit
        return try context.fetch(request) as? [HandHistoryEntity] ?? []
    }

    func saveHandHistory(_ hand: HandHistoryEntity) async throws {
        try context.save()
    }

    func fetchActions(forHandId handId: UUID) async throws -> [ActionEntity] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ActionEntity")
        request.predicate = NSPredicate(format: "handHistory.id == %@", handId as CVarArg)
        return try context.fetch(request) as? [ActionEntity] ?? []
    }
}

// MARK: - Game Repository Implementation (UserDefaults-based)

final class GameRepository: GameRepositoryProtocol {
    static let shared = GameRepository()

    private let historyManager = GameHistoryManager.shared

    private init() {}

    func fetchGameHistory(limit: Int) async throws -> [GameRecord] {
        let records = historyManager.records
        return Array(records.prefix(limit))
    }

    func saveGameRecord(_ record: GameRecord) async throws {
        historyManager.saveRecord(record)
    }

    func deleteGameRecord(byId id: UUID) async throws {
        // GameHistoryManager uses array, need to filter by id
        var records = historyManager.records
        records.removeAll { $0.id == id }
        // Note: This requires modifying GameHistoryManager to support this
        // For now, we'll clear and re-save
        historyManager.clearHistory()
        for record in records {
            historyManager.saveRecord(record)
        }
    }
}

// MARK: - Settings Repository Implementation (UserDefaults-based)

final class SettingsRepository: SettingsRepositoryProtocol {
    static let shared = SettingsRepository()

    private init() {}

    func fetchSettings() -> GameSettings {
        GameSettings()
    }

    func saveSettings(_ settings: GameSettings) throws {
        // GameSettings uses @Published with UserDefaults auto-sync
        // No explicit save needed - changes are persisted automatically via didSet
        // Force a sync by accessing a UserDefaults key
        UserDefaults.standard.synchronize()
    }
}
