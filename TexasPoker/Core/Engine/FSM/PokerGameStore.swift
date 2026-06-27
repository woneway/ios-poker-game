import Foundation
import Combine

@MainActor
class PokerGameStore: ObservableObject {
    private let logger = AppLogger.shared

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

    // MARK: - 异步任务追踪（统一使用 Task）
    private var dealCompleteTask: Task<Void, Never>?
    private var spectateLoopTask: Task<Void, Never>?
    // 后台模拟任务引用，用于正确取消
    private var backgroundSimTask: Task<Void, Never>?

    // 竞态条件保护：使用简单标志位
    // 注意：由于 PokerGameStore 是 @MainActor，所有属性访问都在主线程上执行
    // 不需要使用 NSLock，Combine 的 receive(on: DispatchQueue.main) 确保主线程调度
    private var isProcessingHandOver: Bool = false

    /// Number of background hands to simulate per batch (optimized for better performance)
    private var backgroundHandsPerBatch: Int { GameConstants.Simulation.backgroundHandsPerBatch }
    /// Number of batches to simulate (optimized for better performance)
    private var backgroundBatches: Int { GameConstants.Simulation.backgroundBatches }
    
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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // 检查 isHandOver 是否在订阅前就已经是 true
        // 如果是，立即触发 handOver 事件
        if engine.isHandOver && state != .showdown {
            #if DEBUG
            logger.warning("Engine isHandOver is already true at subscription time!", category: .game)
            #endif
            // Since PokerGameStore is @MainActor, we can directly call send without DispatchQueue
            self.send(.handOver)
        }

        // Listen for hand-over - 核心状态同步机制
        // 当 engine 标记手牌结束时，自动触发状态机转换
        // 使用 isProcessingHandOver 标志防止竞态条件导致的重复触发
        // 确保所有状态更新都在主线程上执行
        engine.$isHandOver
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .filter { [weak self] _ in
                guard let self = self else { return false }
                // 只在非 showdown 状态时触发，且不在处理中
                // 注意: 由于 PokerGameStore 是 @MainActor，这里在主线程执行，访问 isProcessingHandOver 是安全的
                return self.state != .showdown && !self.isProcessingHandOver
            }
            .sink { [weak self] isHandOver in
                guard let self = self, isHandOver else { return }
                self.isProcessingHandOver = true
                self.send(.handOver)
                // 注意: isProcessingHandOver 会在 handleHandOver 中被重置
                // 这里不再需要 async 重置，避免竞态条件
            }
            .store(in: &cancellables)

        // 监听 activePlayerIndex 变化 - 检测人类玩家回合
        // 当活跃玩家变为人类玩家时，切换到 waitingForAction 状态
        // 确保在主线程上执行
        engine.$activePlayerIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.state == .betting && self.isHumanTurn {
                    self.state = .waitingForAction
                }
            }
            .store(in: &cancellables)

        // 状态变化监听 - 简化为单一入口点
        // 替换多个 watchdog 为一个可靠的 Combine 管道
        // 由于 $state 是 @Published，在 @MainActor 类中自动在主线程上发布
        $state
            .sink { [weak self] newState in
                self?.handleStateChange(newState)
            }
            .store(in: &cancellables)
    }

    /// 统一处理状态变化 - 替代多个 watchdog
    private func handleStateChange(_ newState: GameState) {
        switch newState {
        case .betting:
            // 进入 betting 状态时，检查是否需要等待人类玩家
            if isHumanTurn {
                state = .waitingForAction
            }
            // 验证游戏状态一致性，防止卡住
            if !validateGameStateConsistency() && !isProcessingHandOver {
                #if DEBUG
                logger.warning("handleStateChange: 检测到状态不一致，触发 handOver", category: .game)
                #endif
                isProcessingHandOver = true
                send(.handOver)
                return
            }
            // AI 会通过引擎自动处理，不需要额外的轮询

        case .waitingForAction:
            // 人类玩家正在思考，确保 watchdoc 激活
            break

        case .showdown:
            // 清理所有异步任务
            cancelAllAsyncTasks()

        default:
            break
        }
    }

    /// 取消所有异步任务 - 统一的清理入口
    private func cancelAllAsyncTasks() {
        dealCompleteTask?.cancel()
        dealCompleteTask = nil
        backgroundSimTask?.cancel()
        backgroundSimTask = nil
    }

    /// 验证游戏状态一致性 - 用于检测潜在的死锁或卡住情况
    /// 在关键状态转换时调用，确保游戏可以继续进行
    private func validateGameStateConsistency() -> Bool {
        // 检查是否有活跃玩家
        let activePlayers = engine.players.filter { $0.status == .active || $0.status == .allIn }
        if activePlayers.isEmpty {
            #if DEBUG
            logger.warning("validateGameStateConsistency: 没有活跃玩家，触发手牌结束", category: .game)
            #endif
            return false
        }

        // 检查当前玩家索引是否有效
        if engine.activePlayerIndex < 0 || engine.activePlayerIndex >= engine.players.count {
            #if DEBUG
            logger.warning("validateGameStateConsistency: 玩家索引无效 \(engine.activePlayerIndex)，触发手牌结束", category: .game)
            #endif
            return false
        }

        // 如果在 betting 状态但没有任何玩家可以行动，结束手牌
        let currentPlayer = engine.players[engine.activePlayerIndex]
        if state == .betting && currentPlayer.status == .folded {
            #if DEBUG
            logger.warning("validateGameStateConsistency: 当前玩家已 fold，触发 advanceTurn", category: .game)
            #endif
            return false
        }

        return true
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
        logger.debug("FSM: Event=\(event), State=\(state)", category: .game)
        #endif
        
        switch (state, event) {
        case (.idle, .start):
            guard remainingPlayerCount >= 2 else {
                finishGame()
                return
            }
            // 记录这手牌开始时 hero 的 chips
            #if DEBUG
            logger.debug(".idle -> .start: 调用 recordHeroChipsAtHandStart, handNumber=\(engine.handNumber)", category: .game)
            #endif
            self.recordHeroChipsAtHandStart()
            state = .dealing
            engine.startHand()
            scheduleDealCompleteTimer()
            
        case (.dealing, .dealComplete):
            dealCompleteTask?.cancel()
            dealCompleteTask = nil
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
            
        case (.betting, .handOver), (.waitingForAction, .handOver):
            // 统一处理手牌结束逻辑
            handleHandOver(fromState: state)
            
        case (.showdown, .nextHand), (.showdown, .start):
            guard remainingPlayerCount >= 2 else {
                finishGame()
                return
            }
            // 现金局：如果hero被淘汰需要rebuy，阻止继续游戏
            if engine.gameMode == .cashGame && showBuyIn {
                #if DEBUG
                logger.info("现金局：hero需要rebuy，暂停游戏", category: .game)
                #endif
                return
            }
            #if DEBUG
            logger.debug(".showdown -> .nextHand: 调用 recordHeroChipsAtHandStart, handNumber before startHand=\(engine.handNumber)", category: .game)
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
            handleLeaveTableDuringGame()

        // 玩家在发牌阶段离开
        case (.dealing, .leaveTable):
            handleLeaveTableDuringDealing()

        // 无效转换 - 尝试自动恢复
        default:
            #if DEBUG
            logger.error("FSM: Invalid transition \(state) + \(event) — recovering to safe state", category: .game)
            #endif
            attemptStateRecovery()
        }
    }

    // MARK: - Cash Game Leave Helpers

    /// 处理游戏中离开（waitingForAction/betting 状态）
    private func handleLeaveTableDuringGame() {
        guard engine.gameMode == .cashGame else { return }
        isLeavingAfterHand = true
        // 自动帮玩家弃牌
        if engine.players.contains(where: { $0.isHuman }) {
            engine.processAction(.fold)
        }
        showLeaveConfirm = false
    }

    /// 处理发牌阶段离开
    private func handleLeaveTableDuringDealing() {
        guard engine.gameMode == .cashGame else { return }
        isLeavingAfterHand = true
        showLeaveConfirm = false
    }

    /// 统一处理手牌结束逻辑 - 提取公共方法减少重复
    private func handleHandOver(fromState: GameState) {
        // 重置竞态标志
        isProcessingHandOver = false
        state = .showdown
        if remainingPlayerCount <= 1 {
            finishGame()
        }
        // 现金局：记录每手盈利
        #if DEBUG
        logger.debug(".\(fromState) -> .handOver: 调用 recordHandProfit, handNumber=\(engine.handNumber)", category: .game)
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
    }

    /// 状态机错误恢复逻辑 - 拆分为独立方法提高可读性
    private func attemptStateRecovery() {
        // 优先处理：引擎已结束手牌时强制转换到 showdown
        if shouldTransitionToShowdown() {
            state = .showdown
            return
        }

        // 检查是否有活跃玩家，无活跃玩家时处理
        if !hasActivePlayers() && state != .showdown && state != .idle {
            return
        }

        // 检查 activePlayerIndex 有效性
        if !isActivePlayerIndexValid() && engine.isHandOver {
            state = .showdown
        }
    }

    /// 检查是否应该转换到 showdown 状态
    private func shouldTransitionToShowdown() -> Bool {
        return engine.isHandOver && state != .showdown
    }

    /// 检查是否有活跃玩家
    private func hasActivePlayers() -> Bool {
        return engine.players.contains { $0.status == .active || $0.status == .allIn }
    }

    /// 检查 activePlayerIndex 是否有效
    private func isActivePlayerIndexValid() -> Bool {
        return engine.activePlayerIndex >= 0 && engine.activePlayerIndex < engine.players.count
    }
    
    /// 调度可取消的 dealComplete 兜底 timer（使用 Task 统一异步模式）
    private func scheduleDealCompleteTimer() {
        dealCompleteTask?.cancel()
        dealCompleteTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameConstants.Delays.tiltWarning * 1_000_000_000))
            guard let self = self, !Task.isCancelled, self.state == .dealing else { return }
            self.send(.dealComplete)
        }
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

        // 只有在有足够玩家时才运行后台模拟
        guard remainingPlayerCount >= 2 else {
            #if DEBUG
            logger.info("玩家数量不足，跳过后台模拟", category: .game)
            #endif
            return
        }

        isBackgroundSimulating = true

        #if DEBUG
        logger.info("开始 AI 后台模拟...", category: .game)
        #endif

        // 使用 Task 替代 DispatchQueue，避免 @MainActor 桥接问题
        // 保存任务引用以便正确取消
        backgroundSimTask = Task {
            await runBackgroundSimulation()
        }
    }

    /// 后台模拟主逻辑（在 Task 中运行）
    /// 注意：由于 PokerGameStore 是 @MainActor 类，这里可以直接访问 engine
    private func runBackgroundSimulation() async {
        // 获取当前所有玩家名称（用于统计）
        let playerNames = engine.players.map { $0.name }
        let gameMode = engine.gameMode
        let config = engine.tournamentConfig

        // 执行多批模拟
        for batch in 0..<backgroundBatches {
            // 检查任务是否被取消
            if Task.isCancelled { break }
            await runBatchSimulation(
                batch: batch + 1,
                totalBatches: backgroundBatches,
                gameMode: gameMode,
                config: config
            )
        }

        // 模拟完成后更新统计数据
        updateAllPlayerStats(playerNames: playerNames, gameMode: gameMode)
        isBackgroundSimulating = false
    }

    /// 执行一批后台模拟
    private func runBatchSimulation(batch: Int, totalBatches: Int, gameMode: GameMode, config: TournamentConfig?) async {
        // 由于 PokerGameStore 是 @MainActor，可以直接创建 PokerEngine 实例
        let simEngine = PokerEngine(
            mode: gameMode,
            config: config,
            difficulty: self.gameDifficulty,
            playerCount: self.gamePlayerCount
        )

        // 使用同步方式快速完成多手牌
        for _ in 0..<backgroundHandsPerBatch {
            // 检查是否还有足够玩家继续
            let activePlayers = simEngine.players.filter { $0.chips > 0 }
            if activePlayers.count < 2 {
                break
            }

            // 快速模拟一手牌（不播放动画）
            quickSimulateHand(engine: simEngine)
        }

        // 修复资源泄漏：模拟完成后正确销毁引擎
        simEngine.destroy()

        #if DEBUG
        logger.info("Batch \(batch)/\(totalBatches) 完成，已模拟 \(backgroundHandsPerBatch) 手牌", category: .game)
        #endif
    }

    /// 快速模拟一手牌（无动画，无延迟）
    /// 注意：由于 PokerGameStore 是 @MainActor，engine 方法可以直接调用
    private func quickSimulateHand(engine: PokerEngine) {
        // 启动手牌
        engine.startHand()

        // 快速进行到底（不使用延迟）
        while !engine.isHandOver && engine.activePlayerIndex >= 0 && engine.activePlayerIndex < engine.players.count {
            let player = engine.players[engine.activePlayerIndex]

            // AI 玩家快速决策（0 延迟）- 使用注入的决策引擎
            if !player.isHuman && player.status == .active {
                let action = engine.decisionEngine.makeDecision(player: player, engine: engine)
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

        // 按速度延迟后继续（使用 Task 统一异步模式）
        spectateLoopTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.spectateSpeed.rawValue * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.spectateLoop()
        }
    }
    
    /// 在主引擎上快速模拟一手（无动画，人类自动弃牌）
    private func quickSimulateOnMainEngine() {
        engine.startHand()

        var safetyCounter = 0
        let maxIterations = GameConstants.Simulation.maxSimulationIterations

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
                    // 使用注入的决策引擎
                    let action = engine.decisionEngine.makeDecision(player: player, engine: engine)
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
        logger.debug("recordHeroChipsAtHandStart: hero.chips=\(hero.chips), handNumber=\(engine.handNumber)", category: .game)
        #endif
    }
    
    /// 重置 hero 的 chips 记录点，用于 rebuy 后正确计算盈利
    func resetHeroChipsAtHandStart() {
        guard let hero = engine.players.first(where: { $0.isHuman }) else { return }
        heroChipsAtHandStart = hero.chips
        #if DEBUG
        logger.debug("resetHeroChipsAtHandStart: hero.chips=\(hero.chips) (after rebuy)", category: .game)
        #endif
    }
    
    func recordHandProfit() {
        #if DEBUG
        logger.debug("recordHandProfit: 开始, gameMode=\(engine.gameMode)", category: .game)
        #endif
        guard engine.gameMode == .cashGame else { 
            #if DEBUG
            logger.debug("recordHandProfit: guard failed - not cashGame", category: .game)
            #endif
            return 
        }
        guard let hero = engine.players.first(where: { $0.isHuman }) else { 
            #if DEBUG
            logger.debug("recordHandProfit: guard failed - no hero", category: .game)
            logger.debug("recordHandProfit: 所有玩家 = \(engine.players.map { "\($0.name)(\($0.isHuman))" })", category: .game)
            #endif
            return 
        }
        guard var session = currentSession else { 
            #if DEBUG
            logger.debug("recordHandProfit: guard failed - no session", category: .game)
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
        logger.debug("recordHandProfit: hero.chips=\(hero.chips), heroChipsAtHandStart=\(heroChipsAtHandStart), profit=\(profit), handNumber=\(engine.handNumber)", category: .game)
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
            logger.info("Hero被淘汰，检查是否可以rebuy", category: .game)
            #endif
            
            // 检查是否达到买入限制
            if session.isBuyInLimitReached {
                #if DEBUG
                logger.info("达到总买入限制 \(session.maxBuyIns)，无法rebuy，结束游戏", category: .game)
                #endif
                // 标记玩家淘汰
                engine.players[heroIndex].status = .eliminated
                // 达到买入限制，结束游戏
                leaveTable()
                return
            }
            
            #if DEBUG
            logger.info("Hero被淘汰，显示rebuy界面", category: .game)
            #endif
            // 标记玩家淘汰
            engine.players[heroIndex].status = .eliminated
            // 显示rebuy界面
            showBuyIn = true
            return
        }
        
        // 如果没有玩家被淘汰，检查是否达到买入限制（仅用于统计，不强制结束）
        if session.isBuyInLimitReached {
            logger.info("达到总买入限制 \(session.maxBuyIns)，游戏将继续直到所有玩家离开", category: .game)
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
        dealCompleteTask?.cancel()
        dealCompleteTask = nil
        // 取消后台模拟 Task
        backgroundSimTask?.cancel()
        backgroundSimTask = nil
        spectateLoopTask?.cancel()
        spectateLoopTask = nil

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

        // 安全销毁旧引擎 - 取消所有异步任务并注销
        engine.destroy()

        // 创建新引擎（使用之前保存的难度和玩家数量）
        engine = PokerEngine(mode: mode, config: config, difficulty: gameDifficulty, playerCount: gamePlayerCount)
        // 注册新引擎
        DecisionEngine.registerEngine(engine)

        // Re-subscribe
        cancellables.removeAll()
        subscribeToEngine()
    }

    // MARK: - Deinit

    /// 清理所有异步任务，防止内存泄漏
    /// 注意：由于 Swift 6 并发规则，deinit 必须在非隔离上下文中运行
    /// 因此这里只做安全的清理操作，复杂的异步清理通过 Task 完成
    deinit {
        // 取消所有 Task（Task 是 Sendable，可以在 deinit 中安全取消）
        backgroundSimTask?.cancel()
        spectateLoopTask?.cancel()
        dealCompleteTask?.cancel()

        // 注意：引擎销毁通过 DecisionEngine.unregisterEngine 处理
        // 由于 engine 是 @MainActor，不能在 deinit 中直接访问
        // 引擎会在 PokerGameStore 被释放时自动清理
    }
}
