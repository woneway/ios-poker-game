import Foundation

/// 轻量级游戏状态 - 纯数据结构，可在任意线程运行
struct LiteGameState: Equatable {
    var players: [LitePlayer]
    var deck: [Card]
    var communityCards: [Card] = []
    var pot: LitePot = LitePot()

    var dealerIndex: Int = -1
    var activePlayerIndex: Int = 0

    var currentStreet: Street = .preFlop

    var currentBet: Int = 0
    var minRaise: Int = 0

    var hasActed: [UUID: Bool] = [:]
    var lastRaiserID: UUID?
    var preflopAggressorID: UUID?

    var smallBlindIndex: Int = 0
    var bigBlindIndex: Int = 0

    var smallBlindAmount: Int = 10
    var bigBlindAmount: Int = 20

    var handNumber: Int = 0
    var isHandOver: Bool = false
    var winners: [UUID] = []

    /// 当前活跃玩家数量
    var activePlayerCount: Int {
        players.filter { $0.status == .active || $0.status == .allIn }.count
    }

    /// 获取活跃玩家列表
    var activePlayers: [LitePlayer] {
        players.filter { $0.status == .active || $0.status == .allIn }
    }

    /// 获取未弃牌玩家列表
    var nonFoldedPlayers: [LitePlayer] {
        players.filter { $0.status != .folded && $0.status != .eliminated }
    }

    /// 有筹码的玩家数量（用于判断游戏是否结束）
    var playersWithChips: Int {
        players.filter { $0.chips > 0 }.count
    }

    /// 初始化
    init(players: [LitePlayer], smallBlind: Int = 10, bigBlind: Int = 20) {
        self.players = players
        self.deck = Self.createStandardDeck()
        self.smallBlindAmount = smallBlind
        self.bigBlindAmount = bigBlind
    }

    /// 创建标准52张牌
    private static func createStandardDeck() -> [Card] {
        var cards: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                cards.append(Card(rank: rank, suit: suit))
            }
        }
        return cards.shuffled()
    }

    /// 重置牌堆
    mutating func resetDeck() {
        deck = Self.createStandardDeck()
    }

    /// 发一张牌
    mutating func dealCard() -> Card? {
        guard !deck.isEmpty else { return nil }
        return deck.removeLast()
    }

    /// 发底牌给所有活跃玩家
    mutating func dealHoleCards() {
        var playersWithCards = 0

        for i in 0..<players.count {
            guard players[i].chips > 0 else { continue }
            guard let card1 = dealCard(), let card2 = dealCard() else {
                // 牌数不足，给没有牌的玩家标记为无法参与
                #if DEBUG
                print("⚠️ LiteGameState: 牌数不足，无法给所有玩家发牌")
                #endif
                break
            }
            players[i].holeCards = [card1, card2]
            players[i].status = .active
            players[i].currentBet = 0
            players[i].totalBetThisHand = 0
            playersWithCards += 1
        }

        // 如果没有足够的玩家有牌，标记手牌结束
        if playersWithCards < 2 {
            #if DEBUG
            print("⚠️ LiteGameState: 只有 \(playersWithCards) 个玩家有牌，不足以进行游戏")
            #endif
        }
    }

    /// 发下一条街公共牌
    mutating func dealNextStreet() {
        let needed: Int
        switch currentStreet {
        case .preFlop:
            currentStreet = .flop
            needed = 3
        case .flop:
            currentStreet = .turn
            needed = 1
        case .turn:
            currentStreet = .river
            needed = 1
        case .river:
            return
        }

        for _ in 0..<needed {
            if let card = dealCard() {
                communityCards.append(card)
            }
        }
    }

    /// 重置手牌状态
    mutating func resetForNewHand() {
        // 重置牌堆
        resetDeck()

        // 统计有筹码的玩家数量
        let playersWithChips = players.filter { $0.chips > 0 }.count

        // 如果玩家数量不足，标记手牌结束
        if playersWithChips < 2 {
            #if DEBUG
            print("⚠️ LiteGameState: 只有 \(playersWithChips) 个玩家有筹码，手牌结束")
            #endif
            isHandOver = true
            winners = players.filter { $0.chips > 0 }.map { $0.id }
            return
        }

        // 重置玩家状态
        for i in 0..<players.count {
            players[i].holeCards = []
            players[i].status = players[i].chips > 0 ? .active : .eliminated
            players[i].currentBet = 0
            players[i].totalBetThisHand = 0
        }

        // 重置公共牌和奖池
        communityCards = []
        pot = LitePot()

        // 重置下注状态
        currentBet = 0
        minRaise = 0
        hasActed = [:]
        lastRaiserID = nil
        preflopAggressorID = nil

        // 移动庄家位到下一个有筹码的玩家
        dealerIndex = findNextPlayerWithChips(from: dealerIndex)

        // 设置大小盲位置（跳过没有筹码的玩家）
        smallBlindIndex = findNextPlayerWithChips(from: dealerIndex)
        bigBlindIndex = findNextPlayerWithChips(from: smallBlindIndex)

        // 检查是否有足够的玩家有筹码（使用已有的属性）
        guard self.playersWithChips >= 2 else {
            isHandOver = true
            winners = players.filter { $0.chips > 0 }.map { $0.id }
            return
        }

        // 发底牌
        dealHoleCards()

        // 再次检查是否有足够的玩家有牌
        let playersWithHoleCards = players.filter { $0.holeCards.count == 2 }.count
        if playersWithHoleCards < 2 {
            #if DEBUG
            print("⚠️ LiteGameState: 只有 \(playersWithHoleCards) 个玩家有底牌，手牌结束")
            #endif
            isHandOver = true
            winners = players.filter { $0.chips > 0 }.map { $0.id }
            return
        }

        // 投盲注
        postBlinds()

        // 设置当前行动玩家
        activePlayerIndex = findNextPlayerWithChips(from: bigBlindIndex)

        // 重置手牌状态
        isHandOver = false
        winners = []
        currentStreet = .preFlop
        handNumber += 1
    }

    /// 投盲注
    private mutating func postBlinds() {
        // 安全检查：确保索引有效
        guard smallBlindIndex < players.count && bigBlindIndex < players.count else { return }

        // 小盲
        let sbPlayer = players[smallBlindIndex]
        if sbPlayer.chips > 0 {
            let actual = min(sbPlayer.chips, smallBlindAmount)
            players[smallBlindIndex].chips -= actual
            players[smallBlindIndex].currentBet = actual
            players[smallBlindIndex].totalBetThisHand += actual
            pot.add(actual)
        }

        // 大盲
        let bbPlayer = players[bigBlindIndex]
        if bbPlayer.chips > 0 {
            let actual = min(bbPlayer.chips, bigBlindAmount)
            players[bigBlindIndex].chips -= actual
            players[bigBlindIndex].currentBet = actual
            players[bigBlindIndex].totalBetThisHand += actual
            pot.add(actual)
        }

        // 计算当前最高下注
        currentBet = max(players[smallBlindIndex].currentBet, players[bigBlindIndex].currentBet)
        minRaise = max(currentBet * 2, bigBlindAmount)
    }

    /// 获取当前玩家
    var currentPlayer: LitePlayer? {
        guard activePlayerIndex >= 0 && activePlayerIndex < players.count else { return nil }
        return players[activePlayerIndex]
    }

    /// 找到下一个可行动玩家
    mutating func nextActivePlayer() -> Bool {
        let startIndex = activePlayerIndex
        var attempts = 0

        while attempts < players.count {
            activePlayerIndex = (activePlayerIndex + 1) % max(1, players.count)

            let player = players[activePlayerIndex]
            if player.status == .active && player.chips > 0 {
                return true
            }

            attempts += 1

            // 检查是否所有人都已行动
            if allPlayersActed() {
                return false
            }
        }

        return false
    }

    /// 检查是否所有玩家都已行动
    private func allPlayersActed() -> Bool {
        let active = players.filter { $0.status == .active || $0.status == .allIn }
        for player in active {
            if hasActed[player.id] != true {
                return false
            }
        }
        return !active.isEmpty
    }

    /// 检查当前玩家是否可以 check
    func currentPlayerCanCheck() -> Bool {
        guard let player = currentPlayer else { return false }
        return player.currentBet == currentBet
    }

    /// 当前玩家需要跟注的金额
    func currentPlayerCallAmount() -> Int {
        guard let player = currentPlayer else { return 0 }
        return currentBet - player.currentBet
    }

    /// 结束手牌
    mutating func endHand(with winners: [UUID]) {
        self.winners = winners
        self.isHandOver = true
    }

    /// 找到下一个有筹码的玩家索引
    private func findNextPlayerWithChips(from startIndex: Int) -> Int {
        guard !players.isEmpty else { return 0 }

        // 首先检查起始位置的玩家是否有筹码
        if players[startIndex].chips > 0 {
            return startIndex
        }

        // 向前搜索有筹码的玩家
        for i in 1..<players.count {
            let index = (startIndex + i) % players.count
            if players[index].chips > 0 {
                return index
            }
        }

        // 没有找到有筹码的玩家，返回起始位置
        return startIndex
    }
}
