import XCTest
@testable import TexasPoker

class BettingLogicTests: XCTestCase {
    
    var engine: PokerEngine!
    
    override func setUp() {
        super.setUp()
        engine = PokerEngine()
        engine.players = [
            Player(name: "P1", chips: 1000, isHuman: true),
            Player(name: "P2", chips: 1000, isHuman: true)
        ]
        // Status defaults to .active, but set explicitly for clarity
        for i in 0..<engine.players.count {
            engine.players[i].status = .active
        }
        engine.pot = Pot()
        engine.currentBet = 0
        engine.minRaise = 20
    }
    
    // MARK: - Test 1: Raise + Call completes the round
    
    func testRaiseCallRoundComplete() {
        // P1 raises to 50
        engine.activePlayerIndex = 0
        engine.processAction(.raise(50))
        
        XCTAssertEqual(engine.players[0].chips, 950)
        XCTAssertEqual(engine.players[0].currentBet, 50)
        XCTAssertEqual(engine.pot.total, 50)
        XCTAssertEqual(engine.currentBet, 50)
        
        // P2 calls 50
        engine.activePlayerIndex = 1
        engine.processAction(.call)
        
        XCTAssertEqual(engine.players[1].chips, 950)
        XCTAssertEqual(engine.pot.total, 100)
        
        // Round complete → dealNextStreet resets currentBet to 0
        XCTAssertEqual(engine.currentBet, 0)
    }
    
    // MARK: - Test 2: Check + Check completes the round
    
    func testCheckCheckRoundComplete() {
        // Both players check (valid since currentBet is 0)
        engine.activePlayerIndex = 0
        engine.processAction(.check)
        
        engine.activePlayerIndex = 1
        engine.processAction(.check)
        
        // Round complete → dealNextStreet advances to flop
        XCTAssertEqual(engine.currentStreet, .flop)
        XCTAssertEqual(engine.communityCards.count, 3)
        XCTAssertEqual(engine.currentBet, 0)
        // No money moved
        XCTAssertEqual(engine.players[0].chips, 1000)
        XCTAssertEqual(engine.players[1].chips, 1000)
        XCTAssertEqual(engine.pot.total, 0)
    }
    
    // MARK: - Test 3: Short stack goes all-in for less than the current bet
    
    func testShortStackAllIn() {
        engine.players[0].chips = 30 // P1 is short-stacked
        
        // P2 raises to 50
        engine.activePlayerIndex = 1
        engine.processAction(.raise(50))
        
        XCTAssertEqual(engine.currentBet, 50)
        XCTAssertEqual(engine.pot.total, 50)
        
        // P1 (30 chips) goes all-in for less than the current bet
        engine.activePlayerIndex = 0
        engine.processAction(.allIn)
        
        XCTAssertEqual(engine.players[0].chips, 0)
        XCTAssertEqual(engine.players[0].status, .allIn)
        XCTAssertEqual(engine.players[0].currentBet, 30) // Only had 30
        // Pot = 50 (P2 raise) + 30 (P1 all-in) = 80
        XCTAssertEqual(engine.pot.total, 80)
    }
    
    // MARK: Test 4: Blind posting causes all-in when chips < BB
    
    func testBlindAllIn() {
        // Test 1: Core blind posting logic works
        var players = [
            Player(name: "P1", chips: 1000, isHuman: true),
            Player(name: "P2", chips: 15, isHuman: true)
        ]
        var pot = Pot()
        var hasActed: [UUID: Bool] = [:]
        
        BettingManager.postBlind(playerIndex: 0, amount: 10, players: &players, pot: &pot, hasActed: &hasActed)
        BettingManager.postBlind(playerIndex: 1, amount: 20, players: &players, pot: &pot, hasActed: &hasActed)
        
        XCTAssertEqual(players[1].status, .allIn, "P2 should be all-in")
        XCTAssertEqual(players[1].chips, 0, "P2 chips should be 0")
        XCTAssertEqual(players[1].currentBet, 15, "P2 bet should be 15")
        XCTAssertEqual(pot.total, 25, "Pot should be 25")
        
        // Test 2: Test with actual PokerEngine - skip for now due to async issues
        // The full integration test would require testing the complete game flow
        // which involves async bot decisions
    }
    
    // MARK: - Test 5: Fold ends the hand immediately
    
    func testFoldEndsHand() {
        // Add some money to the pot so the winner gets something
        engine.pot.add(100)
        
        engine.activePlayerIndex = 0
        engine.processAction(.fold)
        
        XCTAssertTrue(engine.isHandOver)
        XCTAssertTrue(engine.winners.contains(engine.players[1].id))
        // P2 wins the pot
        XCTAssertEqual(engine.players[1].chips, 1100) // 1000 + 100
    }
    
    // MARK: - Test 6: Re-raise forces original raiser to act again
    
    func testMultipleRaises() {
        // P1 raises to 50
        engine.activePlayerIndex = 0
        engine.processAction(.raise(50))
        
        XCTAssertEqual(engine.currentBet, 50)
        
        // P2 re-raises to 100
        // minRaise after P1's raise: max(20, 50-0) = 50
        // minimumRaiseTo = 50 + 50 = 100, so raise(100) is valid
        engine.activePlayerIndex = 1
        engine.processAction(.raise(100))
        
        XCTAssertEqual(engine.currentBet, 100)
        XCTAssertEqual(engine.players[1].currentBet, 100)
        XCTAssertEqual(engine.players[1].chips, 900)
        
        // P1 must act again (re-raise re-opened action)
        XCTAssertEqual(engine.activePlayerIndex, 0)
        XCTAssertFalse(engine.isHandOver)
    }
}
