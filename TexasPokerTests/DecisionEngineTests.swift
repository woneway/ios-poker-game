import XCTest
@testable import TexasPoker

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
    
    // MARK: - Opponent Modeling Tests
    
    func testClassifyRockStyle() {
        // Rock: VPIP<20%, PFR<15%, AF>2.5
        let style = OpponentModeler.classifyStyle(vpip: 15.0, pfr: 12.0, af: 3.0)
        XCTAssertEqual(style, .rock, "Should classify as Rock")
    }
    
    func testClassifyFishStyle() {
        // Fish: VPIP>45%, PFR<15%, AF<1.5
        let style = OpponentModeler.classifyStyle(vpip: 50.0, pfr: 10.0, af: 1.0)
        XCTAssertEqual(style, .fish, "Should classify as Fish")
    }
    
    func testClassifyLAGStyle() {
        // LAG: VPIP 30-45%, PFR 25-35%, AF≥3.0
        let style = OpponentModeler.classifyStyle(vpip: 35.0, pfr: 28.0, af: 3.5)
        XCTAssertEqual(style, .lag, "Should classify as LAG")
    }
    
    func testClassifyTAGStyle() {
        // TAG: VPIP 20-30%, PFR 15-25%, AF 2-3
        let style = OpponentModeler.classifyStyle(vpip: 25.0, pfr: 20.0, af: 2.5)
        XCTAssertEqual(style, .tag, "Should classify as TAG")
    }
    
    func testClassifyUnknownStyle() {
        // Unknown: no data
        let style = OpponentModeler.classifyStyle(vpip: 0.0, pfr: 0.0, af: 0.0)
        XCTAssertEqual(style, .unknown, "Should classify as Unknown")
    }
    
    func testBoundaryCase_LowVPIP() {
        // VPIP < 25, should default to TAG
        let style = OpponentModeler.classifyStyle(vpip: 22.0, pfr: 10.0, af: 1.5)
        XCTAssertEqual(style, .tag, "Low VPIP boundary should default to TAG")
    }
    
    func testBoundaryCase_HighVPIP() {
        // VPIP > 40, should default to Fish
        let style = OpponentModeler.classifyStyle(vpip: 42.0, pfr: 20.0, af: 2.0)
        XCTAssertEqual(style, .fish, "High VPIP boundary should default to Fish")
    }
    
    func testConfidenceCalculation() {
        let model = OpponentModel(playerName: "TestPlayer", gameMode: .cashGame)
        
        // 0 hands = 0% confidence
        model.totalHands = 0
        XCTAssertEqual(model.confidence, 0.0, accuracy: 0.01)
        
        // 25 hands = 50% confidence
        model.totalHands = 25
        XCTAssertEqual(model.confidence, 0.5, accuracy: 0.01)
        
        // 50 hands = 100% confidence
        model.totalHands = 50
        XCTAssertEqual(model.confidence, 1.0, accuracy: 0.01)
        
        // 100 hands = 100% confidence (capped)
        model.totalHands = 100
        XCTAssertEqual(model.confidence, 1.0, accuracy: 0.01)
    }
    
    func testStrategyAdjustment_Rock() {
        let adjustment = OpponentModeler.getStrategyAdjustment(style: .rock)
        XCTAssertEqual(adjustment.stealFreqBonus, 0.30, accuracy: 0.01)
        XCTAssertEqual(adjustment.bluffFreqAdjust, -0.50, accuracy: 0.01)
        XCTAssertEqual(adjustment.valueSizeAdjust, -0.25, accuracy: 0.01)
        XCTAssertEqual(adjustment.callDownAdjust, -0.30, accuracy: 0.01)
    }
    
    func testStrategyAdjustment_Fish() {
        let adjustment = OpponentModeler.getStrategyAdjustment(style: .fish)
        XCTAssertEqual(adjustment.stealFreqBonus, 0.0, accuracy: 0.01)
        XCTAssertEqual(adjustment.bluffFreqAdjust, -0.70, accuracy: 0.01)
        XCTAssertEqual(adjustment.valueSizeAdjust, 0.40, accuracy: 0.01)
        XCTAssertEqual(adjustment.callDownAdjust, -0.20, accuracy: 0.01)
    }
    
    func testStrategyAdjustment_TAG() {
        let adjustment = OpponentModeler.getStrategyAdjustment(style: .tag)
        XCTAssertEqual(adjustment.stealFreqBonus, 0.0, accuracy: 0.01)
        XCTAssertEqual(adjustment.bluffFreqAdjust, 0.0, accuracy: 0.01)
        XCTAssertEqual(adjustment.valueSizeAdjust, 0.0, accuracy: 0.01)
        XCTAssertEqual(adjustment.callDownAdjust, 0.0, accuracy: 0.01)
    }
    
    func testOpponentModelCache() {
        // Reset cache
        DecisionEngine.resetOpponentModels()
        XCTAssertEqual(DecisionEngine.opponentModels.count, 0)
        
        // Note: This test would require Core Data setup to fully test loadOpponentModel
        // For now, we just verify the cache reset works
    }
}
