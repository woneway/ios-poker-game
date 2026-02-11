import Foundation
import CoreData

// MARK: - PlayerStats Struct

struct PlayerStats {
    let playerName: String
    let gameMode: GameMode
    let totalHands: Int
    let vpip: Double
    let pfr: Double
    let af: Double
    let wtsd: Double
    let wsd: Double
    let threeBet: Double
    let handsWon: Int
    let totalWinnings: Int
}

// MARK: - StatisticsCalculator

class StatisticsCalculator {
    static let shared = StatisticsCalculator()
    
    private init() {}
    
    /// Calculate statistics for a specific player and game mode
    /// Returns nil if player has no data
    func calculateStats(playerName: String, gameMode: GameMode) -> PlayerStats? {
        // TODO: Implement actual Core Data queries in Task 3
        // For now, return nil to indicate no stats available
        // This allows Task 4 (HUD) to be implemented and tested
        return nil
    }
    
    // MARK: - Individual Stat Calculations (to be implemented in Task 3)
    
    private func calculateVPIP(playerName: String, gameMode: GameMode) -> Double {
        // TODO: Implement VPIP calculation
        return 0.0
    }
    
    private func calculatePFR(playerName: String, gameMode: GameMode) -> Double {
        // TODO: Implement PFR calculation
        return 0.0
    }
    
    private func calculateAF(playerName: String, gameMode: GameMode) -> Double {
        // TODO: Implement AF calculation
        return 0.0
    }
    
    private func calculateWTSD(playerName: String, gameMode: GameMode) -> Double {
        // TODO: Implement WTSD calculation
        return 0.0
    }
    
    private func calculateWSD(playerName: String, gameMode: GameMode) -> Double {
        // TODO: Implement W$SD calculation
        return 0.0
    }
    
    // MARK: - Core Data Persistence
    
    /// Update or create PlayerStatsEntity in Core Data
    func updatePlayerStatsEntity(stats: PlayerStats) {
        let context = PersistenceController.shared.container.viewContext
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
        fetchRequest.predicate = NSPredicate(
            format: "playerName == %@ AND gameMode == %@",
            stats.playerName,
            stats.gameMode.rawValue
        )
        
        let entity: NSManagedObject
        if let existing = try? context.fetch(fetchRequest).first {
            entity = existing
        } else {
            entity = NSEntityDescription.insertNewObject(forEntityName: "PlayerStatsEntity", into: context)
            entity.setValue(UUID(), forKey: "id")
            entity.setValue(stats.playerName, forKey: "playerName")
            entity.setValue(stats.gameMode.rawValue, forKey: "gameMode")
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
        
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Failed to save player stats: \(error)")
            #endif
        }
    }
}
