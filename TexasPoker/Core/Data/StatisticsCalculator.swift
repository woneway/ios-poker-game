import Foundation
import CoreData

// MARK: - PlayerStats Struct

struct PlayerStats {
    let playerName: String
    let gameMode: GameMode
    let isHuman: Bool  // 标记是人类还是 AI
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
    
    /// Overridable context for testing. Falls back to shared persistence controller.
    var contextProvider: (() -> NSManagedObjectContext)?

    /// Overridable profile id for testing.
    var profileIdProvider: (() -> String)?
    
    private var context: NSManagedObjectContext {
        contextProvider?() ?? PersistenceController.shared.container.viewContext
    }
    
    private init() {}

    // MARK: - Public: Persisted Stats Lifecycle

    /// Recompute and persist stats for the given players.
    /// - Important: This will **delete** any existing `PlayerStatsEntity` for a player+mode
    ///   when there is no backing hand/action data (i.e. `calculateStats(...) == nil`).
    ///   This ensures a "fresh download" shows empty stats until real gameplay occurs.
    func recomputeAndPersistStats(playerNames: [String], gameMode: GameMode, profileId: String? = nil) {
        let uniqueNames = Array(Set(playerNames))
        let pid = normalizeProfileId(profileId ?? profileIdProvider?() ?? ProfileManager.shared.currentProfileIdForData)
        for name in uniqueNames {
            if let stats = calculateStats(playerName: name, gameMode: gameMode, profileId: pid) {
                updatePlayerStatsEntity(stats: stats, profileId: pid)
            } else {
                deletePlayerStatsEntity(playerName: name, gameMode: gameMode, profileId: pid)
            }
        }
    }
    
    /// Calculate statistics for a specific player and game mode
    /// Returns nil if player has no data
    /// - Parameter isHumanOverride: Optional override to determine if player is human. Defaults to checking action records.
    func calculateStats(playerName: String, gameMode: GameMode, profileId: String? = nil, isHumanOverride: Bool? = nil) -> PlayerStats? {
        let pid = normalizeProfileId(profileId ?? profileIdProvider?() ?? ProfileManager.shared.currentProfileIdForData)
        // Fetch all hands for this game mode
        let hands = fetchHands(gameMode: gameMode, profileId: pid)
        guard !hands.isEmpty else { return nil }
        
        // Fetch all actions for this player across those hands
        let actions = fetchActions(playerName: playerName, gameMode: gameMode, profileId: pid)
        
        // Find hands where this player participated (has at least one action)
        let handIDs = Set(actions.compactMap { ($0.value(forKey: "handHistory") as? NSManagedObject)?.value(forKey: "id") as? UUID })
        let playerHands = hands.filter { hand in
            guard let handID = hand.value(forKey: "id") as? UUID else { return false }
            return handIDs.contains(handID)
        }
        
        let totalHands = playerHands.count
        guard totalHands > 0 else { return nil }
        
        let vpip = calculateVPIP(actions: actions, totalHands: totalHands)
        let pfr = calculatePFR(actions: actions, totalHands: totalHands)
        let af = calculateAF(actions: actions)
        let wtsd = calculateWTSD(actions: actions, playerName: playerName, playerHands: playerHands)
        let wsd = calculateWSD(actions: actions, playerName: playerName, playerHands: playerHands)
        let threeBet = 0.0 // Requires tracking raise sequences (future enhancement)
        let handsWon = countHandsWon(playerName: playerName, playerHands: playerHands)
        let totalWinnings = calculateWinnings(playerName: playerName, playerHands: playerHands)
        
        // Determine if player is human (from override or check actions)
        let isHuman: Bool
        if let override = isHumanOverride {
            isHuman = override
        } else {
            // Check if any action for this player was marked as human
            isHuman = actions.contains { ($0.value(forKey: "isHuman") as? Bool) == true }
        }
        
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
    
    // MARK: - Core Data Queries
    
    private func fetchHands(gameMode: GameMode, profileId: String) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "HandHistoryEntity")
        request.predicate = predicateForHands(gameMode: gameMode, profileId: profileId)
        return (try? context.fetch(request)) ?? []
    }
    
    private func fetchActions(playerName: String, gameMode: GameMode, profileId: String) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ActionEntity")
        request.predicate = predicateForActions(playerName: playerName, gameMode: gameMode, profileId: profileId)
        return (try? context.fetch(request)) ?? []
    }
    
    // MARK: - VPIP: Voluntarily Put $ In Pot
    // Percentage of hands where player voluntarily put money in preflop (call/raise, not blinds)
    
    private func calculateVPIP(actions: [NSManagedObject], totalHands: Int) -> Double {
        guard totalHands > 0 else { return 0.0 }
        
        // Group actions by hand
        let preflopVoluntary = actions.filter { action in
            let street = action.value(forKey: "street") as? String ?? ""
            let isVoluntary = action.value(forKey: "isVoluntary") as? Bool ?? false
            let actionStr = action.value(forKey: "action") as? String ?? ""
            return street == Street.preFlop.rawValue
                && isVoluntary
                && actionStr != "Fold"
                && actionStr != "Check"
        }
        
        // Count unique hands with voluntary preflop action
        let voluntaryHandIDs = Set(preflopVoluntary.compactMap {
            ($0.value(forKey: "handHistory") as? NSManagedObject)?.value(forKey: "id") as? UUID
        })
        
        return Double(voluntaryHandIDs.count) / Double(totalHands) * 100.0
    }
    
    // MARK: - PFR: Pre-Flop Raise
    // Percentage of hands where player raised/allIn preflop
    
    private func calculatePFR(actions: [NSManagedObject], totalHands: Int) -> Double {
        guard totalHands > 0 else { return 0.0 }
        
        let preflopRaises = actions.filter { action in
            let street = action.value(forKey: "street") as? String ?? ""
            let actionStr = action.value(forKey: "action") as? String ?? ""
            return street == Street.preFlop.rawValue
                && (actionStr.hasPrefix("Raise") || actionStr == "All In")
        }
        
        let raiseHandIDs = Set(preflopRaises.compactMap {
            ($0.value(forKey: "handHistory") as? NSManagedObject)?.value(forKey: "id") as? UUID
        })
        
        return Double(raiseHandIDs.count) / Double(totalHands) * 100.0
    }
    
    // MARK: - AF: Aggression Factor
    // (Raise + Bet count) / Call count
    
    private func calculateAF(actions: [NSManagedObject]) -> Double {
        var aggressiveCount = 0
        var callCount = 0
        
        for action in actions {
            let actionStr = action.value(forKey: "action") as? String ?? ""
            if actionStr.hasPrefix("Raise") || actionStr == "All In" {
                aggressiveCount += 1
            } else if actionStr == "Call" {
                callCount += 1
            }
        }
        
        guard callCount > 0 else {
            // If no calls, AF = aggressive count (or 0 if also no aggression)
            return Double(aggressiveCount)
        }
        
        return Double(aggressiveCount) / Double(callCount)
    }
    
    // MARK: - WTSD: Went To Showdown
    // Percentage of hands (that saw flop) where player went to showdown (had action on river)
    
    private func calculateWTSD(actions: [NSManagedObject], playerName: String, playerHands: [NSManagedObject]) -> Double {
        // Hands where player saw the flop (had action on flop or later)
        let handsSawFlop = Set(actions.filter { action in
            let street = action.value(forKey: "street") as? String ?? ""
            return street == Street.flop.rawValue
                || street == Street.turn.rawValue
                || street == Street.river.rawValue
        }.compactMap {
            ($0.value(forKey: "handHistory") as? NSManagedObject)?.value(forKey: "id") as? UUID
        })
        
        guard !handsSawFlop.isEmpty else { return 0.0 }
        
        // Hands where player had action on river (went to showdown)
        let handsAtShowdown = Set(actions.filter { action in
            let street = action.value(forKey: "street") as? String ?? ""
            let actionStr = action.value(forKey: "action") as? String ?? ""
            return street == Street.river.rawValue && actionStr != "Fold"
        }.compactMap {
            ($0.value(forKey: "handHistory") as? NSManagedObject)?.value(forKey: "id") as? UUID
        })
        
        return Double(handsAtShowdown.count) / Double(handsSawFlop.count) * 100.0
    }
    
    // MARK: - W$SD: Won $ at Showdown
    // Percentage of showdowns where player won
    
    private func calculateWSD(actions: [NSManagedObject], playerName: String, playerHands: [NSManagedObject]) -> Double {
        // Hands where player reached river (showdown)
        let showdownHandIDs = Set(actions.filter { action in
            let street = action.value(forKey: "street") as? String ?? ""
            let actionStr = action.value(forKey: "action") as? String ?? ""
            return street == Street.river.rawValue && actionStr != "Fold"
        }.compactMap {
            ($0.value(forKey: "handHistory") as? NSManagedObject)?.value(forKey: "id") as? UUID
        })
        
        guard !showdownHandIDs.isEmpty else { return 0.0 }
        
        // How many of those did the player win?
        let showdownWins = playerHands.filter { hand in
            guard let handID = hand.value(forKey: "id") as? UUID,
                  showdownHandIDs.contains(handID),
                  let winners = hand.value(forKey: "winnerNames") as? String else { return false }
            return winners.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .contains(playerName)
        }.count
        
        return Double(showdownWins) / Double(showdownHandIDs.count) * 100.0
    }
    
    // MARK: - Hands Won & Winnings
    
    private func countHandsWon(playerName: String, playerHands: [NSManagedObject]) -> Int {
        return playerHands.filter { hand in
            guard let winners = hand.value(forKey: "winnerNames") as? String else { return false }
            return winners.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .contains(playerName)
        }.count
    }
    
    private func calculateWinnings(playerName: String, playerHands: [NSManagedObject]) -> Int {
        return playerHands.reduce(0) { total, hand in
            guard let winners = hand.value(forKey: "winnerNames") as? String else { return total }
            let winnerList = winners.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if winnerList.contains(playerName) {
                let pot = hand.value(forKey: "finalPot") as? Int32 ?? 0
                return total + Int(pot)
            }
            return total
        }
    }
    
    // MARK: - Core Data Persistence
    
    /// Update or create PlayerStatsEntity in Core Data
    func updatePlayerStatsEntity(stats: PlayerStats, profileId: String? = nil) {
        let pid = normalizeProfileId(profileId ?? profileIdProvider?() ?? ProfileManager.shared.currentProfileIdForData)
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
        fetchRequest.predicate = predicateForStats(playerName: stats.playerName, gameMode: stats.gameMode, profileId: pid)
        
        let entity: NSManagedObject
        if let existing = try? context.fetch(fetchRequest).first {
            entity = existing
        } else {
            entity = NSEntityDescription.insertNewObject(forEntityName: "PlayerStatsEntity", into: context)
            entity.setValue(UUID(), forKey: "id")
            entity.setValue(stats.playerName, forKey: "playerName")
            entity.setValue(stats.gameMode.rawValue, forKey: "gameMode")
            entity.setValue(pid, forKey: "profileId")
        }

        // Ensure we don't accidentally mix profiles on updates
        if (entity.value(forKey: "profileId") as? String)?.isEmpty ?? true {
            entity.setValue(pid, forKey: "profileId")
        }
        
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
        entity.setValue(Date(), forKey: "lastUpdated")
        
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Failed to save player stats: \(error)")
            #endif
        }
    }

    /// Delete PlayerStatsEntity for player+mode (if it exists).
    private func deletePlayerStatsEntity(playerName: String, gameMode: GameMode, profileId: String) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
        fetchRequest.predicate = predicateForStats(playerName: playerName, gameMode: gameMode, profileId: profileId)

        guard let existing = try? context.fetch(fetchRequest) else { return }
        guard !existing.isEmpty else { return }

        for obj in existing {
            context.delete(obj)
        }

        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Failed to delete player stats: \(error)")
            #endif
        }
    }

    // MARK: - Predicates / Profile normalization

    private func normalizeProfileId(_ profileId: String) -> String {
        profileId.isEmpty ? ProfileManager.defaultProfileId : profileId
    }

    private func predicateForHands(gameMode: GameMode, profileId: String) -> NSPredicate {
        if profileId == ProfileManager.defaultProfileId {
            // Backward compatible: treat nil as default
            return NSPredicate(format: "gameMode == %@ AND (profileId == %@ OR profileId == nil)", gameMode.rawValue, profileId)
        }
        return NSPredicate(format: "gameMode == %@ AND profileId == %@", gameMode.rawValue, profileId)
    }

    private func predicateForActions(playerName: String, gameMode: GameMode, profileId: String) -> NSPredicate {
        if profileId == ProfileManager.defaultProfileId {
            return NSPredicate(
                format: "playerName == %@ AND handHistory.gameMode == %@ AND (handHistory.profileId == %@ OR handHistory.profileId == nil)",
                playerName,
                gameMode.rawValue,
                profileId
            )
        }
        return NSPredicate(
            format: "playerName == %@ AND handHistory.gameMode == %@ AND handHistory.profileId == %@",
            playerName,
            gameMode.rawValue,
            profileId
        )
    }

    private func predicateForStats(playerName: String, gameMode: GameMode, profileId: String) -> NSPredicate {
        if profileId == ProfileManager.defaultProfileId {
            return NSPredicate(
                format: "playerName == %@ AND gameMode == %@ AND (profileId == %@ OR profileId == nil)",
                playerName,
                gameMode.rawValue,
                profileId
            )
        }
        return NSPredicate(
            format: "playerName == %@ AND gameMode == %@ AND profileId == %@",
            playerName,
            gameMode.rawValue,
            profileId
        )
    }
}
