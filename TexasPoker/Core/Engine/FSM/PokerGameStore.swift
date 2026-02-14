import Foundation
import Combine

class PokerGameStore: ObservableObject {
    @Published private(set) var state: GameState = .idle
    @Published var engine: PokerEngine
    @Published var isGameOver: Bool = false
    @Published var finalResults: [PlayerResult] = []
    @Published var showRankings: Bool = false
    @Published var isBackgroundSimulating: Bool = false
    
    // MARK: - Spectating State
    @Published var isSpectating: Bool = false
    @Published var spectateSpeed: SpectateSpeed = .normal
    @Published var spectatePaused: Bool = false
    @Published var spectateHandCount: Int = 0
    @Published var lastSpectateWinner: String = ""
    @Published var lastSpectateWinAmount: Int = 0
    
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
    
    init(mode: GameMode = .cashGame, config: TournamentConfig? = nil) {
        self.engine = PokerEngine(mode: mode, config: config)
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
                self?.pollForHumanTurn()
                self?.scheduleAIWatchdog()
            }
            .store(in: &cancellables)
    }
    
    /// 轮询检查是否轮到人类玩家（解决 AI 在 dealing 期间已完成行动的竞态问题）
    private func pollForHumanTurn() {
        // 检查多次，覆盖 AI 延迟执行的时间窗口
        for delay in [0.1, 0.5, 1.0, 2.0, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
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
        }
    }
    
    /// 监控 AI 是否卡住，如果卡住则强制触发
    private func scheduleAIWatchdog() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.state == .betting else { return }
            
            // 如果依然是 AI 回合（非人类回合），尝试踢一下引擎
            if !self.isHumanTurn {
                #if DEBUG
                print("⚠️ AI Watchdog: Kicking engine to check bot turn. ActiveIdx=\(self.engine.activePlayerIndex)")
                #endif
                self.engine.checkBotTurn()
                
                // 递归调度，直到状态改变
                self.scheduleAIWatchdog()
            } else {
                // It IS human turn, but state is still betting? Force switch.
                print("⚠️ AI Watchdog: It IS human turn but state is .betting. Forcing switch.")
                self.state = .waitingForAction
            }
        }
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
            
        case (.waitingForAction, .handOver):
            // 人类操作导致一手结束
            state = .showdown
            if remainingPlayerCount <= 1 {
                finishGame()
            }
            
        case (.showdown, .nextHand), (.showdown, .start):
            guard remainingPlayerCount >= 2 else {
                finishGame()
                return
            }
            state = .dealing
            engine.startHand()
            scheduleDealCompleteTimer()
            
        // MARK: - Spectating Transitions
        case (.showdown, .startSpectating), (.idle, .startSpectating):
            startSpectating()
            
        case (.spectating, .pauseSpectating):
            pauseSpectating()
            
        case (.spectating, .resumeSpectating):
            resumeSpectating()
            
        case (.spectating, .stopSpectating):
            stopSpectating()
            
        default:
            #if DEBUG
            print("FSM: Invalid transition \(state) + \(event) — recovering to safe state")
            #endif
            // Error recovery: try to recover based on engine state
            if engine.isHandOver && state != .showdown {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
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
        let simEngine = PokerEngine(mode: engine.gameMode, config: engine.tournamentConfig)
        
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
                engine.activePlayerIndex = engine.nextActivePlayerIndex(after: engine.activePlayerIndex)
            } else {
                // 非活跃玩家，跳过
                engine.activePlayerIndex = engine.nextActivePlayerIndex(after: engine.activePlayerIndex)
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
        state = .idle
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
                engine.activePlayerIndex = engine.nextActivePlayerIndex(after: idx)
            }
        }
        
        // 记录最近胜者
        if let winnerId = engine.winners.first,
           let winner = engine.players.first(where: { $0.id == winnerId }) {
            lastSpectateWinner = winner.name
            lastSpectateWinAmount = engine.pot.total
        }
    }
    
    func resetGame(mode: GameMode = .cashGame, config: TournamentConfig? = nil) {
        dealCompleteTimer?.cancel()
        dealCompleteTimer = nil
        backgroundSimulationTask?.cancel()
        backgroundSimulationTask = nil
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
        engine = PokerEngine(mode: mode, config: config)
        
        // Re-subscribe
        cancellables.removeAll()
        subscribeToEngine()
    }
}
