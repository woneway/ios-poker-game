import Foundation
import Combine

class PokerGameStore: ObservableObject {
    @Published private(set) var state: GameState = .idle
    @Published var engine: PokerEngine
    @Published var isGameOver: Bool = false
    @Published var finalResults: [PlayerResult] = []
    @Published var showRankings: Bool = false
    @Published var isBackgroundSimulating: Bool = false
    
    // MARK: - Game Configuration
    private var gameDifficulty: AIProfile.Difficulty?
    private var gamePlayerCount: Int = 8
    
    // MARK: - Spectating State
    @Published var isSpectating: Bool = false
    @Published var spectateSpeed: SpectateSpeed = .normal
    @Published var spectatePaused: Bool = false
    @Published var spectateHandCount: Int = 0
    @Published var lastSpectateWinner: String = ""
    @Published var lastSpectateWinAmount: Int = 0
    
    // MARK: - Cash Game State
    @Published var isLeavingAfterHand: Bool = false
    @Published var showBuyIn: Bool = false
    @Published var showLeaveConfirm: Bool = false
    @Published var showCashSessionSummary: Bool = false
    @Published var currentSession: CashGameSession?
    // 记录这手牌开始时 hero 的 chips，用于正确计算盈利
    private var heroChipsAtHandStart: Int = 0
    
    enum SpectateSpeed: Double, CaseIterable, Identifiable {
        case slow = 0.5
        case normal = 0.2
        case fast = 0.05
        
        var id: Double { rawValue }
        
        var displayName: String {
            switch self {
            case .slow: return "慢速"
            case .normal: return "正常"
            case .fast: return "快速"
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var gameRecordSaved = false
    private var dealCompleteTimer: DispatchWorkItem?
    private var backgroundSimulationTask: DispatchWorkItem?
    private var spectateLoopTask: DispatchWorkItem?
    
    // MARK: - 异步任务追踪（用于正确取消）
    private var pollTasks: [DispatchWorkItem] = []
    private var pollTasksCancelled = false  // 标志位：标记是否需要取消正在执行的任务
    private var watchdogTask: DispatchWorkItem?
    private var runOutBoardTasks: [DispatchWorkItem] = []
    
    /// Number of background hands to simulate per batch
    private let backgroundHandsPerBatch = 100
    /// Number of batches to simulate
    private let backgroundBatches = 10
    
    /// 当前是否是人类玩家的回合
    var isHumanTurn: Bool {
        let idx = engine.activePlayerIndex
        guard idx >= 0 && idx < engine.players.count else { return false }
        return engine.players[idx].isHuman && engine.players[idx].status == .active
    }
    
    init(mode: GameMode = .cashGame, config: TournamentConfig? = nil, cashGameConfig: CashGameConfig? = nil, difficulty: AIProfile.Difficulty? = nil, playerCount: Int = 8) {
        self.gameDifficulty = difficulty
        self.gamePlayerCount = playerCount
        self.engine = PokerEngine(mode: mode, config: config, cashGameConfig: cashGameConfig, difficulty: difficulty, playerCount: playerCount)
        // 注册引擎以追踪对手模型
        DecisionEngine.registerEngine(self.engine)
        subscribeToEngine()
    }
    
    /// 订阅引擎的 Combine 事件
    private func subscribeToEngine() {
        // Forward engine changes to SwiftUI
        engine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // BUG FIX 1: 检查 isHandOver 是否在订阅前就已经是 true
        // 如果是，立即触发 handOver 事件
        if engine.isHandOver && state != .showdown {
            #if DEBUG
            print("⚠️ Engine isHandOver is already true at subscription time!")
            #endif
            DispatchQueue.main.async { [weak self] in
                self?.send(.handOver)
            }
        }
        
        // Listen for hand-over
        engine.$isHandOver
            .removeDuplicates()
            .filter { $0 == true }
            .sink { [weak self] _ in
                self?.send(.handOver)
            }
            .store(in: &cancellables)
        
        // When active player changes, check if we should transition to waitingForAction
        engine.$activePlayerIndex
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.state == .betting && self.isHumanTurn {
                    self.state = .waitingForAction
                }
            }
            .store(in: &cancellables)
        
        // Safety net: whenever state becomes .betting, poll until human turn or state changes
        // This handles the race condition where AI finishes during .dealing state
        $state
            .filter { $0 == .betting }
            .sink { [weak self] _ in
                guard let self = self else { return }
                // 立即同步检查是否是人类玩家的回合，避免延迟
                if self.isHumanTurn {
                    self.state = .waitingForAction
                    return
                }
                self.pollForHumanTurn()
                self.scheduleAIWatchdog()
                self.scheduleHandOverWatchdog()
            }
            .store(in: &cancellables)
        
        // BUG FIX 1: 添加对 waitingForAction 状态的监控
        $state
            .filter { $0 == .waitingForAction }
            .sink { [weak self] _ in
                self?.scheduleHandOverWatchdog()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - BUG FIX 1: Hand Over Watchdog
    
    /// 定时检查机制：如果 engine.isHandOver == true 但状态不是 .showdown，强制转换
    private var handOverWatchdogTask: DispatchWorkItem?
    
    private func scheduleHandOverWatchdog() {
        // 取消之前的 watchdog 任务
        handOverWatchdogTask?.cancel()
        
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // 检查引擎是否已结束但状态机不知道
            if self.engine.isHandOver && self.state != .showdown {
                #if DEBUG
                print("⚠️ HandOver Watchdog: engine.isHandOver is true but state is \(self.state). Forcing transition to showdown.")
                #endif
                self.send(.handOver)
            }
            
            // 检查状态是否长时间停留在 betting/waitingForAction 且没有活跃玩家
            if (self.state == .betting || self.state == .waitingForAction) {
                let activePlayers = self.engine.players.filter { $0.status == .active }
                if activePlayers.isEmpty && self.engine.isHandOver {
                    #if DEBUG
                    print("⚠️ HandOver Watchdog: No active players and engine.isHandOver is true. Forcing transition to showdown.")
                    #endif
                    self.send(.handOver)
                }
            }
        }
        handOverWatchdogTask = task
        // 定期检查，每 2 秒一次
        DispatchQueue.main.asyncAfter(deadline: .now() + GameConstants.Delays.showdown, execute: task)
    }
    
    /// 轮询检查是否轮到人类玩家（解决 AI 在 dealing 期间已完成行动的竞态问题）
    private func pollForHumanTurn() {
        // 取消之前的所有 poll 任务
        pollTasks.forEach { $0.cancel() }
        pollTasks.removeAll()
        
        // 设置取消标志位（用于取消正在执行的任务）
        pollTasksCancelled = true

        // 检查多次，覆盖 AI 延迟执行的时间窗口
        for _ in [0.1, 0.5, 1.0, 2.0, 3.0] {
            let task = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                // 检查是否需要取消
                guard !self.pollTasksCancelled else { return }
                guard self.state == .betting else { return }

                let isHuman = self.isHumanTurn
                #if DEBUG
                print("🔍 Poll: state=\(self.state), activeIdx=\(self.engine.activePlayerIndex), isHumanTurn=\(isHuman)")
                if let player = self.engine.players.indices.contains(self.engine.activePlayerIndex) ? self.engine.players[self.engine.activePlayerIndex] : nil {
                    print("   ActivePlayer: \(player.name), status=\(player.status), isHuman=\(player.isHuman)")
                }
                #endif

                if isHuman {
                    print("✅ Poll detected human turn, switching to waitingForAction")
                    self.state = .waitingForAction
                }
            }
            pollTasks.append(task)
            DispatchQueue.main.asyncAfter(deadline: .now() + GameConstants.Delays.playerAction, execute: task)
        }
    }

    /// 监控 AI 是否卡住，如果卡住则强制触发
    private func scheduleAIWatchdog() {
        // 取消之前的 watchdog 任务
        watchdogTask?.cancel()

        let task = DispatchWorkItem { [weak self] in
            guard let self = self, self.state == .betting else { return }

            // 如果依然是 AI 回合（非人类回合），尝试踢一下引擎
            if !self.isHumanTurn {
                #if DEBUG
                print("⚠️ AI Watchdog: Kicking engine to check bot turn. ActiveIdx=\(self.engine.activePlayerIndex)")
                #endif
                self.engine.checkBotTurn()

                // 递归调度，直到状态改变（添加深度限制防止无限递归）
                self.scheduleAIWatchdog()
            } else {
                // It IS human turn, but state is still betting? Force switch.
                print("⚠️ AI Watchdog: It IS human turn but state is .betting. Forcing switch.")
                self.state = .waitingForAction
            }
        }
        watchdogTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + GameConstants.Delays.showdown, execute: task)
    }
    
    /// Number of players still in the game (chips > 0)
    var remainingPlayerCount: Int {
        engine.players.filter { $0.chips > 0 }.count
    }
    
    /// The final winner if only 1 player remains
    var finalWinner: Player? {
        let alive = engine.players.filter { $0.chips > 0 }
        return alive.count == 1 ? alive.first : nil
    }
    
    func send(_ event: GameEvent) {
        #if DEBUG
        print("FSM: Event=\(event), State=\(state)")
        #endif
        
        switch (state, event) {
        case (.idle, .start):
            guard remainingPlayerCount >= 2 else {
                finishGame()
                return
            }
            // 记录这手牌开始时 hero 的 chips
            #if DEBUG
            print("📊 .idle -> .start: 调用 recordHeroChipsAtHandStart, handNumber=\(engine.handNumber)")
            #endif
            self.recordHeroChipsAtHandStart()
            state = .dealing
            engine.startHand()
            scheduleDealCompleteTimer()
            
        case (.dealing, .dealComplete):
            dealCompleteTimer?.cancel()
            dealCompleteTimer = nil
            if engine.isHandOver {
                state = .showdown
            } else if isHumanTurn {
                state = .waitingForAction
            } else {
                state = .betting
                // pollForHumanTurn 会通过 $state 订阅自动触发
            }
            
        case (.waitingForAction, .playerActed):
            // 人类玩家操作后，检查新状态
            if engine.isHandOver {
                state = .showdown
            } else if isHumanTurn {
                state = .waitingForAction
            } else {
                state = .betting
            }
            
        case (.betting, .handOver):
            state = .showdown
            if remainingPlayerCount <= 1 {
                finishGame()
            }
            // 现金局：记录每手盈利
            #if DEBUG
            print("📊 .betting -> .handOver: 调用 recordHandProfit, handNumber=\(engine.handNumber)")
            #endif
            if engine.gameMode == .cashGame {
                recordHandProfit()
            }
            if isLeavingAfterHand && engine.gameMode == .cashGame {
                // 延迟自动离开，让玩家看到 showdown 结果
                DispatchQueue.main.asyncAfter(deadline: .now() + GameConstants.Delays.playerAction) { [weak self] in
                    self?.leaveTable()
                }
            }
            
        case (.waitingForAction, .handOver):
            // 人类操作导致一手结束
            state = .showdown
            if remainingPlayerCount <= 1 {
                finishGame()
            }
            // 现金局：记录每手盈利
            #if DEBUG
            print("📊 .waitingForAction -> .handOver: 调用 recordHandProfit, handNumber=\(engine.handNumber)")
            #endif
            if engine.gameMode == .cashGame {
                recordHandProfit()
            }
            if isLeavingAfterHand && engine.gameMode == .cashGame {
                // 延迟自动离开，让玩家看到 showdown 结果
                DispatchQueue.main.asyncAfter(deadline: .now() + GameConstants.Delays.playerAction) { [weak self] in
                    self?.leaveTable()
                }
            }
            
        case (.showdown, .nextHand), (.showdown, .start):
            guard remainingPlayerCount >= 2 else {
                finishGame()
                return
            }
            // 现金局：如果hero被淘汰需要rebuy，阻止继续游戏
            if engine.gameMode == .cashGame && showBuyIn {
                #if DEBUG
                print("⏸️ 现金局：hero需要rebuy，暂停游戏")
                #endif
                return
            }
            #if DEBUG
            print("📊 .showdown -> .nextHand: 调用 recordHeroChipsAtHandStart, handNumber before startHand=\(engine.handNumber)")
            #endif
            state = .dealing
            engine.startHand()
            // 在 engine.startHand() 之后记录 hero chips，因为此时新的一手牌已经开始了
            self.recordHeroChipsAtHandStart()
            scheduleDealCompleteTimer()
            
        // MARK: - Spectating Transitions
        case (.showdown, .startSpectating), (.idle, .startSpectating):
            startSpectating()
            
        case (.waitingForAction, .startSpectating):
            // 玩家在等待操作时选择观战，先自动弃牌当前手牌
            if let heroIndex = engine.players.firstIndex(where: { $0.isHuman }),
               engine.players[heroIndex].status == .active {
                engine.processAction(.fold)
            }
            startSpectating()
            
        case (.spectating, .pauseSpectating):
            pauseSpectating()
            
        case (.spectating, .resumeSpectating):
            resumeSpectating()
            
        case (.spectating, .stopSpectating):
            stopSpectating()
            
        // MARK: - Cash Game Leave Table
        case (.idle, .leaveTable), (.showdown, .leaveTable):
            guard engine.gameMode == .cashGame else { break }
            leaveTable()

        // 玩家在游戏进行中离开（waitingForAction/betting 状态）
        case (.waitingForAction, .leaveTable), (.betting, .leaveTable):
            guard engine.gameMode == .cashGame else { break }
            isLeavingAfterHand = true
            // 自动帮玩家弃牌
            if engine.players.contains(where: { $0.isHuman }) {
                engine.processAction(.fold)
            }
            showLeaveConfirm = false

        // 玩家在发牌阶段离开
        case (.dealing, .leaveTable):
            guard engine.gameMode == .cashGame else { break }
            isLeavingAfterHand = true
            showLeaveConfirm = false

        default:
            #if DEBUG
            print("FSM: Invalid transition \(state) + \(event) — recovering to safe state")
            #endif
            // BUG FIX 3: 增强错误恢复逻辑
            // 1. 如果引擎已经结束手牌，强制转换到 showdown
            if engine.isHandOver && state != .showdown {
                state = .showdown
            }
            // 2. 如果没有活跃玩家且不在 showdown/idle 状态，尝试恢复
            // 注意：即使所有玩家都 fold 了，也要先等 showdown 完成才能进入 idle
            let activePlayers = engine.players.filter { $0.status == .active }
            if activePlayers.isEmpty && state != .showdown && state != .idle {
                if engine.isHandOver {
                    state = .showdown
                }
                // 不要在这里设置为 .idle，让正常的流程处理 showdown
            }
            // 3. 如果 activePlayerIndex 指向无效位置，尝试恢复
            if engine.activePlayerIndex < 0 || engine.activePlayerIndex >= engine.players.count {
                if engine.isHandOver {
                    state = .showdown
                }
            }
            // 4. 如果当前状态是 betting/waitingForAction 但引擎已结束，强制恢复
            if (state == .betting || state == .waitingForAction) && engine.isHandOver {
                state = .showdown
            }
        }
    }
    
    /// 调度可取消的 dealComplete 兜底 timer
    private func scheduleDealCompleteTimer() {
        dealCompleteTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.state == .dealing else { return }
            self.send(.dealComplete)
        }
        dealCompleteTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + GameConstants.Delays.tiltWarning, execute: work)
    }
    
    // MARK: - Game Over
    
    private func finishGame() {
        isGameOver = true
        
        guard !gameRecordSaved else { return }
        gameRecordSaved = true
        
        // Generate final results
        finalResults = engine.generateFinalResults()
        
        // Calculate payouts for tournament mode
        if engine.gameMode == .tournament,
           let config = engine.tournamentConfig {
            let totalPrizePool = engine.players.count * config.startingChips
            for i in 0..<min(finalResults.count, config.payoutStructure.count) {
                let payout = Int(Double(totalPrizePool) * config.payoutStructure[i])
                finalResults[i].payout = payout
            }
        }
        
        showRankings = true
        
        // Save to history
        let heroRank = finalResults.first(where: { $0.isHuman })?.rank ?? finalResults.count
        let record = GameRecord(
            totalHands: engine.handNumber,
            totalPlayers: engine.players.count,
            results: finalResults,
            heroRank: heroRank
        )
        GameHistoryManager.shared.saveRecord(record)
        
        // 启动 AI 后台模拟（统计所有玩家数据）
        startBackgroundAISimulation()
    }
    
    // MARK: - AI Background Simulation
    
    /// 为 AI 玩家启动后台模拟任务，加快数据收集速度
    private func startBackgroundAISimulation() {
        guard !isBackgroundSimulating else { return }
        isBackgroundSimulating = true
        
        #if DEBUG
        print("🚀 开始 AI 后台模拟...")
        #endif
        
        // 在后台队列执行模拟
        let simulationQueue = DispatchQueue(label: "com.poker.ai.simulation", qos: .userInitiated)
        
        simulationQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 获取当前所有玩家名称（用于统计）
            let playerNames = self.engine.players.map { $0.name }
            let gameMode = self.engine.gameMode
            
            // 执行多批模拟
            for batch in 0..<self.backgroundBatches {
                self.runBatchSimulation(batch: batch + 1, totalBatches: self.backgroundBatches)
            }
            
            // 模拟完成后更新统计数据
            DispatchQueue.main.async {
                self.updateAllPlayerStats(playerNames: playerNames, gameMode: gameMode)
                self.isBackgroundSimulating = false
                
                #if DEBUG
                print("✅ AI 后台模拟完成！")
                #endif
            }
        }
    }
    
    /// 执行一批后台模拟
    private func runBatchSimulation(batch: Int, totalBatches: Int) {
        // 为每批模拟创建独立的引擎实例，避免状态冲突
        let simEngine = PokerEngine(mode: engine.gameMode, config: engine.tournamentConfig, difficulty: gameDifficulty, playerCount: gamePlayerCount)
        
        // 使用同步方式快速完成多手牌
        for _ in 0..<backgroundHandsPerBatch {
            // 检查是否还有足够玩家继续
            let activePlayers = simEngine.players.filter { $0.chips > 0 }
            if activePlayers.count < 2 {
                break
            }
            
            // 快速模拟一手牌（不播放动画）
            self.quickSimulateHand(engine: simEngine)
        }
        
        #if DEBUG
        print("📊 Batch \(batch)/\(totalBatches) 完成，已模拟 \(backgroundHandsPerBatch) 手牌")
        #endif
    }
    
    /// 快速模拟一手牌（无动画，无延迟）
    private func quickSimulateHand(engine: PokerEngine) {
        // 启动手牌
        engine.startHand()
        
        // 快速进行到底（不使用延迟）
        while !engine.isHandOver && engine.activePlayerIndex >= 0 && engine.activePlayerIndex < engine.players.count {
            let player = engine.players[engine.activePlayerIndex]
            
            // AI 玩家快速决策（0 延迟）
            if !player.isHuman && player.status == .active {
                let action = DecisionEngine.makeDecision(player: player, engine: engine)
                engine.processAction(action)
            } else if player.isHuman && player.status == .active {
                // 人类玩家跳过（不参与后台模拟）
                // 直接推进到下一个活跃玩家
                let nextIdx = engine.nextActivePlayerIndex(after: engine.activePlayerIndex)
                if nextIdx >= 0 {
                    engine.activePlayerIndex = nextIdx
                }
            } else {
                // 非活跃玩家，跳过
                let nextIdx = engine.nextActivePlayerIndex(after: engine.activePlayerIndex)
                if nextIdx >= 0 {
                    engine.activePlayerIndex = nextIdx
                }
            }
        }
    }
    
    /// 更新所有玩家（人类 + AI）的统计数据
    private func updateAllPlayerStats(playerNames: [String], gameMode: GameMode) {
        // 为所有玩家重新计算统计数据
        StatisticsCalculator.shared.recomputeAndPersistStats(
            playerNames: playerNames,
            gameMode: gameMode
        )
    }
    
    // MARK: - Spectating Mode
    
    private func startSpectating() {
        state = .spectating
        isSpectating = true
        spectatePaused = false
        spectateHandCount = 0
        lastSpectateWinner = ""
        lastSpectateWinAmount = 0
        spectateLoop()
    }
    
    private func pauseSpectating() {
        spectatePaused = true
        spectateLoopTask?.cancel()
        spectateLoopTask = nil
    }
    
    private func resumeSpectating() {
        spectatePaused = false
        spectateLoop()
    }
    
    private func stopSpectating() {
        isSpectating = false
        spectatePaused = false
        spectateLoopTask?.cancel()
        spectateLoopTask = nil

        // 根据人类玩家是否有筹码决定返回状态
        if let hero = engine.players.first(where: { $0.isHuman }),
           hero.chips > 0 {
            // 玩家还有筹码，返回 showdown 继续游戏
            state = .showdown
        } else {
            // 玩家已淘汰，返回 idle 回到主界面
            state = .idle
        }
    }
    
    private func spectateLoop() {
        guard isSpectating && !spectatePaused else { return }
        
        // 检查结束条件
        if remainingPlayerCount <= 1 {
            stopSpectating()
            finishGame()
            return
        }
        
        // 在主引擎上快速模拟一手
        quickSimulateOnMainEngine()
        spectateHandCount += 1
        
        // 按速度延迟后继续
        let work = DispatchWorkItem { [weak self] in
            self?.spectateLoop()
        }
        spectateLoopTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + spectateSpeed.rawValue, execute: work)
    }
    
    /// 在主引擎上快速模拟一手（无动画，人类自动弃牌）
    private func quickSimulateOnMainEngine() {
        engine.startHand()
        
        var safetyCounter = 0
        let maxIterations = 200 // 防止无限循环
        
        while !engine.isHandOver && safetyCounter < maxIterations {
            safetyCounter += 1
            
            let idx = engine.activePlayerIndex
            guard idx >= 0 && idx < engine.players.count else { break }
            let player = engine.players[idx]
            
            if player.status == .active {
                if player.isHuman {
                    // 人类自动弃牌
                    engine.processAction(.fold)
                } else {
                    let action = DecisionEngine.makeDecision(player: player, engine: engine)
                    engine.processAction(action)
                }
            } else {
                let nextIdx = engine.nextActivePlayerIndex(after: idx)
                if nextIdx >= 0 {
                    engine.activePlayerIndex = nextIdx
                }
            }
        }
        
        // 记录最近胜者
        if let winnerId = engine.winners.first,
           let winner = engine.players.first(where: { $0.id == winnerId }) {
            lastSpectateWinner = winner.name
            lastSpectateWinAmount = engine.pot.total
        }
    }
    
    // MARK: - Cash Game Methods
    
    func leaveTable() {
        guard engine.gameMode == .cashGame else { return }
        guard let heroIndex = engine.players.firstIndex(where: { $0.isHuman }) else { return }
        
        // 结算 Session
        if var session = currentSession {
            session.endTime = Date()
            session.finalChips = engine.players[heroIndex].chips
            session.handsPlayed = engine.handNumber
            currentSession = session
            saveCashSession(session)
        }
        
        // 标记玩家离开
        engine.players[heroIndex].status = .eliminated
        isLeavingAfterHand = false
        showCashSessionSummary = true
        state = .idle
    }
    
    func startCashSession(buyIn: Int, maxBuyIns: Int = 0) {
        currentSession = CashGameSession(buyIn: buyIn, maxBuyIns: maxBuyIns)
        showBuyIn = false
    }
    
    func recordAIPurchase() {
        guard var session = currentSession else { return }
        session.recordAIPurchase()
        currentSession = session
    }
    
    /// 记录这手牌开始时 hero 的 chips，用于正确计算盈利
    private func recordHeroChipsAtHandStart() {
        guard let hero = engine.players.first(where: { $0.isHuman }) else { return }
        heroChipsAtHandStart = hero.chips
        #if DEBUG
        print("📊 recordHeroChipsAtHandStart: hero.chips=\(hero.chips), handNumber=\(engine.handNumber)")
        #endif
    }
    
    /// 重置 hero 的 chips 记录点，用于 rebuy 后正确计算盈利
    func resetHeroChipsAtHandStart() {
        guard let hero = engine.players.first(where: { $0.isHuman }) else { return }
        heroChipsAtHandStart = hero.chips
        #if DEBUG
        print("📊 resetHeroChipsAtHandStart: hero.chips=\(hero.chips) (after rebuy)")
        #endif
    }
    
    func recordHandProfit() {
        #if DEBUG
        print("📊 recordHandProfit: 开始, gameMode=\(engine.gameMode)")
        #endif
        guard engine.gameMode == .cashGame else { 
            #if DEBUG
            print("📊 recordHandProfit: guard failed - not cashGame")
            #endif
            return 
        }
        guard let hero = engine.players.first(where: { $0.isHuman }) else { 
            #if DEBUG
            print("📊 recordHandProfit: guard failed - no hero")
            print("📊 recordHandProfit: 所有玩家 = \(engine.players.map { "\($0.name)(\($0.isHuman))" })")
            #endif
            return 
        }
        guard var session = currentSession else { 
            #if DEBUG
            print("📊 recordHandProfit: guard failed - no session")
            #endif
            return 
        }
        
        // 正确计算盈利：这手牌结束后的 chips 减去这手牌开始时的 chips
        // 这样无论是赢是输，计算都是正确的
        // 盈利 = showdown 后 chips - heroChipsAtHandStart
        let profit = hero.chips - heroChipsAtHandStart
        
        // 判断是否获胜
        let heroWon = engine.winners.contains(hero.id) || profit > 0
        
        #if DEBUG
        print("📊 recordHandProfit: hero.chips=\(hero.chips), heroChipsAtHandStart=\(heroChipsAtHandStart), profit=\(profit), handNumber=\(engine.handNumber)")
        #endif
        
        session.handProfits.append(profit)
        session.handsPlayed = engine.handNumber
        if heroWon {
            session.handsWon += 1
        }
        currentSession = session
        
        // 记录AI玩家输赢，用于资金管理
        recordAIHandResults(players: engine.players, startingChips: engine.players.reduce(into: [String: Int]()) { dict, player in
            dict[player.id.uuidString] = player.startingChips
        }, bankrollManager: engine.bankrollManager)
        
        checkCashGameEndConditions()
    }
    
    /// 检查现金局结束条件：玩家淘汰或手数达到限制
    private func checkCashGameEndConditions() {
        guard engine.gameMode == .cashGame else { return }
        guard var session = currentSession else { return }
        
        // 检查人类玩家是否被淘汰
        if let heroIndex = engine.players.firstIndex(where: { $0.isHuman }),
           engine.players[heroIndex].chips <= 0 {
            #if DEBUG
            print("💰 Hero被淘汰，检查是否可以rebuy")
            #endif
            
            // 检查是否达到买入限制
            if session.isBuyInLimitReached {
                #if DEBUG
                print("🎯 达到总买入限制 \(session.maxBuyIns)，无法rebuy，结束游戏")
                #endif
                // 标记玩家淘汰
                engine.players[heroIndex].status = .eliminated
                // 达到买入限制，结束游戏
                leaveTable()
                return
            }
            
            #if DEBUG
            print("💰 Hero被淘汰，显示rebuy界面")
            #endif
            // 标记玩家淘汰
            engine.players[heroIndex].status = .eliminated
            // 显示rebuy界面
            showBuyIn = true
            return
        }
        
        // 如果没有玩家被淘汰，检查是否达到买入限制（仅用于统计，不强制结束）
        if session.isBuyInLimitReached {
            #if DEBUG
            print("🎯 达到总买入限制 \(session.maxBuyIns)，游戏将继续直到所有玩家离开")
            #endif
        }
    }
    
    private func saveCashSession(_ session: CashGameSession) {
        var sessions = loadCashSessions()
        sessions.insert(session, at: 0)
        if sessions.count > 50 { sessions = Array(sessions.prefix(50)) }
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "cash_game_sessions")
        }
    }
    
    private func loadCashSessions() -> [CashGameSession] {
        guard let data = UserDefaults.standard.data(forKey: "cash_game_sessions"),
              let sessions = try? JSONDecoder().decode([CashGameSession].self, from: data) else {
            return []
        }
        return sessions
    }
    
    func resetGame(mode: GameMode = .cashGame, config: TournamentConfig? = nil) {
        // 取消所有异步任务
        dealCompleteTimer?.cancel()
        dealCompleteTimer = nil
        backgroundSimulationTask?.cancel()
        backgroundSimulationTask = nil
        spectateLoopTask?.cancel()
        spectateLoopTask = nil
        
        // 取消 poll 任务
        pollTasks.forEach { $0.cancel() }
        pollTasks.removeAll()
        
        // 取消 watchdog 任务
        watchdogTask?.cancel()
        watchdogTask = nil
        
        // 取消 handOverWatchdog 任务
        handOverWatchdogTask?.cancel()
        handOverWatchdogTask = nil
        
        // 取消 runOutBoard 任务
        runOutBoardTasks.forEach { $0.cancel() }
        runOutBoardTasks.removeAll()
        
        isGameOver = false
        isBackgroundSimulating = false
        isSpectating = false
        spectatePaused = false
        spectateHandCount = 0
        showRankings = false
        finalResults = []
        gameRecordSaved = false
        state = .idle
        
        // Reset cash game state - 先保存session数据
        if var session = currentSession, engine.gameMode == .cashGame {
            session.endTime = Date()
            if let heroIndex = engine.players.firstIndex(where: { $0.isHuman }) {
                session.finalChips = engine.players[heroIndex].chips
            }
            session.handsPlayed = engine.handNumber
            saveCashSession(session)
        }
        isLeavingAfterHand = false
        showBuyIn = (mode == .cashGame)
        showLeaveConfirm = false
        showCashSessionSummary = false
        currentSession = nil
        
        // 注销旧引擎并创建新引擎（使用之前保存的难度和玩家数量）
        DecisionEngine.unregisterEngine(engine)
        engine = PokerEngine(mode: mode, config: config, difficulty: gameDifficulty, playerCount: gamePlayerCount)
        // 注册新引擎
        DecisionEngine.registerEngine(engine)
        
        // Re-subscribe
        cancellables.removeAll()
        subscribeToEngine()
    }
}
