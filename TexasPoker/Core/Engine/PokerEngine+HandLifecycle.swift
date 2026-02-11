import Foundation

// MARK: - Hand Lifecycle (startHand, endHand, runOutBoard)
extension PokerEngine {
    
    func startHand() {
        handNumber += 1
        
        // Update tilt levels before starting
        TiltManager.updateTiltLevels(players: &players, lastHandLosers: lastHandLosers, lastPotSize: lastPotSize)
        
        // Reset deck and community (reset 内置 shuffle)
        deck.reset()
        communityCards.removeAll()
        pot.reset()
        currentStreet = .preFlop
        currentBet = 0
        minRaise = bigBlindAmount
        winners = []
        winMessage = ""
        isHandOver = false
        hasActed = [:]
        lastRaiserID = nil
        preflopAggressorID = nil
        
        // Reset player states
        for i in 0..<players.count {
            players[i].holeCards.removeAll()
            players[i].currentBet = 0
            players[i].totalBetThisHand = 0
            players[i].status = players[i].chips > 0 ? .active : .eliminated
        }
        
        // Move dealer button
        dealerIndex = nextActivePlayerIndex(after: dealerIndex)
        
        // Determine blind positions
        let activePlayers = players.filter { $0.status == .active || $0.status == .allIn }
        if activePlayers.count <= 1 {
            isHandOver = true
            winMessage = "Not enough players!"
            return
        }
        
        smallBlindIndex = nextActivePlayerIndex(after: dealerIndex)
        bigBlindIndex = nextActivePlayerIndex(after: smallBlindIndex)
        
        // In heads-up (2 players), dealer posts SB
        if activePlayers.count == 2 {
            smallBlindIndex = dealerIndex
            bigBlindIndex = nextActivePlayerIndex(after: dealerIndex)
        }
        
        // Post antes (if any)
        if anteAmount > 0 {
            for i in 0..<players.count where players[i].status == .active {
                postAnte(playerIndex: i, amount: anteAmount)
            }
        }
        
        // Post blinds
        postBlind(playerIndex: smallBlindIndex, amount: smallBlindAmount)
        postBlind(playerIndex: bigBlindIndex, amount: bigBlindAmount)
        
        // Deal hole cards
        DealingManager.dealHoleCards(deck: &deck, players: &players, dealerIndex: dealerIndex)
        
        currentBet = bigBlindAmount
        minRaise = bigBlindAmount
        activePlayerIndex = nextActivePlayerIndex(after: bigBlindIndex)
        
        for player in players where player.status == .active {
            hasActed[player.id] = false
        }
        
        actionLog.removeAll()
        
        #if DEBUG
        print("=== Hand #\(handNumber): Dealer=\(players[dealerIndex].name), SB=\(players[smallBlindIndex].name), BB=\(players[bigBlindIndex].name) ===")
        #endif
        
        checkBotTurn()
        
        ActionRecorder.shared.startHand(
            handNumber: handNumber,
            gameMode: gameMode,
            players: players
        )
    }
    
    func endHand() {
        guard !isHandOver else { return }
        
        let eligible = players.filter { $0.status == .active || $0.status == .allIn }
        
        let result: HandResult
        if eligible.count == 1 {
            result = ShowdownManager.distributeSingleWinner(
                winner: eligible[0],
                potTotal: pot.total,
                players: &players
            )
        } else if eligible.count > 1 {
            pot.calculatePots(players: players)
            result = ShowdownManager.distributeWithSidePots(
                eligible: eligible,
                pot: pot,
                communityCards: communityCards,
                players: &players
            )
        } else {
            isHandOver = true
            return
        }
        
        winners = result.winnerIDs
        winMessage = result.winMessage
        lastHandLosers = result.loserIDs
        lastPotSize = result.totalPot
        isHandOver = true
        
        // Trigger winner animations
        notifyWinnerAnimations(result: result)
        
        // Record hand end for statistics
        recordHandEnd()
        
        // Record Hero win/loss for difficulty adjustment
        if let hero = players.first(where: { $0.isHuman }) {
            DecisionEngine.difficultyManager.recordHand(heroWon: winners.contains(hero.id))
        }
        
        // Check for blind level up in tournaments
        if gameMode == .tournament, let config = tournamentConfig {
            if let levelUp = TournamentManager.checkBlindLevelUp(
                config: config,
                currentLevel: currentBlindLevel,
                handsAtLevel: handsAtCurrentLevel
            ) {
                smallBlindAmount = levelUp.smallBlind
                bigBlindAmount = levelUp.bigBlind
                anteAmount = levelUp.ante
                currentBlindLevel = levelUp.newLevel
                handsAtCurrentLevel = levelUp.handsAtLevel
            } else {
                handsAtCurrentLevel += 1
            }
        }
        
        // Track newly eliminated players
        GameResultsManager.trackEliminations(
            players: players,
            handNumber: handNumber,
            eliminationOrder: &eliminationOrder
        )
        
        #if DEBUG
        print("=== Hand #\(handNumber) Over: \(winMessage) ===\n")
        #endif
    }
    
    /// 所有人 All-in 时，快速依次发完剩余公共牌然后结算
    func runOutBoard() {
        let streetsToGo = DealingManager.streetsRemaining(from: currentStreet)
        
        guard streetsToGo > 0 else {
            endHand()
            return
        }
        
        for i in 0..<streetsToGo {
            let delay = Double(i + 1) * 0.8
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, !self.isHandOver else { return }
                DealingManager.dealStreetCards(deck: &self.deck, communityCards: &self.communityCards, currentStreet: &self.currentStreet)
                if i == streetsToGo - 1 {
                    self.endHand()
                }
            }
        }
    }
}
