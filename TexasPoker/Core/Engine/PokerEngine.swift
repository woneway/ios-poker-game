import Foundation
import Combine

@MainActor
class PokerEngine: ObservableObject {
    private let logger = AppLogger.shared

    @Published var deck: Deck
    @Published var players: [Player]
    @Published var communityCards: [Card]
    @Published var pot: Pot
    @Published var dealerIndex: Int
    @Published var activePlayerIndex: Int
    @Published var currentStreet: Street

    @Published var currentBet: Int = 0
    @Published var minRaise: Int = 0

    @Published var winners: [UUID] = []
    @Published var winMessage: String = ""
    @Published var isHandOver: Bool = false

    @Published var handNumber: Int = 0

    @Published var actionLog: [ActionLogEntry] = []
    let maxLogEntries = 30
    
    var aiDecisionDelay: Double = 0.0
    var useSyncAIDecision: Bool = false

    /// 动作记录器 - 支持依赖注入
    let actionRecorder: ActionRecorderProtocol

    /// 事件发布器 - 支持依赖注入
    let eventPublisher: EventPublisherProtocol

    /// 音效管理器 - 支持依赖注入
    let soundManager: SoundManagerProtocol

    /// 动画管理器 - 支持依赖注入
    let animationManager: AnimationManagerProtocol

    /// 资金管理器 - 支持依赖注入
    let bankrollManager: BankrollManagerProtocol

    /// 决策引擎 - 支持依赖注入
    let decisionEngine: DecisionEngineProtocol

    
    // MARK: - Computed Properties
    
    var activePlayers: [Player] {
        players.filter { $0.status == .active || $0.status == .allIn }
    }
    
    var activePlayerCount: Int {
        activePlayers.count
    }
    
    var eliminatedPlayers: [Player] {
        players.filter { $0.status == .eliminated }
    }
    
    var nonFoldedPlayers: [Player] {
        players.filter { $0.status != .folded && $0.status != .eliminated }
    }

    @Published var hasActed: [UUID: Bool] = [:]
    var lastRaiserID: UUID? = nil
    var bigBlindIndex: Int = 0
    var smallBlindIndex: Int = 0

    @Published var preflopAggressorID: UUID? = nil

    var lastHandLosers: Set<UUID> = []
    var lastPotSize: Int = 0

    @Published var eliminationOrder: [(name: String, avatar: String, hand: Int, isHuman: Bool)] = []

    var bettingHistory: [Street: [BetAction]] = [:]

    var smallBlindAmount: Int = 10
    var bigBlindAmount: Int = 20

    @Published var gameMode: GameMode = .cashGame
    @Published var tournamentConfig: TournamentConfig?
    @Published var currentBlindLevel: Int = 0
    @Published var handsAtCurrentLevel: Int = 0
    @Published var anteAmount: Int = 0
    @Published var rebuyCount: Int = 0

    @Published var cashGameConfig: CashGameConfig?

    /// 追踪引擎是否已注册到 DecisionEngine（避免重复注销）
    private var isRegistered: Bool = false

    /// 标记引擎已被销毁（防止 deinit 中重复操作）
    private var isEngineDestroyed: Bool = false

    /// 当前活跃的异步任务引用，用于优雅取消
    private var currentTask: Task<Void, Never>?

    /// 初始化引擎（支持依赖注入）
    /// - Parameters:
    ///   - mode: 游戏模式
    ///   - config: 锦标赛配置（仅锦标赛模式需要）
    ///   - cashGameConfig: 现金桌配置（仅现金桌模式需要）
    ///   - difficulty: AI 难度
    ///   - playerCount: 玩家数量
    ///   - actionRecorder: 动作记录器（可选，默认使用单例）
    ///   - eventPublisher: 事件发布器（可选，默认使用单例）
    ///   - soundManager: 音效管理器（可选，默认使用单例）
    ///   - animationManager: 动画管理器（可选，默认使用单例）
    ///   - bankrollManager: 资金管理器（可选，默认使用单例）
    ///   - decisionEngine: 决策引擎（可选，默认使用单例）
    init(
        mode: GameMode = .cashGame,
        config: TournamentConfig? = nil,
        cashGameConfig: CashGameConfig? = nil,
        difficulty: AIProfile.Difficulty? = nil,
        playerCount: Int = 8,
        actionRecorder: ActionRecorderProtocol? = nil,
        eventPublisher: EventPublisherProtocol? = nil,
        soundManager: SoundManagerProtocol? = nil,
        animationManager: AnimationManagerProtocol? = nil,
        bankrollManager: BankrollManagerProtocol? = nil,
        decisionEngine: DecisionEngineProtocol? = nil
    ) {
        // 初始化依赖（如果没有提供则使用默认单例）
        self.actionRecorder = actionRecorder ?? DefaultActionRecorder.shared
        self.eventPublisher = eventPublisher ?? DefaultEventPublisher.shared
        self.soundManager = soundManager ?? DefaultSoundManager.shared
        self.animationManager = animationManager ?? DefaultAnimationManager.shared
        self.bankrollManager = bankrollManager ?? DefaultBankrollManager.shared
        self.decisionEngine = decisionEngine ?? DefaultDecisionEngine.shared

        self.deck = Deck()
        self.players = []
        self.communityCards = []
        self.pot = Pot()
        self.dealerIndex = -1
        self.activePlayerIndex = 0
        self.currentStreet = .preFlop

        if let difficulty = difficulty {
            setupTable(difficulty: difficulty, playerCount: playerCount)
        } else {
            setup8PlayerTable()
        }

        self.gameMode = mode
        self.tournamentConfig = config
        
        if mode == .cashGame {
            self.cashGameConfig = cashGameConfig ?? .default
        }
        
        if mode == .tournament, let config = config {
            let blinds = TournamentManager.applyConfig(config, players: &players)
            self.smallBlindAmount = blinds.smallBlind
            self.bigBlindAmount = blinds.bigBlind
            self.anteAmount = blinds.ante
            self.currentBlindLevel = 0
            self.handsAtCurrentLevel = 0
        }

        // 注册引擎到 DecisionEngine（用于对手模型管理）
        DecisionEngine.registerEngine(self)
        self.isRegistered = true
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
        players.append(Player(name: heroName, chips: GameConstants.Game.defaultStartingChips, isHuman: true))
        
        // Add AI opponents based on difficulty
        let aiCount = min(playerCount - 1, 7)
        let profiles = difficulty.randomOpponents(count: aiCount)
        
        for profile in profiles {
            players.append(Player(
                name: profile.name,
                chips: GameConstants.Game.defaultStartingChips,
                isHuman: false,
                aiProfile: profile
            ))
        }
        
        // Use cashGameConfig blind values if in cash game mode
        if gameMode == .cashGame, let config = cashGameConfig {
            smallBlindAmount = config.smallBlind
            bigBlindAmount = config.bigBlind
        }
    }
    
    /// Legacy setup for backward compatibility
    private func setup8PlayerTable() {
        // 使用默认初始筹码（与Player模型默认值保持一致）
        let defaultStartingChips = GameConstants.Game.defaultStartingChips

        players = [
            Player(name: "Hero", chips: defaultStartingChips, isHuman: true),
            Player(name: "石头", chips: defaultStartingChips, isHuman: false, aiProfile: .rock, entryIndex: 1),
            Player(name: "疯子麦克", chips: defaultStartingChips, isHuman: false, aiProfile: .maniac, entryIndex: 1),
            Player(name: "安娜", chips: defaultStartingChips, isHuman: false, aiProfile: .callingStation, entryIndex: 1),
            Player(name: "老狐狸", chips: defaultStartingChips, isHuman: false, aiProfile: .fox, entryIndex: 1),
            Player(name: "鲨鱼汤姆", chips: defaultStartingChips, isHuman: false, aiProfile: .shark, entryIndex: 1),
            Player(name: "艾米", chips: defaultStartingChips, isHuman: false, aiProfile: .academic, entryIndex: 1),
            Player(name: "大卫", chips: defaultStartingChips, isHuman: false, aiProfile: .tiltDavid, entryIndex: 1),
        ]
        
        // Use cashGameConfig blind values if in cash game mode
        if gameMode == .cashGame, let config = cashGameConfig {
            smallBlindAmount = config.smallBlind
            bigBlindAmount = config.bigBlind
        }
    }
    
    // MARK: - Rebuy

    /// Rebuy：恢复玩家状态和筹码
    /// 注意：此方法仅在锦标赛模式下有效，现金局不应调用
    func rebuyPlayer(playerIndex: Int, chips: Int) {
        // 安全检查：锦标赛模式强制检查
        guard gameMode == .tournament else {
            #if DEBUG
            logger.warning("Rebuy attempted in non-tournament mode - blocked for safety", category: .game)
            #endif
            return
        }
        guard playerIndex >= 0 && playerIndex < players.count else { return }
        guard players[playerIndex].status == .eliminated else { return }
        guard chips > 0 else { return }
        
        players[playerIndex].chips = chips
        players[playerIndex].status = .active
        rebuyCount += 1

        #if DEBUG
        logger.info("\(players[playerIndex].name) Rebuy 成功，筹码: \(chips)，总 Rebuy 次数: \(rebuyCount)", category: .game)
        #endif
    }
    
    // MARK: - Top Up
    
    /// Top up a player to a specific chip amount (cash game buy-in)
    func topUpPlayer(playerIndex: Int, toAmount: Int) {
        guard let config = cashGameConfig else { return }
        guard playerIndex >= 0 && playerIndex < players.count else { return }
        guard players[playerIndex].status != .eliminated else { return }
        guard toAmount > players[playerIndex].chips else { return }
        guard toAmount <= config.maxBuyIn else { return }
        
        players[playerIndex].chips = toAmount
    }
    
    // MARK: - Lifecycle

    deinit {
        // 取消所有异步任务，防止销毁后访问已释放对象
        currentTask?.cancel()
        currentTask = nil
        isEngineDestroyed = true

        // 注销引擎（安全检查在 DecisionEngine 内部处理）
        DecisionEngine.unregisterEngine(self)
    }

    /// 标记是否通过 destroy() 方法显式销毁
    private var isEngineDestroyedByDestroy: Bool = false

    /// 安全清理引擎资源（替代直接 deinit，供外部调用）
    /// 调用后引擎将不再可用
    func destroy() {
        guard !isEngineDestroyedByDestroy else { return }

        currentTask?.cancel()
        currentTask = nil
        isEngineDestroyed = true
        isEngineDestroyedByDestroy = true

        if isRegistered {
            DecisionEngine.unregisterEngine(self)
            isRegistered = false
        }
    }
    
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

        // 关键修复：当所有玩家都是 all-in 时（没有 active 玩家），
        // 或者只有1个active玩家但有all-in玩家时，应该先发完剩余公共牌再结算
        let activePlayersCount = players.filter { $0.status == .active }.count
        let allInPlayersCount = players.filter { $0.status == .allIn }.count
        
        if activePlayersCount == 0 || (activePlayersCount == 1 && allInPlayersCount >= 1) {
            #if DEBUG
            logger.debug("dealNextStreet: 玩家all-in状态: active=\(activePlayersCount), allIn=\(allInPlayersCount)，发完公共牌后结算", category: .game)
            #endif
            runOutBoard()
            return
        }

        // canBet 应该同时考虑 active 和 allIn 玩家
        // allIn 玩家不能再下注，但仍然参与后续发牌和底池争夺
        let canBet = players.filter { $0.status == .active || $0.status == .allIn }

        // 只有在需要继续下注时才提前发牌（只有 active 玩家可以继续下注）
        if activePlayersCount >= 2 {
            // 有足够的 active 玩家，可以继续正常发牌流程
            DealingManager.dealStreetCards(deck: &deck, communityCards: &communityCards, currentStreet: &currentStreet)
        }

        if currentStreet == .river {
            // Fix: river 街的判断也应该同时考虑 active 和 allIn 玩家
            // 而不是只检查 active 玩家数量
            resetBettingState()
            if canBet.count >= 2 {
                let nextIdx = nextActivePlayerIndex(after: dealerIndex)
                if nextIdx >= 0 {
                    activePlayerIndex = nextIdx
                    checkBotTurn()
                } else {
                    // 没有活跃玩家，结束手牌
                    endHand()
                }
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
        
        let nextIdx = nextActivePlayerIndex(after: dealerIndex)
        if nextIdx >= 0 {
            activePlayerIndex = nextIdx
        } else {
            // 没有活跃玩家（但可能还有 allIn 玩家）
            // 检查是否应该 runOutBoard 而非直接结束游戏
            let allInPlayers = players.filter { $0.status == .allIn }
            if allInPlayers.count >= 2 {
                runOutBoard()
            } else {
                endHand()
            }
            return
        }

        #if DEBUG
        logger.debug("\(currentStreet.rawValue) | Community: \(communityCards.map { $0.description }.joined(separator: " "))", category: .game)
        #endif

        checkBotTurn()
    }

    // MARK: - Action Validation

    /// 检查当前活跃玩家是否可以执行 check 操作
    /// - Returns: 如果当前下注额等于玩家当前下注额（即不需要跟注），返回 true
    func canCheck() -> Bool {
        guard activePlayerIndex >= 0 && activePlayerIndex < players.count else { return false }
        let player = players[activePlayerIndex]
        return player.currentBet == currentBet
    }

    /// 获取当前玩家需要跟注的金额
    /// - Returns: 需要跟注的金额（如果为 0 表示可以 check）
    func callAmount() -> Int {
        guard activePlayerIndex >= 0 && activePlayerIndex < players.count else { return 0 }
        let player = players[activePlayerIndex]
        return currentBet - player.currentBet
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

        // 检查操作是否有效，无效则忽略
        guard result.isValid else {
            #if DEBUG
            logger.warning("无效操作被忽略: \(player.name) 尝试 \(action.description)", category: .game)
            #endif
            return
        }

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
        
        // 所有有效的玩家操作（包括 check）都应该标记为 hasActed[playerID] = true
        // 只有无效的操作才不应该标记为已完成行动
        if result.isValid {
            hasActed[playerID] = true
            
            // 记录下注历史（用于AI决策如triple barrel检测）
            if result.potAddition > 0 {
                let betType: BetAction.ActionType
                switch action {
                case .call: betType = .call
                case .raise: betType = .raise
                case .allIn: betType = .raise  // allIn treated as raise for betting history
                case .check, .fold: betType = .check
                }
                let betAction = BetAction(street: currentStreet, type: betType, amount: result.potAddition)
                if bettingHistory[currentStreet] == nil {
                    bettingHistory[currentStreet] = []
                }
                bettingHistory[currentStreet]?.append(betAction)
            }
        }
        
        // Side effects: sound, log, stats, animation
        playSoundForAction(action)
        recordActionLog(action: action, player: result.playerUpdate)
        recordActionStats(action: action, originalPlayer: player, updatedPlayer: result.playerUpdate, potAddition: result.potAddition)
        
        if result.potAddition > 0 {
            eventPublisher.publishChipAnimation(seatIndex: activePlayerIndex, amount: result.potAddition)
        }

        #if DEBUG
        logger.debug("\(result.playerUpdate.name): \(action.description) | chips=\(result.playerUpdate.chips) bet=\(result.playerUpdate.currentBet) pot=\(pot.total)", category: .game)
        #endif

        // Check if only 1 non-folded player remains
        // allIn玩家仍然在参与手牌，应该被计入
        let nonFolded = players.filter { $0.status != .folded && $0.status != .eliminated }
        if nonFolded.count == 1 {
            endHand()
            return
        }
        
        if BettingManager.isRoundComplete(players: players, hasActed: hasActed, currentBet: currentBet) {
            dealNextStreet()
        } else {
            // 轮次未结束，继续下一个玩家
            advanceTurn()
        }
    }
    
    // MARK: - Turn Management
    
    private func advanceTurn() {
        let nextIdx = nextActivePlayerIndex(after: activePlayerIndex)
        if nextIdx >= 0 {
            activePlayerIndex = nextIdx
            checkBotTurn()
        } else {
            // 没有活跃玩家，结束手牌
            endHand()
        }
    }
    
    func checkBotTurn() {
        guard activePlayerIndex >= 0 && activePlayerIndex < players.count else { return }
        let player = players[activePlayerIndex]
        guard !player.isHuman && player.status == .active else { return }
        guard !isHandOver else { return }

        // 同步模式：立即执行 AI 决策（无延迟）
        if useSyncAIDecision {
            executeAIDecision()
            return
        }

        // 取消之前的任务（如果存在）
        currentTask?.cancel()

        // 捕获当前状态快照（值类型拷贝，避免引用问题）
        let capturedIndex = activePlayerIndex
        let capturedStreet = currentStreet
        let capturedHandOver = isHandOver
        let capturedDecisionDelay = aiDecisionDelay

        // 使用 Task 进行异步执行，并保存引用以便后续取消
        // 注意：Task 闭包外部捕获 self，但内部使用弱引用避免循环
        currentTask = Task { [weak self] in
            guard let self = self else { return }

            // 等待指定的决策延迟
            if capturedDecisionDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(capturedDecisionDelay * 1_000_000_000))

                // 睡眠后立即检查取消状态，确保任务取消时能立即响应
                if Task.isCancelled { return }
            }

            // ========== 验证检查（按优先级排序）==========

            // 1. 检查任务是否被取消（Swift 内置机制）- 使用 guard 确保真正退出
            guard !Task.isCancelled else { return }

            // 2. 检查引擎是否已销毁
            guard !self.isEngineDestroyed else { return }

            // 3. 检查游戏是否已结束
            guard !self.isHandOver else { return }

            // 4. 检查街道是否变化（状态一致性验证）
            guard self.currentStreet == capturedStreet else { return }

            // 5. 再次检查手牌状态
            guard self.isHandOver == capturedHandOver else { return }

            // 6. 验证玩家仍然符合条件（使用捕获的值而不是重新访问数组）
            guard capturedIndex >= 0 && capturedIndex < self.players.count else { return }

            // 7. 额外安全检查：确保仍然是当前活跃玩家
            guard self.activePlayerIndex == capturedIndex else { return }

            // 在主线程上安全地访问玩家并进行决策
            await MainActor.run { [weak self] in
                guard let self = self else { return }

                // 最终安全检查（在主线程执行）
                guard self.activePlayerIndex == capturedIndex else { return }
                guard capturedIndex < self.players.count else { return }
                let currentPlayer = self.players[capturedIndex]
                guard currentPlayer.status == .active && !currentPlayer.isHuman else { return }
                guard !self.isHandOver else { return }

                self.executeAIDecisionForPlayer(currentPlayer, capturedIndex: capturedIndex)
            }
        }
    }
    
    private func executeAIDecision() {
        guard activePlayerIndex >= 0 && activePlayerIndex < players.count else { return }
        let currentPlayer = players[activePlayerIndex]
        guard currentPlayer.status == .active && !currentPlayer.isHuman else { return }
        executeAIDecisionForPlayer(currentPlayer, capturedIndex: activePlayerIndex)
    }
    
    private func executeAIDecisionForPlayer(_ currentPlayer: Player, capturedIndex: Int) {
        // 使用注入的决策引擎（支持依赖注入和测试 mock）
        let action = decisionEngine.makeDecision(player: currentPlayer, engine: self)

        let equity = MonteCarloSimulator.calculateEquity(
            holeCards: currentPlayer.holeCards,
            communityCards: self.communityCards,
            playerCount: 2,
            iterations: 100
        )
        let potOdds = self.currentBet > 0 ? Double(self.currentBet - currentPlayer.currentBet) / Double(self.pot.total) : 0
        decisionEngine.publishDecision(
            player: currentPlayer,
            action: action,
            equity: equity,
            potOdds: potOdds
        )

        self.processAction(action)
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
        guard !players.isEmpty else { return -1 }
        
        // 首先检查是否有任何可行动的玩家（只有 active 玩家才能行动，allIn 不能）
        let hasActivePlayer = players.contains { $0.status == .active }
        if !hasActivePlayer {
            #if DEBUG
            logger.warning("nextActivePlayerIndex: No active players found! Returning -1", category: .game)
            #endif
            return -1
        }

        let safeIndex = ((index % players.count) + players.count) % players.count
        var next = (safeIndex + 1) % players.count
        var attempts = 0
        
        // 循环查找下一个 active 玩家（只有 active 玩家才能行动）
        while players[next].status != .active && attempts < players.count {
            next = (next + 1) % players.count
            attempts += 1
        }
        
        // 如果遍历完所有玩家都没有找到 active 玩家，返回 -1
        if attempts >= players.count {
            #if DEBUG
            logger.warning("nextActivePlayerIndex: No active players found after full cycle! Returning -1", category: .game)
            #endif
            return -1
        }
        
        return next
    }
    
    func resetBettingState() {
        let state = BettingManager.resetBettingState(players: &players, bigBlindAmount: bigBlindAmount)
        currentBet = state.currentBet
        minRaise = state.minRaise
        hasActed = state.hasActed
        lastRaiserID = nil
    }

    // MARK: - Profile Switch Handling

    /// Reset game engine when profile changes
    /// Called by ProfileManager when creating or switching profiles
    func resetForProfile() {
        // Reset hand counter
        handNumber = 0

        // Reset all players to initial chips
        for i in 0..<players.count {
            players[i].chips = GameConstants.Game.defaultStartingChips
            players[i].currentBet = 0
            players[i].totalBetThisHand = 0  // 修复：重置本手牌总投注额
            players[i].status = .active
            players[i].holeCards = []
        }

        // Reset pot
        pot = Pot()

        // Clear community cards
        communityCards = []

        // Reset dealer
        dealerIndex = -1

        // Reset betting state
        currentBet = 0
        minRaise = 0
        hasActed = [:]
        lastRaiserID = nil

        // Reset street
        currentStreet = .preFlop
        activePlayerIndex = 0

        // Reset hand state
        isHandOver = false
        winners = []
        winMessage = ""

        // Clear action log
        actionLog = []

        // Reset elimination tracking
        eliminationOrder = []

        // Reset internal tracking
        preflopAggressorID = nil
        lastHandLosers = []
        lastPotSize = 0

        // Reset tilt system
        TiltManager.resetAllTilt(players: &players)
        
        // Reset betting history (之前遗漏)
        bettingHistory = [:]
        
        // Reset tournament state (之前遗漏)
        rebuyCount = 0
        handsAtCurrentLevel = 0
        currentBlindLevel = 0

        #if DEBUG
        logger.info("PokerEngine.resetForProfile() called - game state reset for new profile", category: .game)
        #endif
    }
}
