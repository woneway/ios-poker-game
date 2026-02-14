import Foundation
import CoreData

/// Manages data migration from UserDefaults to Core Data
class DataMigrationManager {
    static let shared = DataMigrationManager()
    
    private let migrationKey = "statistics_migration_completed"
    private var context: NSManagedObjectContext {
        PersistenceController.shared.container.viewContext
    }
    
    private init() {}
    
    // MARK: - Migration Status
    
    var isMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: migrationKey)
    }
    
    func markMigrationCompleted() {
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
    
    // MARK: - Main Migration
    
    /// Migrate all legacy statistics data to Core Data
    func migrateIfNeeded() {
        guard !isMigrationCompleted else {
            print("✅ Statistics migration already completed")
            return
        }
        
        print("🔄 Starting statistics migration...")
        
        // Migrate legacy player stats if they exist
        migrateLegacyPlayerStats()
        
        // Migrate game history to hand history if needed
        migrateGameHistoryToHandHistory()

        // Backfill new fields (e.g. profileId) for existing rows
        backfillDefaultProfileIdIfMissing()
        
        // Mark migration as complete
        markMigrationCompleted()
        print("✅ Statistics migration completed")
    }
    
    // MARK: - Legacy Player Stats Migration
    
    private func migrateLegacyPlayerStats() {
        // Check for legacy statistics format in UserDefaults
        // Format: "player_stats_<playerName>_<gameMode>"
        let defaults = UserDefaults.standard
        let dictionaryRepresentation = defaults.dictionaryRepresentation()
        
        var migratedCount = 0
        
        for (key, value) in dictionaryRepresentation {
            // Look for keys matching legacy format
            if key.hasPrefix("player_stats_"), let statsDict = value as? [String: Any] {
                if let stats = parseLegacyStats(from: statsDict, key: key) {
                    // Create or update PlayerStatsEntity
                    createOrUpdateStatsEntity(stats: stats)
                    migratedCount += 1
                }
            }
        }
        
        if migratedCount > 0 {
            print("📊 Migrated \(migratedCount) legacy player statistics")
        } else {
            print("ℹ️ No legacy player statistics found to migrate")
        }
    }
    
    private func parseLegacyStats(from dict: [String: Any], key: String) -> PlayerStats? {
        // Parse key: "player_stats_<playerName>_<gameMode>"
        let components = key.components(separatedBy: "_")
        guard components.count >= 4 else { return nil }
        
        let playerName = components[2]
        let gameModeStr = components[3]
        let gameMode = GameMode(rawValue: gameModeStr) ?? .cashGame
        
        // Extract stats from dictionary
        guard let totalHands = dict["totalHands"] as? Int,
              let vpip = dict["vpip"] as? Double,
              let pfr = dict["pfr"] as? Double else {
            return nil
        }
        
        let af = dict["af"] as? Double ?? 0.0
        let wtsd = dict["wtsd"] as? Double ?? 0.0
        let wsd = dict["wsd"] as? Double ?? 0.0
        let threeBet = dict["threeBet"] as? Double ?? 0.0
        let handsWon = dict["handsWon"] as? Int ?? 0
        let totalWinnings = dict["totalWinnings"] as? Int ?? 0

        // Determine if this player is human (hero player is human)
        let isHuman = playerName.lowercased() == "hero"

        return PlayerStats(
            playerName: playerName,
            gameMode: gameMode,
            isHuman: isHuman,
            totalHands: totalHands,
            vpip: vpip,
            pfr: pfr,
            af: af,
            wtsd: wtsd,
            wsd: wsd,
            threeBet: threeBet,
            handsWon: handsWon,
            totalWinnings: totalWinnings
        )
    }
    
    private func createOrUpdateStatsEntity(stats: PlayerStats) {
        let defaultProfileId = ProfileManager.defaultProfileId
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
        fetchRequest.predicate = NSPredicate(
            format: "playerName == %@ AND gameMode == %@ AND (profileId == %@ OR profileId == nil)",
            stats.playerName,
            stats.gameMode.rawValue,
            defaultProfileId
        )
        
        let entity: NSManagedObject
        if let existing = try? context.fetch(fetchRequest).first {
            entity = existing
        } else {
            entity = NSEntityDescription.insertNewObject(forEntityName: "PlayerStatsEntity", into: context)
            entity.setValue(stats.playerName, forKey: "playerName")
            entity.setValue(stats.gameMode.rawValue, forKey: "gameMode")
            entity.setValue(defaultProfileId, forKey: "profileId")
        }
        
        entity.setValue(Int32(stats.totalHands), forKey: "totalHands")
        entity.setValue(stats.vpip, forKey: "vpip")
        entity.setValue(stats.pfr, forKey: "pfr")
        entity.setValue(stats.af, forKey: "af")
        entity.setValue(stats.wtsd, forKey: "wtsd")
        entity.setValue(stats.wsd, forKey: "wsd")
        entity.setValue(stats.threeBet, forKey: "threeBet")
        entity.setValue(Int32(stats.handsWon), forKey: "handsWon")
        entity.setValue(Int32(stats.totalWinnings), forKey: "totalWinnings")
        entity.setValue(Date(), forKey: "lastUpdated")
        
        try? context.save()
    }
    
    // MARK: - Game History Migration
    
    private func migrateGameHistoryToHandHistory() {
        // Load game history from UserDefaults
        let historyManager = GameHistoryManager.shared
        let records = historyManager.records
        
        guard !records.isEmpty else {
            print("ℹ️ No game history found to migrate")
            return
        }
        
        var migratedHands = 0
        
        for record in records {
            // Create a simplified HandHistoryEntity for each game
            // Note: This is a basic migration since GameRecord doesn't have detailed hand data
            let entity = NSEntityDescription.insertNewObject(forEntityName: "HandHistoryEntity", into: context)
            
            entity.setValue(UUID(), forKey: "id")
            entity.setValue(record.date, forKey: "date")
            entity.setValue(GameMode.cashGame.rawValue, forKey: "gameMode") // Default to cash game
            entity.setValue(Int32(record.totalHands), forKey: "handNumber")
            entity.setValue(ProfileManager.defaultProfileId, forKey: "profileId")
            
            // Set winner from results
            if let winner = record.results.first(where: { $0.rank == 1 }) {
                entity.setValue(winner.name, forKey: "winnerNames")
                entity.setValue(Int32(winner.finalChips), forKey: "finalPot")
            }
            
            // Note: We can't populate ActionEntity from GameRecord since it lacks action details
            // This is a minimal migration to preserve game history metadata
            
            migratedHands += 1
        }
        
        if migratedHands > 0 {
            try? context.save()
            print("📝 Migrated \(migratedHands) game records to hand history")
        }
    }

    // MARK: - Backfill new fields

    private func backfillDefaultProfileIdIfMissing() {
        let pid = ProfileManager.defaultProfileId

        do {
            let req = NSFetchRequest<NSManagedObject>(entityName: "HandHistoryEntity")
            req.predicate = NSPredicate(format: "profileId == nil")
            let rows = try context.fetch(req)
            for r in rows {
                r.setValue(pid, forKey: "profileId")
            }
        } catch {
            #if DEBUG
            print("Failed to backfill HandHistoryEntity.profileId: \(error)")
            #endif
        }

        // ActionEntity.profileId (best-effort: inherit from handHistory, else default)
        do {
            let req = NSFetchRequest<NSManagedObject>(entityName: "ActionEntity")
            req.predicate = NSPredicate(format: "profileId == nil")
            let rows = try context.fetch(req)
            for r in rows {
                if let hand = r.value(forKey: "handHistory") as? NSManagedObject,
                   let handPid = hand.value(forKey: "profileId") as? String,
                   !handPid.isEmpty {
                    r.setValue(handPid, forKey: "profileId")
                } else {
                    r.setValue(pid, forKey: "profileId")
                }
            }
        } catch {
            #if DEBUG
            print("Failed to backfill ActionEntity.profileId: \(error)")
            #endif
        }

        do {
            let req = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
            req.predicate = NSPredicate(format: "profileId == nil")
            let rows = try context.fetch(req)
            for r in rows {
                r.setValue(pid, forKey: "profileId")
            }
        } catch {
            #if DEBUG
            print("Failed to backfill PlayerStatsEntity.profileId: \(error)")
            #endif
        }

        try? context.save()
    }
    
    // MARK: - Manual Migration Trigger
    
    /// Force re-run migration (useful for testing or data recovery)
    func forceMigration() {
        UserDefaults.standard.set(false, forKey: migrationKey)
        migrateIfNeeded()
    }
}
