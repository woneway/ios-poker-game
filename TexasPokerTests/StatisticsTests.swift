import XCTest
import CoreData
@testable import TexasPoker

class StatisticsTests: XCTestCase {
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var calculator: StatisticsCalculator!
    var recorder: ActionRecorder!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory Core Data stack for testing
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        
        calculator = StatisticsCalculator.shared
        recorder = ActionRecorder.shared
    }
    
    override func tearDown() {
        // Clean up test data
        clearAllEntities()
        
        persistenceController = nil
        context = nil
        calculator = nil
        recorder = nil
        
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func clearAllEntities() {
        let entities = ["HandHistoryEntity", "ActionEntity", "PlayerStatsEntity"]
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try? context.execute(deleteRequest)
        }
        try? context.save()
    }
    
    private func createTestHand(handNumber: Int, gameMode: GameMode) -> UUID {
        let handId = UUID()
        // Note: ActionRecorder.startHand doesn't return handId, so we track it separately
        recorder.startHand(handNumber: handNumber, gameMode: gameMode, players: [])
        return handId
    }
    
    private func recordAction(handId: UUID, playerName: String, action: String, amount: Int = 0, street: String = "preFlop", isVoluntary: Bool = false) {
        // Convert string action to PlayerAction enum
        let playerAction: PlayerAction
        switch action.lowercased() {
        case "fold": playerAction = .fold
        case "call": playerAction = .call
        case "raise": playerAction = .raise(amount)
        case "allin": playerAction = .allIn
        default: playerAction = .fold
        }
        
        // Convert string street to Street enum
        let streetEnum: Street
        switch street.lowercased() {
        case "preflop": streetEnum = .preFlop
        case "flop": streetEnum = .flop
        case "turn": streetEnum = .turn
        case "river": streetEnum = .river
        default: streetEnum = .preFlop
        }
        
        recorder.recordAction(
            playerName: playerName,
            action: playerAction,
            amount: amount,
            street: streetEnum,
            isVoluntary: isVoluntary,
            position: "BTN"
        )
    }
    
    private func finishHand(handId: UUID, winnerNames: String, finalPot: Int) {
        let winners = winnerNames.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        recorder.endHand(
            finalPot: finalPot,
            communityCards: [],
            heroCards: [],
            winners: winners
        )
    }
    
    // MARK: - VPIP Tests
    
    func testVPIPCalculation() {
        // Setup: Player voluntarily puts money in 3 out of 5 hands
        let gameMode = GameMode.cashGame
        
        // Hand 1: Raise (voluntary)
        let hand1 = createTestHand(handNumber: 1, gameMode: gameMode)
        recordAction(handId: hand1, playerName: "Alice", action: "raise", amount: 20, street: "preFlop", isVoluntary: true)
        finishHand(handId: hand1, winnerNames: "Alice", finalPot: 100)
        
        // Hand 2: Fold (not voluntary)
        let hand2 = createTestHand(handNumber: 2, gameMode: gameMode)
        recordAction(handId: hand2, playerName: "Alice", action: "fold", street: "preFlop", isVoluntary: false)
        finishHand(handId: hand2, winnerNames: "Bob", finalPot: 50)
        
        // Hand 3: Call (voluntary)
        let hand3 = createTestHand(handNumber: 3, gameMode: gameMode)
        recordAction(handId: hand3, playerName: "Alice", action: "call", amount: 10, street: "preFlop", isVoluntary: true)
        finishHand(handId: hand3, winnerNames: "Bob", finalPot: 80)
        
        // Hand 4: Fold (not voluntary)
        let hand4 = createTestHand(handNumber: 4, gameMode: gameMode)
        recordAction(handId: hand4, playerName: "Alice", action: "fold", street: "preFlop", isVoluntary: false)
        finishHand(handId: hand4, winnerNames: "Charlie", finalPot: 60)
        
        // Hand 5: Raise (voluntary)
        let hand5 = createTestHand(handNumber: 5, gameMode: gameMode)
        recordAction(handId: hand5, playerName: "Alice", action: "raise", amount: 30, street: "preFlop", isVoluntary: true)
        finishHand(handId: hand5, winnerNames: "Alice", finalPot: 120)
        
        // Calculate stats
        let stats = calculator.calculateStats(playerName: "Alice", gameMode: gameMode)
        
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.totalHands, 5)
        XCTAssertEqual(stats?.vpip, 60.0, accuracy: 0.1) // 3/5 = 60%
    }
    
    // MARK: - PFR Tests
    
    func testPFRCalculation() {
        // Setup: Player raises preflop 2 out of 5 hands
        let gameMode = GameMode.cashGame
        
        // Hand 1: Raise
        let hand1 = createTestHand(handNumber: 1, gameMode: gameMode)
        recordAction(handId: hand1, playerName: "Bob", action: "raise", amount: 20, street: "preFlop")
        finishHand(handId: hand1, winnerNames: "Bob", finalPot: 100)
        
        // Hand 2: Call
        let hand2 = createTestHand(handNumber: 2, gameMode: gameMode)
        recordAction(handId: hand2, playerName: "Bob", action: "call", amount: 10, street: "preFlop")
        finishHand(handId: hand2, winnerNames: "Alice", finalPot: 80)
        
        // Hand 3: Fold
        let hand3 = createTestHand(handNumber: 3, gameMode: gameMode)
        recordAction(handId: hand3, playerName: "Bob", action: "fold", street: "preFlop")
        finishHand(handId: hand3, winnerNames: "Charlie", finalPot: 60)
        
        // Hand 4: All-in (counts as raise)
        let hand4 = createTestHand(handNumber: 4, gameMode: gameMode)
        recordAction(handId: hand4, playerName: "Bob", action: "allIn", amount: 100, street: "preFlop")
        finishHand(handId: hand4, winnerNames: "Bob", finalPot: 200)
        
        // Hand 5: Call
        let hand5 = createTestHand(handNumber: 5, gameMode: gameMode)
        recordAction(handId: hand5, playerName: "Bob", action: "call", amount: 10, street: "preFlop")
        finishHand(handId: hand5, winnerNames: "Alice", finalPot: 90)
        
        // Calculate stats
        let stats = calculator.calculateStats(playerName: "Bob", gameMode: gameMode)
        
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.totalHands, 5)
        XCTAssertEqual(stats?.pfr, 40.0, accuracy: 0.1) // 2/5 = 40%
    }
    
    // MARK: - AF Tests
    
    func testAggressionFactorCalculation() {
        // Setup: Player has 6 aggressive actions and 3 calls
        let gameMode = GameMode.cashGame
        let hand1 = createTestHand(handNumber: 1, gameMode: gameMode)
        
        // Aggressive actions
        recordAction(handId: hand1, playerName: "Charlie", action: "raise", amount: 20, street: "preFlop")
        recordAction(handId: hand1, playerName: "Charlie", action: "raise", amount: 40, street: "flop")
        recordAction(handId: hand1, playerName: "Charlie", action: "raise", amount: 80, street: "turn")
        
        let hand2 = createTestHand(handNumber: 2, gameMode: gameMode)
        recordAction(handId: hand2, playerName: "Charlie", action: "raise", amount: 30, street: "preFlop")
        recordAction(handId: hand2, playerName: "Charlie", action: "allIn", amount: 200, street: "river")
        
        let hand3 = createTestHand(handNumber: 3, gameMode: gameMode)
        recordAction(handId: hand3, playerName: "Charlie", action: "raise", amount: 25, street: "preFlop")
        
        // Passive actions (calls)
        let hand4 = createTestHand(handNumber: 4, gameMode: gameMode)
        recordAction(handId: hand4, playerName: "Charlie", action: "call", amount: 10, street: "preFlop")
        
        let hand5 = createTestHand(handNumber: 5, gameMode: gameMode)
        recordAction(handId: hand5, playerName: "Charlie", action: "call", amount: 20, street: "flop")
        recordAction(handId: hand5, playerName: "Charlie", action: "call", amount: 40, street: "turn")
        
        finishHand(handId: hand1, winnerNames: "Charlie", finalPot: 300)
        finishHand(handId: hand2, winnerNames: "Charlie", finalPot: 400)
        finishHand(handId: hand3, winnerNames: "Alice", finalPot: 100)
        finishHand(handId: hand4, winnerNames: "Bob", finalPot: 50)
        finishHand(handId: hand5, winnerNames: "Charlie", finalPot: 150)
        
        // Calculate stats
        let stats = calculator.calculateStats(playerName: "Charlie", gameMode: gameMode)
        
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.af, 2.0, accuracy: 0.1) // 6 aggressive / 3 calls = 2.0
    }
    
    // MARK: - WTSD Tests
    
    func testWTSDCalculation() {
        // Setup: Player sees flop 4 times, goes to showdown 2 times
        let gameMode = GameMode.cashGame
        
        // Hand 1: Sees flop, goes to showdown
        let hand1 = createTestHand(handNumber: 1, gameMode: gameMode)
        recordAction(handId: hand1, playerName: "Dave", action: "call", street: "preFlop")
        recordAction(handId: hand1, playerName: "Dave", action: "call", street: "flop")
        recordAction(handId: hand1, playerName: "Dave", action: "call", street: "turn")
        recordAction(handId: hand1, playerName: "Dave", action: "call", street: "river")
        finishHand(handId: hand1, winnerNames: "Dave", finalPot: 200)
        
        // Hand 2: Sees flop, folds on turn
        let hand2 = createTestHand(handNumber: 2, gameMode: gameMode)
        recordAction(handId: hand2, playerName: "Dave", action: "call", street: "preFlop")
        recordAction(handId: hand2, playerName: "Dave", action: "call", street: "flop")
        recordAction(handId: hand2, playerName: "Dave", action: "fold", street: "turn")
        finishHand(handId: hand2, winnerNames: "Alice", finalPot: 150)
        
        // Hand 3: Sees flop, goes to showdown
        let hand3 = createTestHand(handNumber: 3, gameMode: gameMode)
        recordAction(handId: hand3, playerName: "Dave", action: "call", street: "preFlop")
        recordAction(handId: hand3, playerName: "Dave", action: "call", street: "flop")
        recordAction(handId: hand3, playerName: "Dave", action: "call", street: "river")
        finishHand(handId: hand3, winnerNames: "Bob", finalPot: 180)
        
        // Hand 4: Sees flop, folds on flop
        let hand4 = createTestHand(handNumber: 4, gameMode: gameMode)
        recordAction(handId: hand4, playerName: "Dave", action: "call", street: "preFlop")
        recordAction(handId: hand4, playerName: "Dave", action: "fold", street: "flop")
        finishHand(handId: hand4, winnerNames: "Charlie", finalPot: 100)
        
        // Calculate stats
        let stats = calculator.calculateStats(playerName: "Dave", gameMode: gameMode)
        
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.wtsd, 50.0, accuracy: 0.1) // 2/4 = 50%
    }
    
    // MARK: - W$SD Tests
    
    func testWSDCalculation() {
        // Setup: Player goes to showdown 3 times, wins 2 times
        let gameMode = GameMode.cashGame
        
        // Hand 1: Showdown - Win
        let hand1 = createTestHand(handNumber: 1, gameMode: gameMode)
        recordAction(handId: hand1, playerName: "Eve", action: "call", street: "river")
        finishHand(handId: hand1, winnerNames: "Eve", finalPot: 200)
        
        // Hand 2: Showdown - Lose
        let hand2 = createTestHand(handNumber: 2, gameMode: gameMode)
        recordAction(handId: hand2, playerName: "Eve", action: "call", street: "river")
        finishHand(handId: hand2, winnerNames: "Alice", finalPot: 150)
        
        // Hand 3: Showdown - Win
        let hand3 = createTestHand(handNumber: 3, gameMode: gameMode)
        recordAction(handId: hand3, playerName: "Eve", action: "call", street: "river")
        finishHand(handId: hand3, winnerNames: "Eve", finalPot: 180)
        
        // Calculate stats
        let stats = calculator.calculateStats(playerName: "Eve", gameMode: gameMode)
        
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.wsd, 66.7, accuracy: 0.1) // 2/3 = 66.7%
    }
    
    // MARK: - Winnings Tests
    
    func testWinningsCalculation() {
        let gameMode = GameMode.cashGame
        
        // Hand 1: Win 200
        let hand1 = createTestHand(handNumber: 1, gameMode: gameMode)
        recordAction(handId: hand1, playerName: "Frank", action: "raise", street: "preFlop")
        finishHand(handId: hand1, winnerNames: "Frank", finalPot: 200)
        
        // Hand 2: Lose
        let hand2 = createTestHand(handNumber: 2, gameMode: gameMode)
        recordAction(handId: hand2, playerName: "Frank", action: "call", street: "preFlop")
        finishHand(handId: hand2, winnerNames: "Alice", finalPot: 150)
        
        // Hand 3: Win 300
        let hand3 = createTestHand(handNumber: 3, gameMode: gameMode)
        recordAction(handId: hand3, playerName: "Frank", action: "raise", street: "preFlop")
        finishHand(handId: hand3, winnerNames: "Frank", finalPot: 300)
        
        // Calculate stats
        let stats = calculator.calculateStats(playerName: "Frank", gameMode: gameMode)
        
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.handsWon, 2)
        XCTAssertEqual(stats?.totalWinnings, 500) // 200 + 300
    }
    
    // MARK: - Game Mode Filtering Tests
    
    func testGameModeFiltering() {
        // Create hands in different game modes
        let cashHand = createTestHand(handNumber: 1, gameMode: .cashGame)
        recordAction(handId: cashHand, playerName: "Grace", action: "raise", street: "preFlop")
        finishHand(handId: cashHand, winnerNames: "Grace", finalPot: 100)
        
        let tournamentHand = createTestHand(handNumber: 1, gameMode: .tournament)
        recordAction(handId: tournamentHand, playerName: "Grace", action: "raise", street: "preFlop")
        finishHand(handId: tournamentHand, winnerNames: "Grace", finalPot: 200)
        
        // Calculate stats for each mode
        let cashStats = calculator.calculateStats(playerName: "Grace", gameMode: .cashGame)
        let tournamentStats = calculator.calculateStats(playerName: "Grace", gameMode: .tournament)
        
        XCTAssertNotNil(cashStats)
        XCTAssertNotNil(tournamentStats)
        XCTAssertEqual(cashStats?.totalHands, 1)
        XCTAssertEqual(tournamentStats?.totalHands, 1)
        XCTAssertEqual(cashStats?.totalWinnings, 100)
        XCTAssertEqual(tournamentStats?.totalWinnings, 200)
    }
    
    // MARK: - Edge Cases
    
    func testNoDataReturnsNil() {
        let stats = calculator.calculateStats(playerName: "NonExistent", gameMode: .cashGame)
        XCTAssertNil(stats)
    }
    
    func testZeroDivisionHandling() {
        // Player with only folds (no calls for AF calculation)
        let gameMode = GameMode.cashGame
        let hand1 = createTestHand(handNumber: 1, gameMode: gameMode)
        recordAction(handId: hand1, playerName: "Henry", action: "fold", street: "preFlop")
        finishHand(handId: hand1, winnerNames: "Alice", finalPot: 50)
        
        let stats = calculator.calculateStats(playerName: "Henry", gameMode: gameMode)
        
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.af, 0.0) // No calls, so AF should be 0 (or number of bets)
    }
    
    // MARK: - Integration Tests
    
    func testUpdatePlayerStatsEntity() {
        let gameMode = GameMode.cashGame
        
        // Create some hands
        let hand1 = createTestHand(handNumber: 1, gameMode: gameMode)
        recordAction(handId: hand1, playerName: "Iris", action: "raise", amount: 20, street: "preFlop", isVoluntary: true)
        finishHand(handId: hand1, winnerNames: "Iris", finalPot: 100)
        
        // Calculate and update entity
        if let stats = calculator.calculateStats(playerName: "Iris", gameMode: gameMode) {
            calculator.updatePlayerStatsEntity(stats: stats)
        }
        
        // Fetch from Core Data
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PlayerStatsEntity")
        fetchRequest.predicate = NSPredicate(
            format: "playerName == %@ AND gameMode == %@",
            "Iris",
            gameMode.rawValue
        )
        
        let results = try? context.fetch(fetchRequest)
        
        XCTAssertNotNil(results)
        XCTAssertEqual(results?.count, 1)
        XCTAssertEqual(results?.first?.value(forKey: "totalHands") as? Int32, 1)
        XCTAssertEqual(results?.first?.value(forKey: "totalWinnings") as? Int32, 100)
    }
}
