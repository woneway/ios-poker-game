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
    
    init() {
        self.engine = PokerEngine()
        
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
            // If engine immediately set isHandOver (e.g. not enough players)
            if engine.isHandOver {
                state = .showdown
            } else {
                state = .betting
            }
            
        case (.betting, .handOver):
            state = .showdown
            // Check if game is over
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
            print("FSM: Invalid transition \(state) + \(event)")
            #endif
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
        engine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        engine.$isHandOver
            .removeDuplicates()
            .filter { $0 == true }
            .sink { [weak self] _ in
                self?.send(.handOver)
            }
            .store(in: &cancellables)
    }
}
