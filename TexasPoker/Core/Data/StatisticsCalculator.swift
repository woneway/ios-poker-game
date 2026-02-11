import Foundation
import CoreData

/// Player statistics snapshot
struct PlayerStats {
    let playerName: String
    let gameMode: GameMode
    let totalHands: Int
    let vpip: Double        // Voluntarily Put $ In Pot %
    let pfr: Double         // Pre-Flop Raise %
    let af: Double          // Aggression Factor
    let wtsd: Double        // Went To ShowDown %
    let wsd: Double         // Won $ at ShowDown %
    let threeBet: Double    // 3-Bet %
    let handsWon: Int
    let totalWinnings: Int
}

class StatisticsCalculator {
    static let shared = StatisticsCalculator()
    
    private var context: NSManagedObjectContext {
        PersistenceController.shared.container.viewContext
    }
    
    private init() {}
    
    // MARK: - Main API
    
    /// Calculate all statistics for a player
    func calculateStats(playerName: String, gameMode: GameMode) -> PlayerStats? {
        let totalHands = countTotalHands(playerName: playerName, gameMode: gameMode)
        guard totalHands > 0 else { return nil }
        
        let vpip = calculateVPIP(playerName: playerName, gameMode: gameMode)
        let pfr = calculatePFR(playerName: playerName, gameMode: gameMode)
        let af = calculateAF(playerName: playerName, gameMode: gameMode)
        let wtsd = calculateWTSD(playerName: playerName, gameMode: gameMode)
        let wsd = calculateWSD(playerName: playerName, gameMode: gameMode)
        let threeBet = calculate3Bet(playerName: playerName, gameMode: gameMode)
        let (handsWon, totalWinnings) = calculateWinnings(playerName: playerName, gameMode: gameMode)
        
        return PlayerStats(
            playerName: playerName,
            gameMode: gameMode,
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
    
    /// Update or create PlayerStatsEntity in Core Data
    func updatePlayerStatsEntity(stats: PlayerStats) {
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
        
        try? context.save()
    }
    
    // MARK: - Individual Calculations
    
    private func calculateVPIP(playerName: String, gameMode: GameMode) -> Double {
        let totalHands = countTotalHands(playerName: playerName, gameMode: gameMode)
        guard totalHands > 0 else { return 0.0 }
        
        // Count hands where player voluntarily put money in preflop
        let request = NSFetchRequest<NSManagedObject>(entityName: "ActionEntity")
        request.predicate = NSPredicate(
            format: "playerName == %@ AND street == %@ AND isVoluntary == YES AND handHistory.gameMode == %@",
            playerName,
            "preFlop",
            gameMode.rawValue
        )
        
        let voluntaryActions = (try? context.fetch(request).count) ?? 0
        return Double(voluntaryActions) / Double(totalHands) * 100.0
    }
    
    private func calculatePFR(playerName: String, gameMode: GameMode) -> Double {
        let totalHands = countTotalHands(playerName: playerName, gameMode: gameMode)
        guard totalHands > 0 else { return 0.0 }
        
        // Count preflop raises (raise or allIn actions)
        let request = NSFetchRequest<NSManagedObject>(entityName: "ActionEntity")
        request.predicate = NSPredicate(
            format: "playerName == %@ AND street == %@ AND (action == %@ OR action == %@) AND handHistory.gameMode == %@",
            playerName,
            "preFlop",
            "raise",
            "allIn",
            gameMode.rawValue
        )
        
        let raises = (try? context.fetch(request).count) ?? 0
        return Double(raises) / Double(totalHands) * 100.0
    }
    
    private func calculateAF(playerName: String, gameMode: GameMode) -> Double {
        // Aggression Factor = (Bets + Raises) / Calls
        let betsRequest = NSFetchRequest<NSManagedObject>(entityName: "ActionEntity")
        betsRequest.predicate = NSPredicate(
            format: "playerName == %@ AND (action == %@ OR action == %@) AND handHistory.gameMode == %@",
            playerName,
            "raise",
            "allIn",
            gameMode.rawValue
        )
        let bets = (try? context.fetch(betsRequest).count) ?? 0
        
        let callsRequest = NSFetchRequest<NSManagedObject>(entityName: "ActionEntity")
        callsRequest.predicate = NSPredicate(
            format: "playerName == %@ AND action == %@ AND handHistory.gameMode == %@",
            playerName,
            "call",
            gameMode.rawValue
        )
        let calls = (try? context.fetch(callsRequest).count) ?? 0
        
        guard calls > 0 else { return Double(bets) }
        return Double(bets) / Double(calls)
    }
    
    private func calculateWTSD(playerName: String, gameMode: GameMode) -> Double {
        // WTSD = (hands that went to showdown) / (hands that saw flop)
        let sawFlopHands = countHandsWhereSawStreet(playerName: playerName, gameMode: gameMode, street: "flop")
        guard sawFlopHands > 0 else { return 0.0 }
        
        let sawShowdownHands = countHandsWithWinner(playerName: playerName, gameMode: gameMode)
        return Double(sawShowdownHands) / Double(sawFlopHands) * 100.0
    }
    
    private func calculateWSD(playerName: String, gameMode: GameMode) -> Double {
        // W$SD = (hands won at showdown) / (hands that went to showdown)
        let sawShowdownHands = countHandsWithWinner(playerName: playerName, gameMode: gameMode)
        guard sawShowdownHands > 0 else { return 0.0 }
        
        let wonHands = countHandsWhereWon(playerName: playerName, gameMode: gameMode)
        return Double(wonHands) / Double(sawShowdownHands) * 100.0
    }
    
    private func calculate3Bet(playerName: String, gameMode: GameMode) -> Double {
        // 3-Bet % = (3-bet count) / (opportunities to 3-bet)
        // Simplified: count preflop raises after someone else raised
        // This is complex to implement accurately, return 0.0 for now (TODO)
        return 0.0
    }
    
    private func calculateWinnings(playerName: String, gameMode: GameMode) -> (handsWon: Int, totalWinnings: Int) {
        let wonHands = countHandsWhereWon(playerName: playerName, gameMode: gameMode)
        
        // Get total winnings from won hands
        let request = NSFetchRequest<NSManagedObject>(entityName: "HandHistoryEntity")
        request.predicate = NSPredicate(
            format: "winnerNames CONTAINS %@ AND gameMode == %@",
            playerName,
            gameMode.rawValue
        )
        
        let hands = (try? context.fetch(request)) ?? []
        let totalWinnings = hands.reduce(0) { sum, hand in
            sum + Int(hand.value(forKey: "finalPot") as? Int32 ?? 0)
        }
        
        return (wonHands, totalWinnings)
    }
    
    // MARK: - Helper Queries
    
    private func countTotalHands(playerName: String, gameMode: GameMode) -> Int {
        // Count distinct hands where player had any action
        let request = NSFetchRequest<NSManagedObject>(entityName: "ActionEntity")
        request.predicate = NSPredicate(
            format: "playerName == %@ AND handHistory.gameMode == %@",
            playerName,
            gameMode.rawValue
        )
        request.propertiesToFetch = ["handHistory"]
        request.returnsDistinctResults = true
        request.resultType = .dictionaryResultType
        
        let results = (try? context.fetch(request)) ?? []
        return results.count
    }
    
    private func countHandsWhereSawStreet(playerName: String, gameMode: GameMode, street: String) -> Int {
        // Count hands where player had action on or after the specified street
        let request = NSFetchRequest<NSManagedObject>(entityName: "ActionEntity")
        request.predicate = NSPredicate(
            format: "playerName == %@ AND (street == %@ OR street == %@ OR street == %@) AND handHistory.gameMode == %@",
            playerName,
            street,
            "turn",
            "river",
            gameMode.rawValue
        )
        request.propertiesToFetch = ["handHistory"]
        request.returnsDistinctResults = true
        request.resultType = .dictionaryResultType
        
        let results = (try? context.fetch(request)) ?? []
        return results.count
    }
    
    private func countHandsWithWinner(playerName: String, gameMode: GameMode) -> Int {
        // Count hands that had winners (reached showdown)
        let request = NSFetchRequest<NSManagedObject>(entityName: "HandHistoryEntity")
        request.predicate = NSPredicate(
            format: "winnerNames != nil AND winnerNames != %@ AND gameMode == %@ AND SUBQUERY(actions, $action, $action.playerName == %@).@count > 0",
            "",
            gameMode.rawValue,
            playerName
        )
        
        return (try? context.fetch(request).count) ?? 0
    }
    
    private func countHandsWhereWon(playerName: String, gameMode: GameMode) -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: "HandHistoryEntity")
        request.predicate = NSPredicate(
            format: "winnerNames CONTAINS %@ AND gameMode == %@",
            playerName,
            gameMode.rawValue
        )
        
        return (try? context.fetch(request).count) ?? 0
    }
}
