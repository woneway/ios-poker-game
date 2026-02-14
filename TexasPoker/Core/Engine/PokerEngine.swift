import Foundation
import Combine

class PokerEngine: ObservableObject {
    @Published var deck: Deck
    @Published var players: [Player]
    @Published var communityCards: [Card]
    @Published var pot: Pot
    @Published var dealerIndex: Int
    @Published var activePlayerIndex: Int
    @Published var currentStreet: Street
    
    // Betting state
    @Published var currentBet: Int = 0
    @Published var minRaise: Int = 0
    
    // Winner state
    @Published var winners: [UUID] = []
    @Published var winMessage: String = ""
    @Published var isHandOver: Bool = false
    
    // Hand counter
    @Published var handNumber: Int = 0
    
    // Action log
    @Published var actionLog: [ActionLogEntry] = []
    let maxLogEntries = 30
    
    // Internal tracking (accessible to extensions)
    var hasActed: [UUID: Bool] = [:]
    var lastRaiserID: UUID? = nil
    var bigBlindIndex: Int = 0
    var smallBlindIndex: Int = 0
    
    /// Tracks who was the preflop aggressor (raiser) for c-bet logic
    @Published var preflopAggressorID: UUID? = nil
    
    // Previous hand results (for tilt system)
    var lastHandLosers: Set<UUID> = []
    var lastPotSize: Int = 0
    
    // Elimination tracking (for final rankings)
    @Published var eliminationOrder: [(name: String, avatar: String, hand: Int, isHuman: Bool)] = []
    
    var smallBlindAmount: Int = 10
    var bigBlindAmount: Int = 20
    
    // Tournament support
    @Published var gameMode: GameMode = .cashGame
    @Published var tournamentConfig: TournamentConfig?
    @Published var currentBlindLevel: Int = 0
    @Published var handsAtCurrentLevel: Int = 0
    @Published var anteAmount: Int = 0
    
    init(mode: GameMode = .cashGame, config: TournamentConfig? = nil) {
        self.deck = Deck()
        self.players = []
        self.communityCards = []
        self.pot = Pot()
        self.dealerIndex = -1
        self.activePlayerIndex = 0
        self.currentStreet = .preFlop
        
        setup8PlayerTable()
        
        self.gameMode = mode
        self.tournamentConfig = config
        
        if mode == .tournament, let config = config {
            let blinds = TournamentManager.applyConfig(config, players: &players)
            self.smallBlindAmount = blinds.smallBlind
            self.bigBlindAmount = blinds.bigBlind
            self.anteAmount = blinds.ante
            self.currentBlindLevel = 0
            self.handsAtCurrentLevel = 0
        }
    }
    
    // MARK: - 8-Player Table Setup
    /// Sets up table with configurable difficulty and player count
    func setupTable(
        difficulty: AIProfile.Difficulty = .normal,
        playerCount: Int = 8,
        heroName: String = "Hero"
    ) {
        players = []
        
        // Add Hero
        players.append(Player(name: heroName, chips: 1000, isHuman: true))
        
        // Add AI opponents based on difficulty
        let aiCount = min(playerCount - 1, 7)
        let profiles = difficulty.randomOpponents(count: aiCount)
        
        for profile in profiles {
            players.append(Player(
                name: profile.name,
                chips: 1000,
                isHuman: false,
                aiProfile: profile
            ))
        }
    }
    
    /// Legacy setup for backward compatibility
    private func setup8PlayerTable() {
        setupTable(difficulty: .normal, playerCount: 8)
    }
    
    // MARK: - Position Helpers
    
    func seatOffsetFromDealer(playerIndex: Int) -> Int {
        (playerIndex - dealerIndex + players.count) % players.count
    }
    
    func isLatePosition(playerIndex: Int) -> Bool {
        let offset = seatOffsetFromDealer(playerIndex: playerIndex)
        return offset == 0 || offset >= players.count - 2
    }
    
    // MARK: - Street Dealing
    
    func dealNextStreet() {
        let nonFolded = players.filter { $0.status == .active || $0.status == .allIn }
        if nonFolded.count <= 1 {
            endHand()
            return
        }
        
        // Fix: If we are already at River and dealNextStreet is called,
        // it means the River betting round is complete. End the hand.
        if currentStreet == .river {
            endHand()
            return
        }
        
        let canBet = players.filter { $0.status == .active }
        
        DealingManager.dealStreetCards(deck: &deck, communityCards: &communityCards, currentStreet: &currentStreet)
        
        if currentStreet == .river {
            resetBettingState()
            if canBet.count >= 2 {
                activePlayerIndex = nextActivePlayerIndex(after: dealerIndex)
                checkBotTurn()
            } else {
                endHand()
            }
            return
        }
        
        resetBettingState()
        
        if canBet.count <= 1 {
            runOutBoard()
            return
        }
        
        activePlayerIndex = nextActivePlayerIndex(after: dealerIndex)
        
        #if DEBUG
        print("--- \(currentStreet.rawValue) | Community: \(communityCards.map { $0.description }.joined(separator: " ")) ---")
        #endif
        
        checkBotTurn()
    }
    
    // MARK: - Action Processing
    
    func processAction(_ action: PlayerAction) {
        guard activePlayerIndex >= 0 && activePlayerIndex < players.count else { return }
        guard players[activePlayerIndex].status == .active else { return }
        guard !isHandOver else { return }
        
        let player = players[activePlayerIndex]
        let playerID = player.id
        
        let result = BettingManager.processAction(
            action, player: player, currentBet: currentBet, minRaise: minRaise
        )
        
        // Apply results back to engine state
        players[activePlayerIndex] = result.playerUpdate
        pot.add(result.potAddition)
        currentBet = result.newCurrentBet
        minRaise = result.newMinRaise
        if let raiserID = result.newLastRaiserID { lastRaiserID = raiserID }
        if result.isNewAggressor && currentStreet == .preFlop { preflopAggressorID = playerID }
        if result.reopenAction {
            for p in players where p.status == .active && p.id != playerID {
                hasActed[p.id] = false
            }
        }
        hasActed[playerID] = true
        
        // Side effects: sound, log, stats, animation
        playSoundForAction(action)
        recordActionLog(action: action, player: result.playerUpdate)
        recordActionStats(action: action, originalPlayer: player, updatedPlayer: result.playerUpdate, potAddition: result.potAddition)
        
        if result.potAddition > 0 {
            NotificationCenter.default.post(
                name: NSNotification.Name("ChipAnimation"),
                object: nil,
                userInfo: ["seatIndex": activePlayerIndex, "amount": result.potAddition]
            )
        }
        
        #if DEBUG
        print("  \(result.playerUpdate.name): \(action.description) | chips=\(result.playerUpdate.chips) bet=\(result.playerUpdate.currentBet) pot=\(pot.total)")
        #endif
        
        // Check if only 1 non-folded player remains
        let nonFolded = players.filter { $0.status != .folded && $0.status != .eliminated }
        if nonFolded.count == 1 {
            endHand()
            return
        }
        
        if BettingManager.isRoundComplete(players: players, hasActed: hasActed, currentBet: currentBet) {
            dealNextStreet()
        } else {
            advanceTurn()
        }
    }
    
    // MARK: - Turn Management
    
    private func advanceTurn() {
        activePlayerIndex = nextActivePlayerIndex(after: activePlayerIndex)
        checkBotTurn()
    }
    
    func checkBotTurn() {
        guard activePlayerIndex >= 0 && activePlayerIndex < players.count else { return }
        let player = players[activePlayerIndex]
        guard !player.isHuman && player.status == .active else { return }
        guard !isHandOver else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self, !self.isHandOver else { return }
            let currentPlayer = self.players[self.activePlayerIndex]
            guard currentPlayer.status == .active && !currentPlayer.isHuman else { return }
            let action = DecisionEngine.makeDecision(player: currentPlayer, engine: self)
            self.processAction(action)
        }
    }
    
    // MARK: - Final Rankings
    
    func generateFinalResults() -> [PlayerResult] {
        GameResultsManager.generateFinalResults(
            players: players, handNumber: handNumber, eliminationOrder: eliminationOrder
        )
    }
    
    // MARK: - Helpers
    
    func postBlind(playerIndex: Int, amount: Int) {
        BettingManager.postBlind(
            playerIndex: playerIndex, amount: amount,
            players: &players, pot: &pot, hasActed: &hasActed
        )
    }
    
    func postAnte(playerIndex: Int, amount: Int) {
        let actualAnte = min(players[playerIndex].chips, amount)
        players[playerIndex].chips -= actualAnte
        players[playerIndex].totalBetThisHand += actualAnte
        pot.add(actualAnte)
        if players[playerIndex].chips == 0 {
            players[playerIndex].status = .allIn
            hasActed[players[playerIndex].id] = true
        }
    }
    
    func nextActivePlayerIndex(after index: Int) -> Int {
        guard !players.isEmpty else { return 0 }
        let safeIndex = ((index % players.count) + players.count) % players.count
        var next = (safeIndex + 1) % players.count
        var attempts = 0
        while players[next].status != .active && attempts < players.count {
            next = (next + 1) % players.count
            attempts += 1
        }
        #if DEBUG
        if attempts >= players.count {
            print("⚠️ nextActivePlayerIndex: No active players found! Returning \(next)")
        }
        #endif
        return next
    }
    
    func resetBettingState() {
        let state = BettingManager.resetBettingState(players: &players, bigBlindAmount: bigBlindAmount)
        currentBet = state.currentBet
        minRaise = state.minRaise
        hasActed = state.hasActed
        lastRaiserID = nil
    }
}
