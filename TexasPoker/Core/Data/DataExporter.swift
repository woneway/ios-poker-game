import Foundation
import CoreData

class DataExporter {
    
    /// Export player statistics as JSON
    static func exportStatistics(gameMode: GameMode) -> URL? {
        let context = PersistenceController.shared.container.viewContext
        let profileId = ProfileManager.shared.currentProfileIdForData
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
        if profileId == ProfileManager.defaultProfileId {
            request.predicate = NSPredicate(format: "gameMode == %@ AND (profileId == %@ OR profileId == nil)", gameMode.rawValue, profileId)
        } else {
            request.predicate = NSPredicate(format: "gameMode == %@ AND profileId == %@", gameMode.rawValue, profileId)
        }
        request.sortDescriptors = [NSSortDescriptor(key: "totalHands", ascending: false)]
        
        guard let statsEntities = try? context.fetch(request) else { return nil }
        
        // Convert to dictionary format
        var statsArray: [[String: Any]] = []
        for entity in statsEntities {
            let dict: [String: Any] = [
                "profileId": entity.value(forKey: "profileId") as? String ?? ProfileManager.defaultProfileId,
                "playerName": entity.value(forKey: "playerName") as? String ?? "",
                "gameMode": entity.value(forKey: "gameMode") as? String ?? "",
                "totalHands": entity.value(forKey: "totalHands") as? Int32 ?? 0,
                "vpip": entity.value(forKey: "vpip") as? Double ?? 0.0,
                "pfr": entity.value(forKey: "pfr") as? Double ?? 0.0,
                "af": entity.value(forKey: "af") as? Double ?? 0.0,
                "wtsd": entity.value(forKey: "wtsd") as? Double ?? 0.0,
                "wsd": entity.value(forKey: "wsd") as? Double ?? 0.0,
                "threeBet": entity.value(forKey: "threeBet") as? Double ?? 0.0,
                "handsWon": entity.value(forKey: "handsWon") as? Int32 ?? 0,
                "totalWinnings": entity.value(forKey: "totalWinnings") as? Int32 ?? 0,
                "lastUpdated": (entity.value(forKey: "lastUpdated") as? Date)?.ISO8601Format() ?? ""
            ]
            statsArray.append(dict)
        }
        
        // Convert to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: statsArray, options: .prettyPrinted) else {
            return nil
        }
        
        // Write to temp file
        let fileName = "poker_stats_\(profileId)_\(gameMode.rawValue)_\(Date().ISO8601Format()).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonData.write(to: tempURL)
            return tempURL
        } catch {
            #if DEBUG
            print("Failed to write JSON: \(error)")
            #endif
            return nil
        }
    }
    
    /// Export hand history as JSON
    static func exportHandHistory(limit: Int = 100, gameMode: GameMode) -> URL? {
        let context = PersistenceController.shared.container.viewContext
        let profileId = ProfileManager.shared.currentProfileIdForData
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "HandHistoryEntity")
        if profileId == ProfileManager.defaultProfileId {
            request.predicate = NSPredicate(format: "gameMode == %@ AND (profileId == %@ OR profileId == nil)", gameMode.rawValue, profileId)
        } else {
            request.predicate = NSPredicate(format: "gameMode == %@ AND profileId == %@", gameMode.rawValue, profileId)
        }
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = limit
        
        guard let hands = try? context.fetch(request) else { return nil }
        
        var handsArray: [[String: Any]] = []
        for hand in hands {
            let dict: [String: Any] = [
                "profileId": hand.value(forKey: "profileId") as? String ?? ProfileManager.defaultProfileId,
                "handNumber": hand.value(forKey: "handNumber") as? Int32 ?? 0,
                "date": (hand.value(forKey: "date") as? Date)?.ISO8601Format() ?? "",
                "finalPot": hand.value(forKey: "finalPot") as? Int32 ?? 0,
                "communityCards": hand.value(forKey: "communityCards") as? String ?? "[]",
                "heroCards": hand.value(forKey: "heroCards") as? String ?? "[]",
                "winners": hand.value(forKey: "winnerNames") as? String ?? ""
            ]
            handsArray.append(dict)
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: handsArray, options: .prettyPrinted) else {
            return nil
        }
        
        let fileName = "poker_history_\(profileId)_\(gameMode.rawValue)_\(Date().ISO8601Format()).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try? jsonData.write(to: tempURL)
        return tempURL
    }
}
