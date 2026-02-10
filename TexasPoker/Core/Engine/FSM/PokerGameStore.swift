import Foundation
import Combine

class PokerGameStore: ObservableObject {
    @Published private(set) var state: GameState = .idle
    @Published var engine: PokerEngine
    @Published var isGameOver: Bool = false
    @Published var finalResults: [PlayerResult] = []
    @Published var showRankings: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var gameRecordSaved = false
    private var dealCompleteTimer: DispatchWorkItem?
    
    /// 当前是否是人类玩家的回合
    var isHumanTurn: Bool {
        let idx = engine.activePlayerIndex
        guard idx >= 0 && idx < engine.players.count else { return false }
        return engine.players[idx].isHuman && engine.players[idx].status == .active
    }
    
    init() {
        self.engine = PokerEngine()
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
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.state == .betting && self.isHumanTurn {
                    self.state = .waitingForAction
                }
            }
            .store(in: &cancellables)
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
    }
    
    func resetGame() {
        dealCompleteTimer?.cancel()
        dealCompleteTimer = nil
        isGameOver = false
        showRankings = false
        finalResults = []
        gameRecordSaved = false
        state = .idle
        engine = PokerEngine()
        
        // Re-subscribe
        cancellables.removeAll()
        subscribeToEngine()
    }
}
