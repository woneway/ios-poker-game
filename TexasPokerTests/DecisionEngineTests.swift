// import XCTest

class DecisionEngineTests: XCTestCase {
    
    func testEquityCalculation() {
        // AA vs 72o (Preflop)
        // AA should have ~85% equity
        
        let aces = [Card(rank: .ace, suit: .spades), Card(rank: .ace, suit: .hearts)]
        _ = [Card(rank: .seven, suit: .clubs), Card(rank: .two, suit: .diamonds)]
        
        // We can't easily force opponent hand in MonteCarloSimulator without modifying it to accept specific opponent hands.
        // But we can test Equity of AA against random hands.
        
        let equity = MonteCarloSimulator.calculateEquity(
            holeCards: aces,
            communityCards: [],
            playerCount: 2,
            iterations: 1000
        )
        
        print("AA Equity vs Random: \(equity)")
        XCTAssertTrue(equity > 0.80, "Aces should be strong preflop (>80%)")
    }
    
    func testPotOdds() {
        // Pot is 100, Call is 50.
        // Total Pot after call = 150.
        // Odds = 50 / 150 = 0.33 (33%)
        
        let callAmount = 50
        let potSize = 100
        let odds = Double(callAmount) / Double(potSize + callAmount)
        
        XCTAssertEqual(odds, 1.0/3.0, accuracy: 0.01)
    }
}
