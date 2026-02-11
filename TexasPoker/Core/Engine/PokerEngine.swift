import Foundation
import Combine

/// 操作日志条目
struct ActionLogEntry: Identifiable {
    let id = UUID()
    let playerName: String
    let avatar: String
    let action: PlayerAction
    let amount: Int?      // 涉及金额（call/raise/allIn）
    let street: Street
    let timestamp: Date = Date()
    
    /// 动作描述（中文）
    var actionText: String {
        switch action {
        case .fold: return "弃牌"
        case .check: return "过牌"
        case .call: return amount.map { "跟注 $\($0)" } ?? "跟注"
        case .raise(let to): return "加注到 $\(to)"
        case .allIn: return "全下 $\(amount ?? 0)"
        }
    }
    
    /// 动作图标（SF Symbol）
    var iconName: String {
        switch action {
        case .fold: return "hand.raised.slash.fill"
        case .check: return "checkmark.circle.fill"
        case .call: return "arrow.right.circle.fill"
        case .raise: return "arrow.up.circle.fill"
        case .allIn: return "flame.fill"
        }
    }
    
    /// 动作颜色
    var color: String {
        switch action {
        case .fold: return "gray"
        case .check: return "green"
        case .call: return "blue"
        case .raise: return "orange"
        case .allIn: return "red"
        }
    }
}

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
    
    // Hand counter (for tilt tracking)
    @Published var handNumber: Int = 0
    
    // Action log
    @Published var actionLog: [ActionLogEntry] = []
    /// 最多保留的日志条数
    private let maxLogEntries = 30
    
    // Internal tracking
    private var hasActed: [UUID: Bool] = [:]
    private var lastRaiserID: UUID? = nil
    private var bigBlindIndex: Int = 0
    private var smallBlindIndex: Int = 0
    
    /// Tracks who was the preflop aggressor (raiser) for c-bet logic
    @Published var preflopAggressorID: UUID? = nil
    
    // Previous hand results (for tilt system)
    private var lastHandLosers: Set<UUID> = []
    private var lastPotSize: Int = 0
    
    // Elimination tracking (for final rankings)
    /// Records (playerName, avatar, eliminatedAtHand) in order of elimination (first eliminated = last place)
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
            applyTournamentConfig(config)
        }
    }
    
    // MARK: - 8-Player Table Setup
    
    private func setup8PlayerTable() {
        players = [
            // Seat 0: Hero (bottom center)
            Player(name: "Hero", chips: 1000, isHuman: true),
            // Seat 1: 石头 (bottom-left)
            Player(name: "石头", chips: 1000, aiProfile: .rock),
            // Seat 2: 疯子麦克 (left)
            Player(name: "疯子麦克", chips: 1000, aiProfile: .maniac),
            // Seat 3: 安娜 (top-left)
            Player(name: "安娜", chips: 1000, aiProfile: .callingStation),
            // Seat 4: 老狐狸 (top)
            Player(name: "老狐狸", chips: 1000, aiProfile: .fox),
            // Seat 5: 鲨鱼汤姆 (top-right)
            Player(name: "鲨鱼汤姆", chips: 1000, aiProfile: .shark),
            // Seat 6: 艾米 (right)
            Player(name: "艾米", chips: 1000, aiProfile: .academic),
            // Seat 7: 大卫 (bottom-right)
            Player(name: "大卫", chips: 1000, aiProfile: .tiltDavid)
        ]
    }
    
    private func applyTournamentConfig(_ config: TournamentConfig) {
        guard !config.blindSchedule.isEmpty else { return }
        let firstLevel = config.blindSchedule[0]
        self.smallBlindAmount = firstLevel.smallBlind
        self.bigBlindAmount = firstLevel.bigBlind
        self.anteAmount = firstLevel.ante
        self.currentBlindLevel = 0
        self.handsAtCurrentLevel = 0
        
        // Update starting chips for all players
        for i in 0..<players.count {
            players[i].chips = config.startingChips
        }
    }
    
    // MARK: - Position Helpers
    
    /// Calculate seat offset from dealer (0=BTN, 1=SB, 2=BB, 3=UTG, ...)
    func seatOffsetFromDealer(playerIndex: Int) -> Int {
        let offset = (playerIndex - dealerIndex + players.count) % players.count
        return offset
    }
    
    /// Check if a player is in late position (BTN, CO, HJ)
    func isLatePosition(playerIndex: Int) -> Bool {
        let offset = seatOffsetFromDealer(playerIndex: playerIndex)
        return offset == 0 || offset >= players.count - 2  // BTN, CO, HJ
    }
    
    // MARK: - Hand Lifecycle
    
    func startHand() {
        handNumber += 1
        
        // Update tilt levels before starting
        updateTiltLevels()
        
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
            if players[i].chips > 0 {
                players[i].status = .active
            } else {
                players[i].status = .eliminated
            }
        }
        
        // Move dealer button
        dealerIndex = nextActivePlayerIndex(after: dealerIndex)
        
        // Determine blind positions
        let activePlayers = players.filter { $0.status == .active || $0.status == .allIn }
        if activePlayers.count <= 1 {
            // Not enough players for a hand
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
        
        // Deal hole cards (2 to each active player)
        DealingManager.dealHoleCards(deck: &deck, players: &players, dealerIndex: dealerIndex)
        
        // Set current bet to BB amount
        currentBet = bigBlindAmount
        minRaise = bigBlindAmount
        
        // First to act preFlop: player after BB
        activePlayerIndex = nextActivePlayerIndex(after: bigBlindIndex)
        
        // Mark all active players as not having acted yet
        for player in players where player.status == .active {
            hasActed[player.id] = false
        }
        
        // 清空上一手日志，记录新手牌开始
        actionLog.removeAll()
        
        #if DEBUG
        print("=== Hand #\(handNumber): Dealer=\(players[dealerIndex].name), SB=\(players[smallBlindIndex].name), BB=\(players[bigBlindIndex].name) ===")
        #endif
        
        checkBotTurn()
        
        // Record hand start
        ActionRecorder.shared.startHand(
            handNumber: handNumber,
            gameMode: gameMode,
            players: players
        )
    }
    
    func dealNextStreet() {
        // Check if hand should end (only 1 non-folded player)
        let nonFolded = players.filter { $0.status == .active || $0.status == .allIn }
        if nonFolded.count <= 1 {
            endHand()
            return
        }
        
        // Check how many players can still bet (not all-in, not folded, not eliminated)
        let canBet = players.filter { $0.status == .active }
        
        // Deal the current street's cards
        dealStreetCards()
        
        // If we just dealt the river, end hand
        if currentStreet == .river {
            resetBettingState()
            // 如果还有能下注的玩家，让他们完成行动
            if canBet.count >= 2 {
                activePlayerIndex = nextActivePlayerIndex(after: dealerIndex)
                checkBotTurn()
            } else {
                endHand()
            }
            return
        }
        
        // Reset betting state for new street
        resetBettingState()
        
        // 只有当 0 个玩家能下注时（全员 all-in），才跳过 betting 直接跑完公共牌
        // 当有 1 个 active 玩家面对 all-in 时，他仍需要选择 call/fold
        if canBet.count == 0 {
            runOutBoard()
            return
        }
        
        // First to act post-flop: first active player after dealer
        activePlayerIndex = nextActivePlayerIndex(after: dealerIndex)
        
        #if DEBUG
        print("--- \(currentStreet.rawValue) | Community: \(communityCards.map { $0.description }.joined(separator: " ")) ---")
        #endif
        
        checkBotTurn()
    }
    
    /// 发当前街的公共牌（burn + deal）— 委托给 DealingManager
    private func dealStreetCards() {
        DealingManager.dealStreetCards(deck: &deck, communityCards: &communityCards, currentStreet: &currentStreet)
    }
    
    /// 重置 betting state（每条新街开始时调用）
    private func resetBettingState() {
        let state = BettingManager.resetBettingState(players: &players, bigBlindAmount: bigBlindAmount)
        currentBet = state.currentBet
        minRaise = state.minRaise
        hasActed = state.hasActed
        lastRaiserID = nil
    }
    
    /// 所有人 All-in 时，快速依次发完剩余公共牌然后结算
    private func runOutBoard() {
        // 计算还需要发几条街
        let streetsToGo = DealingManager.streetsRemaining(from: currentStreet)
        
        guard streetsToGo > 0 else {
            endHand()
            return
        }
        
        // 逐步发牌，每张延迟 0.8 秒（给玩家视觉反馈）
        for i in 0..<streetsToGo {
            let delay = Double(i + 1) * 0.8
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, !self.isHandOver else { return }
                self.dealStreetCards()
                
                // 最后一条街发完后结算
                if i == streetsToGo - 1 {
                    self.endHand()
                }
            }
        }
    }
    
    // MARK: - Action Processing
    
    func processAction(_ action: PlayerAction) {
        guard activePlayerIndex >= 0 && activePlayerIndex < players.count else { return }
        guard players[activePlayerIndex].status == .active else { return }
        guard !isHandOver else { return }
        
        let player = players[activePlayerIndex]
        let playerID = player.id
        
        // Delegate betting logic to BettingManager
        let result = BettingManager.processAction(
            action,
            player: player,
            currentBet: currentBet,
            minRaise: minRaise
        )
        
        // Apply results back to engine state
        players[activePlayerIndex] = result.playerUpdate
        pot.add(result.potAddition)
        currentBet = result.newCurrentBet
        minRaise = result.newMinRaise
        if let raiserID = result.newLastRaiserID {
            lastRaiserID = raiserID
        }
        if result.isNewAggressor && currentStreet == .preFlop {
            preflopAggressorID = playerID
        }
        if result.reopenAction {
            for p in players where p.status == .active && p.id != playerID {
                hasActed[p.id] = false
            }
        }
        hasActed[playerID] = true
        
        // Play sound for action
        switch action {
        case .fold:
            SoundManager.shared.playSound(.fold)
        case .check:
            SoundManager.shared.playSound(.check)
        case .call:
            SoundManager.shared.playSound(.call)
        case .raise:
            SoundManager.shared.playSound(.raise)
        case .allIn:
            SoundManager.shared.playSound(.allIn)
        }
        
        // 记录操作日志
        let updatedPlayer = result.playerUpdate
        let logAmount: Int? = {
            switch action {
            case .call: return updatedPlayer.currentBet
            case .raise(let to): return to
            case .allIn: return updatedPlayer.currentBet
            default: return nil
            }
        }()
        let avatar = updatedPlayer.aiProfile?.avatar ?? (updatedPlayer.isHuman ? "🤠" : "🤖")
        let entry = ActionLogEntry(
            playerName: updatedPlayer.name,
            avatar: avatar,
            action: action,
            amount: logAmount,
            street: currentStreet
        )
        actionLog.append(entry)
        if actionLog.count > maxLogEntries {
            actionLog.removeFirst(actionLog.count - maxLogEntries)
        }
        
        // Trigger chip animation for betting actions
        if result.potAddition > 0 {
            NotificationCenter.default.post(
                name: NSNotification.Name("ChipAnimation"),
                object: nil,
                userInfo: ["seatIndex": activePlayerIndex, "amount": result.potAddition]
            )
        }
        
        #if DEBUG
        print("  \(updatedPlayer.name): \(action.description) | chips=\(updatedPlayer.chips) bet=\(updatedPlayer.currentBet) pot=\(pot.total)")
        #endif
        
        // Record action for statistics
        let isVoluntary = determineIfVoluntary(action: action, player: player)
        let position = getPosition(playerIndex: activePlayerIndex)
        ActionRecorder.shared.recordAction(
            playerName: updatedPlayer.name,
            action: action,
            amount: result.potAddition,
            street: currentStreet,
            isVoluntary: isVoluntary,
            position: position
        )
        
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
    
    private func checkBotTurn() {
        guard activePlayerIndex >= 0 && activePlayerIndex < players.count else { return }
        let player = players[activePlayerIndex]
        guard !player.isHuman && player.status == .active else { return }
        guard !isHandOver else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self, !self.isHandOver else { return }
            let currentPlayer = self.players[self.activePlayerIndex]
            guard currentPlayer.status == .active && !currentPlayer.isHuman else { return }
            
            let action = DecisionEngine.makeDecision(
                player: currentPlayer,
                engine: self
            )
            self.processAction(action)
        }
    }
    
    // MARK: - Hand End
    
    private func endHand() {
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
        for winnerID in result.winnerIDs {
            if let winnerIndex = players.firstIndex(where: { $0.id == winnerID }) {
                // Notify for highlight effect
                NotificationCenter.default.post(
                    name: NSNotification.Name("PlayerWon"),
                    object: nil,
                    userInfo: ["playerID": winnerID]
                )
                
                // Trigger chip animation
                let winnerAmount = players[winnerIndex].chips - (players[winnerIndex].chips - result.totalPot / result.winnerIDs.count)
                NotificationCenter.default.post(
                    name: NSNotification.Name("WinnerChipAnimation"),
                    object: nil,
                    userInfo: ["seatIndex": winnerIndex, "amount": winnerAmount]
                )
            }
        }
        
        // Record hand end for statistics
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
        
        // Record Hero win/loss for difficulty adjustment
        if let hero = players.first(where: { $0.isHuman }) {
            let heroWon = winners.contains(where: { $0.id == hero.id })
            DecisionEngine.difficultyManager.recordHand(heroWon: heroWon)
        }
        
        // Check for blind level up in tournaments
        checkBlindLevelUp()
        
        // Track newly eliminated players
        for player in players {
            if player.chips <= 0 &&
               !eliminationOrder.contains(where: { $0.name == player.name }) {
                let avatar = player.aiProfile?.avatar ?? (player.isHuman ? "🎯" : "🤖")
                eliminationOrder.append((
                    name: player.name,
                    avatar: avatar,
                    hand: handNumber,
                    isHuman: player.isHuman
                ))
            }
        }
        
        #if DEBUG
        print("=== Hand #\(handNumber) Over: \(winMessage) ===\n")
        #endif
    }
    
    // MARK: - Tilt System
    
    private func updateTiltLevels() {
        for i in 0..<players.count {
            guard var profile = players[i].aiProfile else { continue }
            
            if lastHandLosers.contains(players[i].id) {
                // Lost last hand - increase tilt based on sensitivity and pot size
                let tiltIncrease = profile.tiltSensitivity * Double(lastPotSize) / 800.0
                profile.currentTilt = min(1.0, profile.currentTilt + tiltIncrease)
            } else {
                // Didn't lose - tilt decays slowly (realistic: takes many hands to cool down)
                let decayRate = 0.03 * (1.0 - profile.tiltSensitivity * 0.5)
                profile.currentTilt = max(0.0, profile.currentTilt - decayRate)
            }
            
            players[i].aiProfile = profile
        }
    }
    
    private func checkBlindLevelUp() {
        guard gameMode == .tournament,
              let config = tournamentConfig else { return }
        
        handsAtCurrentLevel += 1
        
        if handsAtCurrentLevel >= config.handsPerLevel {
            let nextLevel = currentBlindLevel + 1
            guard nextLevel < config.blindSchedule.count else { return }
            
            let level = config.blindSchedule[nextLevel]
            smallBlindAmount = level.smallBlind
            bigBlindAmount = level.bigBlind
            anteAmount = level.ante
            currentBlindLevel = nextLevel
            handsAtCurrentLevel = 0
            
            #if DEBUG
            print("🔔 Blinds increased to \(level.description)")
            #endif
        }
    }
    
    // MARK: - Final Rankings
    
    /// Generate final game results sorted by rank (1st place first)
    func generateFinalResults() -> [PlayerResult] {
        let totalPlayers = players.count
        var results: [PlayerResult] = []
        
        // Winner(s) - players still with chips
        let alive = players.filter { $0.chips > 0 }
        for (i, p) in alive.enumerated() {
            let avatar = p.aiProfile?.avatar ?? (p.isHuman ? "🎯" : "🤖")
            results.append(PlayerResult(
                name: p.name,
                avatar: avatar,
                rank: i + 1,
                finalChips: p.chips,
                handsPlayed: handNumber,
                isHuman: p.isHuman
            ))
        }
        
        // Eliminated players - reverse elimination order (last eliminated = 2nd place)
        let eliminated = eliminationOrder.reversed()
        for (i, entry) in eliminated.enumerated() {
            let rank = alive.count + i + 1
            results.append(PlayerResult(
                name: entry.name,
                avatar: entry.avatar,
                rank: rank,
                finalChips: 0,
                handsPlayed: entry.hand,
                isHuman: entry.isHuman
            ))
        }
        
        return results.sorted { $0.rank < $1.rank }
    }
    
    // MARK: - Helpers
    
    private func postBlind(playerIndex: Int, amount: Int) {
        BettingManager.postBlind(
            playerIndex: playerIndex,
            amount: amount,
            players: &players,
            pot: &pot,
            hasActed: &hasActed
        )
    }
    
    private func postAnte(playerIndex: Int, amount: Int) {
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
        // 安全处理负数索引（如 dealerIndex 初始值 -1）
        let safeIndex = ((index % players.count) + players.count) % players.count
        var next = (safeIndex + 1) % players.count
        var attempts = 0
        while players[next].status != .active && attempts < players.count {
            next = (next + 1) % players.count
            attempts += 1
        }
        return next
    }
    
    // MARK: - Statistics Helpers
    
    private func determineIfVoluntary(action: PlayerAction, player: Player) -> Bool {
        // Big blind passive call is not voluntary
        if currentStreet == .preFlop && 
           players[bigBlindIndex].id == player.id &&
           case .call = action &&
           currentBet == bigBlindAmount {
            return false
        }
        // Fold and check are not voluntary investments
        return action != .fold && action != .check
    }
    
    private func getPosition(playerIndex: Int) -> String {
        let offset = seatOffsetFromDealer(playerIndex: playerIndex)
        let activeCount = players.filter { $0.status == .active || $0.status == .allIn }.count
        
        if activeCount == 2 {
            // Heads-up
            return offset == 0 ? "BTN/SB" : "BB"
        }
        
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
