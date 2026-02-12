import Foundation

// MARK: - Sound, Action Log, Statistics, Notifications
extension PokerEngine {
    
    func playSoundForAction(_ action: PlayerAction) {
        switch action {
        case .fold:  SoundManager.shared.playSound(.fold)
        case .check: SoundManager.shared.playSound(.check)
        case .call:  SoundManager.shared.playSound(.call)
        case .raise: SoundManager.shared.playSound(.raise)
        case .allIn: SoundManager.shared.playSound(.allIn)
        }
    }
    
    func recordActionLog(action: PlayerAction, player: Player) {
        let logAmount: Int? = {
            switch action {
            case .call:          return player.currentBet
            case .raise(let to): return to
            case .allIn:         return player.currentBet
            default:             return nil
            }
        }()
        let avatar = player.aiProfile?.avatar ?? (player.isHuman ? "🤠" : "🤖")
        let entry = ActionLogEntry(
            playerName: player.name,
            avatar: avatar,
            action: action,
            amount: logAmount,
            street: currentStreet
        )
        actionLog.append(entry)
        if actionLog.count > maxLogEntries {
            actionLog.removeFirst(actionLog.count - maxLogEntries)
        }
    }
    
    func recordActionStats(action: PlayerAction, originalPlayer: Player, updatedPlayer: Player, potAddition: Int) {
        let isVoluntary = determineIfVoluntary(action: action, player: originalPlayer)
        let position = getPosition(playerIndex: activePlayerIndex)
        ActionRecorder.shared.recordAction(
            playerName: updatedPlayer.name,
            action: action,
            amount: potAddition,
            street: currentStreet,
            isVoluntary: isVoluntary,
            position: position
        )
    }
    
    func recordHandEnd() {
        let heroCards = players.first { $0.isHuman }?.holeCards ?? []
        let winnerNames = winners.compactMap { id in
            players.first { $0.id == id }?.name
        }
        ActionRecorder.shared.endHand(
            finalPot: lastPotSize,
            communityCards: communityCards,
            heroCards: heroCards,
            winners: winnerNames
        )

        // Recompute persisted statistics for all table players.
        // This keeps "download/new install" stats empty, and updates dynamically as the user plays.
        StatisticsCalculator.shared.recomputeAndPersistStats(
            playerNames: players.map { $0.name },
            gameMode: gameMode,
            profileId: ProfileManager.shared.currentProfileIdForData
        )
    }
    
    func notifyWinnerAnimations(result: HandResult) {
        for winnerID in result.winnerIDs {
            if let winnerIndex = players.firstIndex(where: { $0.id == winnerID }) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("PlayerWon"),
                    object: nil,
                    userInfo: ["playerID": winnerID]
                )
                let winnerAmount = result.totalPot / result.winnerIDs.count
                NotificationCenter.default.post(
                    name: NSNotification.Name("WinnerChipAnimation"),
                    object: nil,
                    userInfo: ["seatIndex": winnerIndex, "amount": winnerAmount]
                )
            }
        }
    }
    
    // MARK: - Position & Statistics Helpers
    
    func determineIfVoluntary(action: PlayerAction, player: Player) -> Bool {
        if currentStreet == .preFlop,
           players[bigBlindIndex].id == player.id,
           case .call = action,
           currentBet == bigBlindAmount {
            return false
        }
        return action != .fold && action != .check
    }
    
    func getPosition(playerIndex: Int) -> String {
        let offset = seatOffsetFromDealer(playerIndex: playerIndex)
        let activeCount = players.filter { $0.status == .active || $0.status == .allIn }.count
        
        if activeCount == 2 { return offset == 0 ? "BTN/SB" : "BB" }
        
        switch offset {
        case 0: return "BTN"
        case 1: return "SB"
        case 2: return "BB"
        case 3: return "UTG"
        case 4: return "MP"
        case 5: return activeCount <= 6 ? "CO" : "MP"
        case 6: return "CO"
        case 7: return "HJ"
        default: return "EP"
        }
    }
}
