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
    
    let smallBlindAmount = 10
    let bigBlindAmount = 20
    
    init() {
        self.deck = Deck()
        self.players = []
        self.communityCards = []
        self.pot = Pot()
        self.dealerIndex = -1
        self.activePlayerIndex = 0
        self.currentStreet = .preFlop
        
        setup8PlayerTable()
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
        
        // Post blinds
        postBlind(playerIndex: smallBlindIndex, amount: smallBlindAmount)
        postBlind(playerIndex: bigBlindIndex, amount: bigBlindAmount)
        
        // Deal hole cards (2 to each active player)
        for _ in 0..<2 {
            var idx = nextActivePlayerIndex(after: dealerIndex)
            for _ in 0..<players.count {
                if players[idx].status == .active || players[idx].status == .allIn {
                    if let card = deck.deal() {
                        players[idx].holeCards.append(card)
                    }
                }
                idx = (idx + 1) % players.count
            }
        }
        
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
    
    /// 发当前街的公共牌（burn + deal）
    private func dealStreetCards() {
        _ = deck.deal() // burn card
        
        switch currentStreet {
        case .preFlop:
            currentStreet = .flop
            if let c1 = deck.deal(), let c2 = deck.deal(), let c3 = deck.deal() {
                communityCards.append(contentsOf: [c1, c2, c3])
            }
        case .flop:
            currentStreet = .turn
            if let c = deck.deal() { communityCards.append(c) }
        case .turn:
            currentStreet = .river
            if let c = deck.deal() { communityCards.append(c) }
        case .river:
            break // already at river, nothing to deal
        }
    }
    
    /// 重置 betting state（每条新街开始时调用）
    private func resetBettingState() {
        currentBet = 0
        minRaise = bigBlindAmount
        lastRaiserID = nil
        hasActed = [:]
        for i in 0..<players.count {
            players[i].currentBet = 0
        }
        for player in players where player.status == .active {
            hasActed[player.id] = false
        }
    }
    
    /// 所有人 All-in 时，快速依次发完剩余公共牌然后结算
    private func runOutBoard() {
        // 计算还需要发几条街
        let streetsToGo: Int
        switch currentStreet {
        case .preFlop: streetsToGo = 3 // flop + turn + river（但 flop 已经在 dealNextStreet 中发了）
        case .flop: streetsToGo = 2    // turn + river
        case .turn: streetsToGo = 1    // river
        case .river: streetsToGo = 0
        }
        
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
        
        var player = players[activePlayerIndex]
        let playerID = player.id
        
        switch action {
        case .fold:
            player.status = .folded
            
        case .check:
            if player.currentBet != currentBet {
                // Invalid check, fold instead
                player.status = .folded
            }
            
        case .call:
            let amountNeeded = currentBet - player.currentBet
            let actualAmount = min(amountNeeded, player.chips)
            player.chips -= actualAmount
            player.currentBet += actualAmount
            player.totalBetThisHand += actualAmount
            pot.add(actualAmount)
            if player.chips == 0 { player.status = .allIn }
            
        case .raise(let raiseToAmount):
            let minimumRaiseTo = currentBet + minRaise
            let actualRaiseTo = max(raiseToAmount, minimumRaiseTo)
            let amountNeeded = actualRaiseTo - player.currentBet
            let actualAmount = min(amountNeeded, player.chips)
            
            player.chips -= actualAmount
            player.currentBet += actualAmount
            player.totalBetThisHand += actualAmount
            pot.add(actualAmount)
            
            if player.currentBet > currentBet {
                let raiseSize = player.currentBet - currentBet
                minRaise = max(minRaise, raiseSize)
                currentBet = player.currentBet
                lastRaiserID = playerID
                if currentStreet == .preFlop { preflopAggressorID = playerID }
                
                // Re-open action for all other active players
                for p in players where p.status == .active && p.id != playerID {
                    hasActed[p.id] = false
                }
            }
            if player.chips == 0 { player.status = .allIn }
            
        case .allIn:
            let amount = player.chips
            player.chips = 0
            player.currentBet += amount
            player.totalBetThisHand += amount
            pot.add(amount)
            if player.currentBet > currentBet {
                let raiseSize = player.currentBet - currentBet
                minRaise = max(minRaise, raiseSize)
                currentBet = player.currentBet
                lastRaiserID = playerID
                if currentStreet == .preFlop { preflopAggressorID = playerID }
                for p in players where p.status == .active && p.id != playerID {
                    hasActed[p.id] = false
                }
            }
            player.status = .allIn
        }
        
        // Write back
        players[activePlayerIndex] = player
        hasActed[playerID] = true
        
        // 记录操作日志
        let logAmount: Int? = {
            switch action {
            case .call: return player.currentBet
            case .raise(let to): return to
            case .allIn: return player.currentBet
            default: return nil
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
        
        #if DEBUG
        print("  \(player.name): \(action.description) | chips=\(player.chips) bet=\(player.currentBet) pot=\(pot.total)")
        #endif
        
        // Check if only 1 non-folded player remains
        let nonFolded = players.filter { $0.status != .folded && $0.status != .eliminated }
        if nonFolded.count == 1 {
            endHand()
            return
        }
        
        if isRoundComplete() {
            dealNextStreet()
        } else {
            advanceTurn()
        }
    }
    
    // MARK: - Round Completion
    
    private func isRoundComplete() -> Bool {
        let activePlayers = players.filter { $0.status == .active }
        if activePlayers.isEmpty { return true }
        
        for player in activePlayers {
            if hasActed[player.id] != true { return false }
            if player.currentBet != currentBet { return false }
        }
        return true
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
        
        if eligible.count == 1 {
            // 所有人弃牌，唯一存活者赢得全部
            distributeSingleWinner(eligible[0])
        } else if eligible.count > 1 {
            // 计算边池
            pot.calculatePots(players: players)
            // Showdown: 逐池结算
            distributeWithSidePots(eligible: eligible)
        }
        
        isHandOver = true
        
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
    
    /// 唯一存活者（所有人弃牌）赢得全部奖池
    private func distributeSingleWinner(_ winner: Player) {
        let totalPot = pot.total
        if let index = players.firstIndex(where: { $0.id == winner.id }) {
            players[index].chips += totalPot
            winners.append(winner.id)
            winMessage = "\(winner.name) 赢得 $\(totalPot)!"
        }
        trackLosers(winnerIDs: [winner.id])
    }
    
    /// Showdown: 逐池结算（支持主池 + 多个边池）
    private func distributeWithSidePots(eligible: [Player]) {
        var message = ""
        var allWinnerIDs = Set<UUID>()
        
        for (potIdx, portion) in pot.portions.enumerated() {
            // 过滤出该池有资格的玩家
            let potEligible = eligible.filter { portion.eligiblePlayerIDs.contains($0.id) }
            guard !potEligible.isEmpty else { continue }
            
            // 如果只有一人有资格，直接获得
            if potEligible.count == 1 {
                let winner = potEligible[0]
                if let index = players.firstIndex(where: { $0.id == winner.id }) {
                    players[index].chips += portion.amount
                    allWinnerIDs.insert(winner.id)
                    if !winners.contains(winner.id) { winners.append(winner.id) }
                    let potLabel = potIdx == 0 ? "主池" : "边池\(potIdx)"
                    message += "\(winner.name) 赢得\(potLabel) $\(portion.amount)! "
                }
                continue
            }
            
            // 评估手牌
            var playerScores: [(Player, Int, [Int])] = []
            for player in potEligible {
                let score = HandEvaluator.evaluate(holeCards: player.holeCards, communityCards: communityCards)
                playerScores.append((player, score.0, score.1))
            }
            
            playerScores.sort { (lhs, rhs) in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return compareKickers(lhs.2, rhs.2) > 0
            }
            
            guard let best = playerScores.first else { continue }
            let potWinners = playerScores.filter {
                $0.1 == best.1 && compareKickers($0.2, best.2) == 0
            }.map { $0.0 }
            
            // 分配该池
            let winAmount = portion.amount / potWinners.count
            let remainder = portion.amount % potWinners.count
            
            let potLabel = potIdx == 0 ? "主池" : "边池\(potIdx)"
            
            for (i, winner) in potWinners.enumerated() {
                if let index = players.firstIndex(where: { $0.id == winner.id }) {
                    let bonus = (i == 0) ? remainder : 0
                    players[index].chips += winAmount + bonus
                    allWinnerIDs.insert(winner.id)
                    if !winners.contains(winner.id) { winners.append(winner.id) }
                    message += "\(winner.name) 赢得\(potLabel) $\(winAmount + bonus)! "
                }
            }
        }
        
        winMessage = message.trimmingCharacters(in: .whitespaces)
        trackLosers(winnerIDs: allWinnerIDs)
    }
    
    /// 追踪输家（用于 tilt 系统）
    private func trackLosers(winnerIDs: Set<UUID>) {
        lastHandLosers = Set(players.filter {
            ($0.status == .active || $0.status == .allIn || $0.status == .folded) &&
            !winnerIDs.contains($0.id) && $0.totalBetThisHand > 0
        }.map { $0.id })
        lastPotSize = pot.total
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
        let actualBet = min(players[playerIndex].chips, amount)
        players[playerIndex].chips -= actualBet
        players[playerIndex].currentBet += actualBet
        players[playerIndex].totalBetThisHand += actualBet
        pot.add(actualBet)
        if players[playerIndex].chips == 0 {
            players[playerIndex].status = .allIn
            // 盲注导致 All-in 的玩家标记为已行动，避免 isRoundComplete 卡死
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
    
    private func compareKickers(_ k1: [Int], _ k2: [Int]) -> Int {
        for i in 0..<min(k1.count, k2.count) {
            if k1[i] > k2[i] { return 1 }
            if k1[i] < k2[i] { return -1 }
        }
        return 0
    }
}
