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
    /// - Parameters:
    ///   - players: Array of tuples containing (playerName, playerUniqueId)
    ///   - gameMode: The game mode to calculate stats for
    ///   - profileId: Optional profile ID override
    func recomputeAndPersistStats(players: [(name: String, uniqueId: String?)], gameMode: GameMode, profileId: String? = nil) {
        let pid = normalizeProfileId(profileId ?? profileIdProvider?() ?? ProfileManager.shared.currentProfileIdForData)
        for player in players {
            if let stats = calculateStats(playerName: player.name, playerUniqueId: player.uniqueId, gameMode: gameMode, profileId: pid) {
                updatePlayerStatsEntity(stats: stats, playerUniqueId: player.uniqueId, profileId: pid)
            } else {
                deletePlayerStatsEntity(playerName: player.name, playerUniqueId: player.uniqueId, gameMode: gameMode, profileId: pid)
            }
        }
    }
    
    /// Recompute and persist stats for the given player names (legacy method for backward compatibility).
    func recomputeAndPersistStats(playerNames: [String], gameMode: GameMode, profileId: String? = nil) {
        let players = playerNames.map { (name: $0, uniqueId: nil as String?) }
        recomputeAndPersistStats(players: players, gameMode: gameMode, profileId: profileId)
    }
    
    // MARK: - Batch Stats Calculation (Performance Optimization)

    /// Calculate stats for multiple players in a single query pass
    /// This is much more efficient than calling calculateStats for each player separately
    /// - Parameters:
    ///   - playerNames: Array of player names to calculate stats for
    ///   - gameMode: The game mode
    ///   - profileId: Optional profile ID override
    /// - Returns: Dictionary mapping player name to PlayerStats (nil if player has no data)
    func calculateBatchStats(
        playerNames: [String],
        gameMode: GameMode,
        profileId: String? = nil
    ) -> [String: PlayerStats?] {
        let pid = normalizeProfileId(profileId ?? profileIdProvider?() ?? ProfileManager.shared.currentProfileIdForData)

        // Fetch all hands and actions for this game mode in ONE query
        let hands = fetchHands(gameMode: gameMode, profileId: pid)

        guard !hands.isEmpty else {
            // No hands at all - return nil for all players
            var result: [String: PlayerStats?] = [:]
            for name in playerNames {
                result[name] = nil
            }
            return result
        }

        // Fetch all actions for all players in this game mode
        let allActions = fetchAllActionsForGameMode(gameMode: gameMode, profileId: pid)

        // Build result dictionary
        var result: [String: PlayerStats?] = [:]

        for playerName in playerNames {
            // Filter actions for this player
            let playerActions = allActions.filter { action in
                let uniqueId = action.value(forKey: "playerUniqueId") as? String
                let name = action.value(forKey: "playerName") as? String ?? ""
                // 前缀匹配：playerName + "#" 能匹配到 "playerName#1", "playerName#2" 等
                let uniqueIdMatches = uniqueId != nil && uniqueId!.hasPrefix(playerName + "#")
                return uniqueIdMatches || name == playerName
            }

            // Find hands where this player participated
            let handIDs = Set(playerActions.compactMap { ($0.value(forKey: "handHistory") as? NSManagedObject)?.value(forKey: "id") as? UUID })
            let playerHands = hands.filter { hand in
                guard let handID = hand.value(forKey: "id") as? UUID else { return false }
                return handIDs.contains(handID)
            }

            let totalHands = playerHands.count
            guard totalHands > 0 else {
                result[playerName] = nil
                continue
            }

            let vpip = calculateVPIP(actions: playerActions, totalHands: totalHands)
            let pfr = calculatePFR(actions: playerActions, totalHands: totalHands)
            let af = calculateAF(actions: playerActions)
            let wtsd = calculateWTSD(actions: playerActions, playerName: playerName, playerHands: playerHands)
            let wsd = calculateWSD(actions: playerActions, playerName: playerName, playerHands: playerHands)
            let threeBet = calculate3Bet(actions: playerActions, playerHands: playerHands)
            let handsWon = countHandsWon(playerName: playerName, playerHands: playerHands)
            let totalWinnings = calculateWinnings(playerName: playerName, playerHands: playerHands)

            // Determine if player is human
            let isHuman = playerActions.contains { ($0.value(forKey: "isHuman") as? Bool) == true }

            result[playerName] = PlayerStats(
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

        return result
    }

    /// Fetch all actions for a game mode (optimized batch query)
    private func fetchAllActionsForGameMode(gameMode: GameMode, profileId: String) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ActionEntity")

        var predicates: [NSPredicate] = [
            NSPredicate(format: "handHistory.gameMode == %@", gameMode.rawValue)
        ]

        if profileId == ProfileManager.defaultProfileId {
            predicates.append(NSPredicate(format: "(handHistory.profileId == %@ OR handHistory.profileId == nil)", profileId))
        } else {
            predicates.append(NSPredicate(format: "handHistory.profileId == %@", profileId))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return (try? context.fetch(request)) ?? []
    }

    /// Calculate statistics for a specific player and game mode
    /// Returns nil if player has no data
    /// - Parameters:
    ///   - playerName: The player's display name (used as fallback if playerUniqueId is not available)
    ///   - playerUniqueId: The unique identifier for the player (preferred, will fallback to playerName if nil)
    ///   - gameMode: The game mode to calculate stats for
    ///   - profileId: Optional profile ID override
    ///   - isHumanOverride: Optional override to determine if player is human. Defaults to checking action records.
    func calculateStats(playerName: String, playerUniqueId: String? = nil, gameMode: GameMode, profileId: String? = nil, isHumanOverride: Bool? = nil) -> PlayerStats? {
        let pid = normalizeProfileId(profileId ?? profileIdProvider?() ?? ProfileManager.shared.currentProfileIdForData)
        // Fetch all hands for this game mode
        let hands = fetchHands(gameMode: gameMode, profileId: pid)
        guard !hands.isEmpty else { return nil }
        
        // Fetch all actions for this player across those hands (using playerUniqueId with fallback to playerName)
        let actions = fetchActions(playerName: playerName, playerUniqueId: playerUniqueId, gameMode: gameMode, profileId: pid)
        
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
        let threeBet = calculate3Bet(actions: actions, playerHands: playerHands)
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
    
    private func fetchActions(playerName: String, playerUniqueId: String? = nil, gameMode: GameMode, profileId: String) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ActionEntity")
        request.predicate = predicateForActions(playerName: playerName, playerUniqueId: playerUniqueId, gameMode: gameMode, profileId: profileId)
        return (try? context.fetch(request)) ?? []
    }
    
    // MARK: - VPIP: Voluntarily Put $ In Pot
    // Percentage of hands where player voluntarily put money in preflop (call/raise, not blinds)
    
    private func calculateVPIP(actions: [NSManagedObject], totalHands: Int) -> Double {
        guard totalHands > 0 else { return 0.0 }
        
        // VPIP = hands where player voluntarily put money in preflop (Call, Raise, All In)
        // Use action type directly instead of isVoluntary flag to avoid inconsistency with PFR
        let preflopVoluntary = actions.filter { action in
            let street = action.value(forKey: "street") as? String ?? ""
            let actionStr = action.value(forKey: "action") as? String ?? ""
            return street == Street.preFlop.rawValue
                && (actionStr == "Call" || actionStr.hasPrefix("Raise") || actionStr == "All In")
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

    // MARK: - 3Bet Calculation

    /// Calculate 3Bet rate: percentage of times player 3-bets when facing an open raise
    /// 3Bet = 3rd preflop raise (first raise = open, second raise = 3bet, etc.)
    /// Excludes All-in as it's not a "strategic" 3bet
    private func calculate3Bet(actions: [NSManagedObject], playerHands: [NSManagedObject]) -> Double {
        // Filter to preflop actions only
        let preflopActions = actions.filter { action in
            let street = action.value(forKey: "street") as? String ?? ""
            return street == Street.preFlop.rawValue
        }

        // Group actions by hand
        var handActions: [[NSManagedObject]] = []
        var currentHandId: UUID?
        var currentHandActions: [NSManagedObject] = []

        for action in preflopActions.sorted(by: { a, b in
            let timeA = a.value(forKey: "timestamp") as? Date ?? Date.distantPast
            let timeB = b.value(forKey: "timestamp") as? Date ?? Date.distantPast
            return timeA < timeB
        }) {
            guard let handHistory = action.value(forKey: "handHistory") as? NSManagedObject,
                  let handId = handHistory.value(forKey: "id") as? UUID else {
                continue
            }

            if currentHandId != handId {
                if !currentHandActions.isEmpty {
                    handActions.append(currentHandActions)
                }
                currentHandActions = [action]
                currentHandId = handId
            } else {
                currentHandActions.append(action)
            }
        }
        if !currentHandActions.isEmpty {
            handActions.append(currentHandActions)
        }

        // For each hand, count raise sequence
        var threeBetCount = 0
        var threeBetOpportunities = 0

        for handActionList in handActions {
            let raises = handActionList.filter { action in
                let actionStr = action.value(forKey: "action") as? String ?? ""
                return actionStr.hasPrefix("Raise") || actionStr == "All In"
            }.sorted { a, b in
                let timeA = a.value(forKey: "timestamp") as? Date ?? Date.distantPast
                let timeB = b.value(forKey: "timestamp") as? Date ?? Date.distantPast
                return timeA < timeB
            }

            // Count non-All-in raises to determine position in raise sequence
            var raiseIndex = 0
            for raise in raises {
                let actionStr = raise.value(forKey: "action") as? String ?? ""
                if actionStr == "All In" {
                    // All-in doesn't count as 3bet for strategic purposes
                    continue
                }
                raiseIndex += 1
                if raiseIndex == 3 {
                    // This is a 3bet (3rd non-All-in raise)
                    threeBetCount += 1
                    break
                }
            }

            // If there were at least 2 raises, that's a 3bet opportunity
            if raises.count >= 2 {
                // Count only non-All-in raises for opportunity
                let nonAllInRaises = raises.filter { ($0.value(forKey: "action") as? String ?? "") != "All In" }
                if nonAllInRaises.count >= 2 {
                    threeBetOpportunities += 1
                }
            }
        }

        guard threeBetOpportunities > 0 else { return 0.0 }
        return Double(threeBetCount) / Double(threeBetOpportunities) * 100.0
    }

    // MARK: - Core Data Persistence
    
    /// Update or create PlayerStatsEntity in Core Data
    /// - Parameters:
    ///   - stats: The player stats to save
    ///   - playerUniqueId: Optional unique identifier for the player
    ///   - profileId: Optional profile ID override
    func updatePlayerStatsEntity(stats: PlayerStats, playerUniqueId: String? = nil, profileId: String? = nil) {
        let pid = normalizeProfileId(profileId ?? profileIdProvider?() ?? ProfileManager.shared.currentProfileIdForData)
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
        fetchRequest.predicate = predicateForStats(playerName: stats.playerName, playerUniqueId: playerUniqueId, gameMode: stats.gameMode, profileId: pid)
        
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

        // Save playerUniqueId if provided
        if let uniqueId = playerUniqueId {
            entity.setValue(uniqueId, forKey: "playerUniqueId")
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
    private func deletePlayerStatsEntity(playerName: String, playerUniqueId: String? = nil, gameMode: GameMode, profileId: String) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
        fetchRequest.predicate = predicateForStats(playerName: playerName, playerUniqueId: playerUniqueId, gameMode: gameMode, profileId: profileId)

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

    private func predicateForActions(playerName: String, playerUniqueId: String? = nil, gameMode: GameMode, profileId: String) -> NSPredicate {
        // Use playerUniqueId if available, otherwise fallback to playerName
        let playerPredicate: NSPredicate
        if let uniqueId = playerUniqueId, !uniqueId.isEmpty {
            // Priority: match playerUniqueId first, fallback to playerName if null
            playerPredicate = NSPredicate(format: "playerUniqueId == %@ OR (playerUniqueId == nil AND playerName == %@)", uniqueId, playerName)
        } else {
            playerPredicate = NSPredicate(format: "playerName == %@", playerName)
        }
        
        if profileId == ProfileManager.defaultProfileId {
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                playerPredicate,
                NSPredicate(format: "handHistory.gameMode == %@", gameMode.rawValue),
                NSPredicate(format: "(handHistory.profileId == %@ OR handHistory.profileId == nil)", profileId)
            ])
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            playerPredicate,
            NSPredicate(format: "handHistory.gameMode == %@", gameMode.rawValue),
            NSPredicate(format: "handHistory.profileId == %@", profileId)
        ])
    }

    private func predicateForStats(playerName: String, playerUniqueId: String? = nil, gameMode: GameMode, profileId: String) -> NSPredicate {
        // Use playerUniqueId if available, otherwise fallback to playerName
        let playerPredicate: NSPredicate
        if let uniqueId = playerUniqueId, !uniqueId.isEmpty {
            // Priority: match playerUniqueId first, fallback to playerName if null
            playerPredicate = NSPredicate(format: "playerUniqueId == %@ OR (playerUniqueId == nil AND playerName == %@)", uniqueId, playerName)
        } else {
            playerPredicate = NSPredicate(format: "playerName == %@", playerName)
        }
        
        if profileId == ProfileManager.defaultProfileId {
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                playerPredicate,
                NSPredicate(format: "gameMode == %@", gameMode.rawValue),
                NSPredicate(format: "(profileId == %@ OR profileId == nil)", profileId)
            ])
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            playerPredicate,
            NSPredicate(format: "gameMode == %@", gameMode.rawValue),
            NSPredicate(format: "profileId == %@", profileId)
        ])
    }

    // MARK: - Time Range Support

    enum TimeRange: String, CaseIterable {
        case session = "本局"
        case day = "今日"
        case week = "本周"
        case all = "全部"
    }

    func startDate(for timeRange: TimeRange) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        switch timeRange {
        case .session:
            // Session is current game only - return nil to indicate no filtering
            return nil
        case .day:
            return calendar.startOfDay(for: now)
        case .week:
            let weekday = calendar.component(.weekday, from: now)
            let daysToSubtract = (weekday - calendar.firstWeekday + 7) % 7
            return calendar.date(byAdding: .day, value: -daysToSubtract, to: calendar.startOfDay(for: now))
        case .all:
            return nil
        }
    }

    // MARK: - Data Structures for Enhanced Statistics

    struct HandHistorySummary {
        let id: UUID
        let handNumber: Int
        let date: Date
        let finalPot: Int
        let communityCards: [Card]
        let heroCards: [Card]
        let winnerNames: [String]
        let isWin: Bool
        let profit: Int
    }

    struct ProfitDataPoint {
        let handNumber: Int
        let cumulativeProfit: Int
    }

    struct PositionStat {
        let position: String
        let winRate: Double
        let handsPlayed: Int
    }

    // MARK: - Public Data Query Methods

    /// Fetch hand history summaries for the current profile and game mode
    func fetchHandHistorySummaries(
        gameMode: GameMode,
        timeRange: TimeRange = .all,
        profileId: String? = nil
    ) -> [HandHistorySummary] {
        let pid = normalizeProfileId(profileId ?? ProfileManager.shared.currentProfileIdForData)

        var predicates: [NSPredicate] = [
            NSPredicate(format: "gameMode == %@", gameMode.rawValue),
            predicateForProfileId(pid)
        ]

        // Add time range filter
        if let startDate = startDate(for: timeRange) {
            predicates.append(NSPredicate(format: "date >= %@", startDate as NSDate))
        }

        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        let request = NSFetchRequest<NSManagedObject>(entityName: "HandHistoryEntity")
        request.predicate = compoundPredicate
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        guard let hands = try? context.fetch(request) else { return [] }

        // Decode hero cards for the current profile's human player
        let heroName = "Hero"

        return hands.compactMap { hand -> HandHistorySummary? in
            guard let id = hand.value(forKey: "id") as? UUID,
                  let handNumber = hand.value(forKey: "handNumber") as? Int32,
                  let date = hand.value(forKey: "date") as? Date,
                  let finalPot = hand.value(forKey: "finalPot") as? Int32,
                  let winnerNamesStr = hand.value(forKey: "winnerNames") as? String else {
                return nil
            }

            let communityCards = decodeCards(hand.value(forKey: "communityCards") as? String ?? "[]")
            let heroCards = decodeCards(hand.value(forKey: "heroCards") as? String ?? "[]")
            let winnerNames = winnerNamesStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            let isWin = winnerNames.contains(heroName)
            // More accurate profit calculation: calculate based on winner count
            // If won: profit = finalPot / winnerCount (simplified, assumes equal split)
            // Note: For accurate profit, we would need to track player investments from action history
            let winnerCount = winnerNames.count
            let profit: Int
            if isWin && winnerCount > 0 {
                // Approximate: divide pot among winners (simplified)
                // In reality, should calculate from action history (total invested vs returned)
                profit = Int(finalPot) / winnerCount
            } else {
                // Loss: we don't track exact loss amount, so use 0 for now
                // TODO: Calculate actual loss from action history
                profit = 0
            }

            return HandHistorySummary(
                id: id,
                handNumber: Int(handNumber),
                date: date,
                finalPot: Int(finalPot),
                communityCards: communityCards,
                heroCards: heroCards,
                winnerNames: winnerNames,
                isWin: isWin,
                profit: profit
            )
        }
    }

    /// Calculate profit trend data points
    func calculateProfitTrend(
        gameMode: GameMode,
        timeRange: TimeRange = .all,
        profileId: String? = nil
    ) -> [ProfitDataPoint] {
        let summaries = fetchHandHistorySummaries(gameMode: gameMode, timeRange: timeRange, profileId: profileId)

        // Sort by date ascending for cumulative calculation
        let sorted = summaries.sorted { $0.date < $1.date }

        var cumulativeProfit = 0
        return sorted.map { summary in
            cumulativeProfit += summary.profit
            return ProfitDataPoint(handNumber: summary.handNumber, cumulativeProfit: cumulativeProfit)
        }
    }

    /// Calculate position-based statistics
    /// - Parameters:
    ///   - gameMode: The game mode to filter by
    ///   - timeRange: Time range to filter by
    ///   - profileId: Optional profile ID override
    ///   - playerName: The player name to calculate stats for (defaults to "Hero")
    func calculatePositionStats(
        gameMode: GameMode,
        timeRange: TimeRange = .all,
        profileId: String? = nil,
        playerName: String = "Hero"
    ) -> [PositionStat] {
        let pid = normalizeProfileId(profileId ?? ProfileManager.shared.currentProfileIdForData)

        var predicates: [NSPredicate] = [
            NSPredicate(format: "playerName == %@", playerName),
            NSPredicate(format: "handHistory.gameMode == %@", gameMode.rawValue),
            predicateForProfileId(pid)
        ]

        if let startDate = startDate(for: timeRange) {
            predicates.append(NSPredicate(format: "handHistory.date >= %@", startDate as NSDate))
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: "ActionEntity")
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        guard let actions = try? context.fetch(request) else { return [] }

        // Group actions by position and calculate win rate
        // FIX: Track unique hands per position to avoid counting same hand multiple times
        var positionHandIds: [String: Set<UUID>] = [:]
        var positionWins: [String: Set<UUID>] = [:]

        for action in actions {
            guard let position = action.value(forKey: "position") as? String,
                  let handHistory = action.value(forKey: "handHistory") as? NSManagedObject,
                  let handId = handHistory.value(forKey: "id") as? UUID else {
                continue
            }

            // Track unique hand IDs per position
            if positionHandIds[position] == nil {
                positionHandIds[position] = []
                positionWins[position] = []
            }

            // Only count each hand once per position
            if positionHandIds[position]!.insert(handId).inserted {
                // Check if this hand was won
                if let winnerNames = handHistory.value(forKey: "winnerNames") as? String,
                   winnerNames.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) }).contains(playerName) {
                    positionWins[position]!.insert(handId)
                }
            }
        }

        // Convert to PositionStat
        let positionMapping: [String: String] = [
            "BTN": "BTN",
            "CO": "CO",
            "MP": "MP",
            "EP": "EP",
            "BB": "BB",
            "SB": "SB"
        ]

        return positionHandIds.compactMap { position, handIds -> PositionStat? in
            guard let mappedPosition = positionMapping[position] else { return nil }
            let total = handIds.count
            let wins = positionWins[position]?.count ?? 0
            let winRate = total > 0 ? Double(wins) / Double(total) * 100.0 : 0.0
            return PositionStat(position: mappedPosition, winRate: winRate, handsPlayed: total)
        }
    }

    // MARK: - Delete Profile Data

    /// Delete all Core Data records for a given profile
    func deleteAllDataForProfile(profileId: String) {
        let pid = normalizeProfileId(profileId)
        guard pid != ProfileManager.defaultProfileId else { return } // Don't delete default

        let entities = ["HandHistoryEntity", "ActionEntity", "PlayerStatsEntity"]

        for entityName in entities {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = NSPredicate(format: "profileId == %@", pid)

            guard let objects = try? context.fetch(request) else { continue }

            for obj in objects {
                context.delete(obj)
            }
        }

        do {
            try context.save()
            #if DEBUG
            print("🗑️ Deleted all data for profile: \(pid)")
            #endif
        } catch {
            #if DEBUG
            print("Failed to delete profile data: \(error)")
            #endif
        }
    }

    // MARK: - Private Helpers

    private func predicateForProfileId(_ profileId: String) -> NSPredicate {
        if profileId == ProfileManager.defaultProfileId {
            return NSPredicate(format: "profileId == %@ OR profileId == nil", profileId)
        }
        return NSPredicate(format: "profileId == %@", profileId)
    }

    private func decodeCards(_ json: String) -> [Card] {
        guard let data = json.data(using: .utf8),
              let cards = try? JSONDecoder().decode([Card].self, from: data) else {
            return []
        }
        return cards
    }
}
