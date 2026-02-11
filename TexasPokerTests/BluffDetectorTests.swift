import XCTest
@testable import TexasPoker

class BluffDetectorTests: XCTestCase {
    
    // MARK: - Test Triple Barrel Detection
    
    func testTripleBarrelDetection() {
        // Setup: Create opponent with high AF
        let opponent = OpponentModel(playerName: "Aggressive Player", gameMode: .cashGame)
        opponent.af = 4.0
        opponent.totalHands = 50
        
        // Create betting history: 3 streets of continuous betting
        let betHistory = [
            BetAction(street: .flop, type: .bet, amount: 50),
            BetAction(street: .turn, type: .bet, amount: 100),
            BetAction(street: .river, type: .bet, amount: 200)
        ]
        
        // Dry board (easier to bluff)
        let board = BoardTexture(
            wetness: 0.3,
            isPaired: false,
            isMonotone: false,
            isTwoTone: false,
            hasHighCards: true,
            connectivity: 0.2
        )
        
        // Calculate bluff probability
        let indicator = BluffDetector.calculateBluffProbability(
            opponent: opponent,
            board: board,
            betHistory: betHistory,
            potSize: 300
        )
        
        // Assertions
        XCTAssertGreaterThan(indicator.bluffProbability, 0.5, "Triple barrel should indicate high bluff probability")
        XCTAssertTrue(indicator.signals.contains(.tripleBarrel), "Should detect triple barrel signal")
        XCTAssertTrue(indicator.signals.contains(.highAggression), "Should detect high aggression signal")
        XCTAssertTrue(indicator.signals.contains(.dryBoardLargeBet), "Should detect dry board signal")
        XCTAssertGreaterThan(indicator.confidence, 0.9, "Should have high confidence with 50 hands")
        
        print("✅ Triple Barrel Test: Bluff probability = \(String(format: "%.1f%%", indicator.bluffProbability * 100))")
        print("   Signals: \(indicator.signals.map { $0.rawValue }.joined(separator: ", "))")
    }
    
    // MARK: - Test River Overbet Detection
    
    func testRiverOverbetDetection() {
        // Setup: Create opponent
        let opponent = OpponentModel(playerName: "Overbet Player", gameMode: .cashGame)
        opponent.af = 2.5
        opponent.totalHands = 40
        
        // River overbet: 1.5x pot
        let potSize = 300
        let betHistory = [
            BetAction(street: .river, type: .bet, amount: 450)  // 1.5x pot
        ]
        
        // Medium board texture
        let board = BoardTexture(
            wetness: 0.5,
            isPaired: false,
            isMonotone: false,
            isTwoTone: true,
            hasHighCards: true,
            connectivity: 0.5
        )
        
        let indicator = BluffDetector.calculateBluffProbability(
            opponent: opponent,
            board: board,
            betHistory: betHistory,
            potSize: potSize
        )
        
        // Assertions
        XCTAssertTrue(indicator.signals.contains(.riverOverbet), "Should detect river overbet")
        XCTAssertGreaterThan(indicator.bluffProbability, 0.15, "Overbet should increase bluff probability")
        
        print("✅ River Overbet Test: Bluff probability = \(String(format: "%.1f%%", indicator.bluffProbability * 100))")
        print("   Signals: \(indicator.signals.map { $0.rawValue }.joined(separator: ", "))")
    }
    
    // MARK: - Test High Aggression Detection
    
    func testHighAggressionDetection() {
        // Setup: Very aggressive opponent (AF > 3.0)
        let opponent = OpponentModel(playerName: "Maniac", gameMode: .cashGame)
        opponent.af = 5.0  // Very high aggression
        opponent.totalHands = 60
        
        let betHistory = [
            BetAction(street: .flop, type: .bet, amount: 50)
        ]
        
        let board = BoardTexture(
            wetness: 0.4,
            isPaired: false,
            isMonotone: false,
            isTwoTone: false,
            hasHighCards: false,
            connectivity: 0.3
        )
        
        let indicator = BluffDetector.calculateBluffProbability(
            opponent: opponent,
            board: board,
            betHistory: betHistory,
            potSize: 100
        )
        
        // Assertions
        XCTAssertTrue(indicator.signals.contains(.highAggression), "Should detect high aggression")
        XCTAssertGreaterThan(indicator.bluffProbability, 0.15, "High AF should increase bluff probability")
        XCTAssertEqual(indicator.confidence, 1.0, "Should have full confidence with 60+ hands")
        
        print("✅ High Aggression Test: Bluff probability = \(String(format: "%.1f%%", indicator.bluffProbability * 100))")
    }
    
    // MARK: - Test Wet Board Continuation
    
    func testWetBoardContinuation() {
        // Setup: Opponent continues betting on wet board
        let opponent = OpponentModel(playerName: "Wet Board Bettor", gameMode: .cashGame)
        opponent.af = 3.5
        opponent.totalHands = 45
        
        // Two streets of betting on wet board
        let betHistory = [
            BetAction(street: .flop, type: .bet, amount: 60),
            BetAction(street: .turn, type: .bet, amount: 120)
        ]
        
        // Very wet board (monotone, connected)
        let board = BoardTexture(
            wetness: 0.8,
            isPaired: false,
            isMonotone: true,
            isTwoTone: false,
            hasHighCards: true,
            connectivity: 0.7
        )
        
        let indicator = BluffDetector.calculateBluffProbability(
            opponent: opponent,
            board: board,
            betHistory: betHistory,
            potSize: 200
        )
        
        // Assertions
        XCTAssertTrue(indicator.signals.contains(.wetBoardContinue), "Should detect wet board continuation")
        XCTAssertTrue(indicator.signals.contains(.highAggression), "Should also detect high aggression")
        
        print("✅ Wet Board Continuation Test: Bluff probability = \(String(format: "%.1f%%", indicator.bluffProbability * 100))")
        print("   Signals: \(indicator.signals.map { $0.rawValue }.joined(separator: ", "))")
    }
    
    // MARK: - Test Inconsistent Sizing
    
    func testInconsistentBetSizing() {
        // Setup: Opponent with inconsistent bet sizing
        let opponent = OpponentModel(playerName: "Erratic Bettor", gameMode: .cashGame)
        opponent.af = 2.8
        opponent.totalHands = 35
        
        // Highly inconsistent bet sizes
        let potSize = 100
        let betHistory = [
            BetAction(street: .flop, type: .bet, amount: 30),   // 0.3x pot
            BetAction(street: .turn, type: .bet, amount: 150)   // 1.5x pot
        ]
        
        let board = BoardTexture(
            wetness: 0.5,
            isPaired: false,
            isMonotone: false,
            isTwoTone: true,
            hasHighCards: false,
            connectivity: 0.4
        )
        
        let indicator = BluffDetector.calculateBluffProbability(
            opponent: opponent,
            board: board,
            betHistory: betHistory,
            potSize: potSize
        )
        
        // Assertions
        XCTAssertTrue(indicator.signals.contains(.inconsistentSizing), "Should detect inconsistent sizing")
        
        print("✅ Inconsistent Sizing Test: Bluff probability = \(String(format: "%.1f%%", indicator.bluffProbability * 100))")
        print("   Signals: \(indicator.signals.map { $0.rawValue }.joined(separator: ", "))")
    }
    
    // MARK: - Test Low Bluff Probability (Tight Player)
    
    func testLowBluffProbability() {
        // Setup: Tight passive opponent
        let opponent = OpponentModel(playerName: "Rock", gameMode: .cashGame)
        opponent.af = 1.5  // Low aggression
        opponent.totalHands = 50
        
        // Single bet on wet board
        let betHistory = [
            BetAction(street: .flop, type: .bet, amount: 50)
        ]
        
        // Wet board (harder to bluff)
        let board = BoardTexture(
            wetness: 0.7,
            isPaired: true,
            isMonotone: false,
            isTwoTone: true,
            hasHighCards: true,
            connectivity: 0.6
        )
        
        let indicator = BluffDetector.calculateBluffProbability(
            opponent: opponent,
            board: board,
            betHistory: betHistory,
            potSize: 100
        )
        
        // Assertions
        XCTAssertLessThan(indicator.bluffProbability, 0.3, "Tight player should have low bluff probability")
        XCTAssertFalse(indicator.signals.contains(.highAggression), "Should not detect high aggression")
        XCTAssertEqual(indicator.recommendation, "低诈唬概率 - 收紧跟注范围")
        
        print("✅ Low Bluff Probability Test: Bluff probability = \(String(format: "%.1f%%", indicator.bluffProbability * 100))")
        print("   Recommendation: \(indicator.recommendation)")
    }
    
    // MARK: - Test Confidence Based on Sample Size
    
    func testConfidenceCalculation() {
        // Test with different sample sizes
        let testCases: [(hands: Int, expectedConfidence: Double)] = [
            (10, 0.33),   // Low sample
            (30, 1.0),    // Sufficient sample
            (50, 1.0),    // High sample
            (100, 1.0)    // Very high sample
        ]
        
        for testCase in testCases {
            let opponent = OpponentModel(playerName: "Test", gameMode: .cashGame)
            opponent.totalHands = testCase.hands
            opponent.af = 3.0
            
            let indicator = BluffDetector.calculateBluffProbability(
                opponent: opponent,
                board: BoardTexture(wetness: 0.5, isPaired: false, isMonotone: false,
                                  isTwoTone: false, hasHighCards: false, connectivity: 0.5),
                betHistory: [BetAction(street: .flop, type: .bet, amount: 50)],
                potSize: 100
            )
            
            XCTAssertEqual(indicator.confidence, testCase.expectedConfidence, accuracy: 0.05,
                          "Confidence should be \(testCase.expectedConfidence) for \(testCase.hands) hands")
        }
        
        print("✅ Confidence Calculation Test: All sample sizes validated")
    }
    
    // MARK: - Test Maximum Bluff Probability Cap
    
    func testMaximumBluffProbabilityCap() {
        // Setup: All signals triggered
        let opponent = OpponentModel(playerName: "Super Aggressive", gameMode: .cashGame)
        opponent.af = 6.0  // Very high
        opponent.totalHands = 50
        
        // Triple barrel with overbet on river
        let betHistory = [
            BetAction(street: .flop, type: .bet, amount: 50),
            BetAction(street: .turn, type: .bet, amount: 100),
            BetAction(street: .river, type: .bet, amount: 500)  // Huge overbet
        ]
        
        // Dry board
        let board = BoardTexture(
            wetness: 0.2,
            isPaired: false,
            isMonotone: false,
            isTwoTone: false,
            hasHighCards: false,
            connectivity: 0.1
        )
        
        let indicator = BluffDetector.calculateBluffProbability(
            opponent: opponent,
            board: board,
            betHistory: betHistory,
            potSize: 200
        )
        
        // Assertions
        XCTAssertLessThanOrEqual(indicator.bluffProbability, 0.85, "Bluff probability should be capped at 85%")
        XCTAssertGreaterThan(indicator.signals.count, 3, "Should detect multiple signals")
        
        print("✅ Maximum Cap Test: Bluff probability = \(String(format: "%.1f%%", indicator.bluffProbability * 100))")
        print("   Signals detected: \(indicator.signals.count)")
    }
    
    // MARK: - Test Recommendation System
    
    func testRecommendationSystem() {
        let opponent = OpponentModel(playerName: "Test", gameMode: .cashGame)
        opponent.totalHands = 50
        
        // Test high bluff probability recommendation
        opponent.af = 5.0
        let highBluffIndicator = BluffDetector.calculateBluffProbability(
            opponent: opponent,
            board: BoardTexture(wetness: 0.3, isPaired: false, isMonotone: false,
                              isTwoTone: false, hasHighCards: false, connectivity: 0.2),
            betHistory: [
                BetAction(street: .flop, type: .bet, amount: 50),
                BetAction(street: .turn, type: .bet, amount: 100),
                BetAction(street: .river, type: .bet, amount: 200)
            ],
            potSize: 300
        )
        XCTAssertEqual(highBluffIndicator.recommendation, "高诈唬概率 - 扩大跟注范围")
        
        // Test low bluff probability recommendation
        opponent.af = 1.5
        let lowBluffIndicator = BluffDetector.calculateBluffProbability(
            opponent: opponent,
            board: BoardTexture(wetness: 0.7, isPaired: true, isMonotone: false,
                              isTwoTone: true, hasHighCards: true, connectivity: 0.6),
            betHistory: [BetAction(street: .flop, type: .bet, amount: 50)],
            potSize: 100
        )
        XCTAssertEqual(lowBluffIndicator.recommendation, "低诈唬概率 - 收紧跟注范围")
        
        print("✅ Recommendation System Test: All recommendations validated")
    }
}
