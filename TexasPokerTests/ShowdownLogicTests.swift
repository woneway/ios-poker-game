import XCTest
@testable import TexasPoker

class ShowdownLogicTests: XCTestCase {
    
    var engine: PokerEngine!
    
    override func setUp() {
        super.setUp()
        engine = PokerEngine()
    }
    
    // MARK: - Test 1: All opponents fold → single winner gets entire pot
    
    func testSingleWinnerAllFold() {
        engine.players = [
            Player(name: "P1", chips: 1000, isHuman: true),
            Player(name: "P2", chips: 1000, isHuman: true),
            Player(name: "P3", chips: 1000, isHuman: true)
        ]
        engine.pot = Pot()
        engine.pot.add(150) // Simulated pot from prior betting
        engine.currentBet = 0
        
        // P2 folds
        engine.activePlayerIndex = 1
        engine.processAction(.fold)
        
        XCTAssertFalse(engine.isHandOver, "Hand should not end with 2 players remaining")
        
        // P3 folds → only P1 left
        engine.activePlayerIndex = 2
        engine.processAction(.fold)
        
        XCTAssertTrue(engine.isHandOver)
        XCTAssertTrue(engine.winners.contains(engine.players[0].id))
        XCTAssertEqual(engine.players[0].chips, 1150) // 1000 + 150 pot
    }
    
    // MARK: - Test 2: Showdown with known cards → best hand wins
    
    func testShowdownBestHandWins() {
        engine.players = [
            Player(name: "P1", chips: 500, isHuman: true),
            Player(name: "P2", chips: 500, isHuman: true)
        ]
        
        // P1: Ace-King → will make pair of aces
        engine.players[0].holeCards = [
            Card(rank: .ace, suit: .spades),
            Card(rank: .king, suit: .spades)
        ]
        // P2: Two-Seven → worst starting hand, no help from board
        engine.players[1].holeCards = [
            Card(rank: .two, suit: .clubs),
            Card(rank: .seven, suit: .diamonds)
        ]
        
        // Board gives P1 a pair of aces; P2 has high card only
        engine.communityCards = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .ten, suit: .diamonds),
            Card(rank: .five, suit: .clubs),
            Card(rank: .three, suit: .hearts),
            Card(rank: .nine, suit: .spades)
        ]
        engine.currentStreet = .river
        engine.pot = Pot()
        engine.currentBet = 0
        engine.minRaise = 20
        
        // Both go all-in to trigger showdown via endHand
        engine.activePlayerIndex = 0
        engine.processAction(.allIn)
        
        engine.activePlayerIndex = 1
        engine.processAction(.call)
        
        // endHand is triggered after river with 0 active players
        XCTAssertTrue(engine.isHandOver)
        XCTAssertTrue(engine.winners.contains(engine.players[0].id), "P1 (pair of aces) should win")
        XCTAssertEqual(engine.players[0].chips, 1000) // 0 + 1000 pot
        XCTAssertEqual(engine.players[1].chips, 0)
    }
    
    // MARK: - Test 3: Identical hands split the pot equally
    
    func testSplitPot() {
        engine.players = [
            Player(name: "P1", chips: 500, isHuman: true),
            Player(name: "P2", chips: 500, isHuman: true)
        ]
        
        // Both players have AK (different suits) → same effective hand
        engine.players[0].holeCards = [
            Card(rank: .ace, suit: .spades),
            Card(rank: .king, suit: .hearts)
        ]
        engine.players[1].holeCards = [
            Card(rank: .ace, suit: .diamonds),
            Card(rank: .king, suit: .clubs)
        ]
        
        // Board makes A-K-Q-J-10 straight for both (no flush possible)
        engine.communityCards = [
            Card(rank: .queen, suit: .hearts),
            Card(rank: .jack, suit: .diamonds),
            Card(rank: .ten, suit: .clubs),
            Card(rank: .five, suit: .spades),
            Card(rank: .two, suit: .hearts)
        ]
        engine.currentStreet = .river
        engine.pot = Pot()
        engine.currentBet = 0
        engine.minRaise = 20
        
        // Both go all-in
        engine.activePlayerIndex = 0
        engine.processAction(.allIn)
        
        engine.activePlayerIndex = 1
        engine.processAction(.call)
        
        XCTAssertTrue(engine.isHandOver)
        // Both should be winners (split pot)
        XCTAssertTrue(engine.winners.contains(engine.players[0].id))
        XCTAssertTrue(engine.winners.contains(engine.players[1].id))
        // Each gets half: 1000 / 2 = 500
        XCTAssertEqual(engine.players[0].chips, 500)
        XCTAssertEqual(engine.players[1].chips, 500)
    }
}
