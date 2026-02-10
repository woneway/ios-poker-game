// import XCTest

class PokerEngineTests: XCTestCase {
    
    var engine: PokerEngine!
    
    override func setUp() {
        super.setUp()
        engine = PokerEngine()
        // Force simple state
        engine.players = [
            Player(name: "P1", chips: 1000),
            Player(name: "P2", chips: 1000)
        ]
        engine.pot = Pot()
        engine.currentBet = 0
    }
    
    func testBettingLogic() {
        // P1 bets 50
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
        
        // Since round is complete (2 players, both matched), engine advances to next street
        // and resets currentBet to 0.
        XCTAssertEqual(engine.currentBet, 0)
    }
    
    func testAllInLogic() {
        // P1 goes All In (1000)
        engine.activePlayerIndex = 0
        engine.processAction(.allIn)
        
        XCTAssertEqual(engine.players[0].chips, 0)
        XCTAssertEqual(engine.players[0].status, .allIn)
        XCTAssertEqual(engine.pot.total, 1000)
        XCTAssertEqual(engine.currentBet, 1000)
    }
}
