import XCTest
@testable import TexasPoker

class DifficultyManagerTests: XCTestCase {
    
    var manager: DifficultyManager!
    
    override func setUp() {
        super.setUp()
        manager = DifficultyManager()
        manager.isAutoDifficulty = true
    }
    
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    // MARK: - Test Difficulty Increase
    
    func testDifficultyIncreaseFromMedium() {
        manager.currentDifficulty = .medium
        
        // Simulate Hero winning 65% of hands (13 wins out of 20)
        for _ in 0..<13 {
            manager.recordHand(heroWon: true)
        }
        for _ in 0..<7 {
            manager.recordHand(heroWon: false)
        }
        
        XCTAssertEqual(manager.currentDifficulty, .hard, 
                      "Difficulty should increase from Medium to Hard when win rate > 60%")
        XCTAssertEqual(manager.heroWinRate, 0.65, accuracy: 0.01, "Win rate should be 65%")
        
        print("✅ Difficulty Increase Test (Medium → Hard):")
        print("   Win rate: \(String(format: "%.1f%%", manager.heroWinRate * 100))")
        print("   New difficulty: \(manager.currentDifficulty.description)")
    }
    
    func testDifficultyIncreaseFromHard() {
        manager.currentDifficulty = .hard
        
        // Simulate Hero winning 70% of hands (14 wins out of 20)
        for _ in 0..<14 {
            manager.recordHand(heroWon: true)
        }
        for _ in 0..<6 {
            manager.recordHand(heroWon: false)
        }
        
        XCTAssertEqual(manager.currentDifficulty, .expert, 
                      "Difficulty should increase from Hard to Expert when win rate > 60%")
        
        print("✅ Difficulty Increase Test (Hard → Expert):")
        print("   Win rate: \(String(format: "%.1f%%", manager.heroWinRate * 100))")
        print("   New difficulty: \(manager.currentDifficulty.description)")
    }
    
    func testDifficultyDoesNotIncreaseFromExpert() {
        manager.currentDifficulty = .expert
        
        // Simulate Hero winning 70% of hands
        for _ in 0..<14 {
            manager.recordHand(heroWon: true)
        }
        for _ in 0..<6 {
            manager.recordHand(heroWon: false)
        }
        
        XCTAssertEqual(manager.currentDifficulty, .expert, 
                      "Difficulty should stay at Expert (max level)")
        
        print("✅ Max Difficulty Test: Expert remains Expert")
    }
    
    // MARK: - Test Difficulty Decrease
    
    func testDifficultyDecreaseFromMedium() {
        manager.currentDifficulty = .medium
        
        // Simulate Hero winning 30% of hands (6 wins out of 20)
        for _ in 0..<6 {
            manager.recordHand(heroWon: true)
        }
        for _ in 0..<14 {
            manager.recordHand(heroWon: false)
        }
        
        XCTAssertEqual(manager.currentDifficulty, .easy, 
                      "Difficulty should decrease from Medium to Easy when win rate < 35%")
        XCTAssertEqual(manager.heroWinRate, 0.30, accuracy: 0.01, "Win rate should be 30%")
        
        print("✅ Difficulty Decrease Test (Medium → Easy):")
        print("   Win rate: \(String(format: "%.1f%%", manager.heroWinRate * 100))")
        print("   New difficulty: \(manager.currentDifficulty.description)")
    }
    
    func testDifficultyDecreaseFromHard() {
        manager.currentDifficulty = .hard
        
        // Simulate Hero winning 32% of hands (6 wins out of 20, then 7 more)
        for _ in 0..<13 {
            manager.recordHand(heroWon: false)
        }
        for _ in 0..<7 {
            manager.recordHand(heroWon: true)
        }
        
        XCTAssertEqual(manager.currentDifficulty, .medium, 
                      "Difficulty should decrease from Hard to Medium when win rate < 35%")
        
        print("✅ Difficulty Decrease Test (Hard → Medium):")
        print("   Win rate: \(String(format: "%.1f%%", manager.heroWinRate * 100))")
        print("   New difficulty: \(manager.currentDifficulty.description)")
    }
    
    func testDifficultyDoesNotDecreaseFromEasy() {
        manager.currentDifficulty = .easy
        
        // Simulate Hero winning 25% of hands
        for _ in 0..<5 {
            manager.recordHand(heroWon: true)
        }
        for _ in 0..<15 {
            manager.recordHand(heroWon: false)
        }
        
        XCTAssertEqual(manager.currentDifficulty, .easy, 
                      "Difficulty should stay at Easy (min level)")
        
        print("✅ Min Difficulty Test: Easy remains Easy")
    }
    
    // MARK: - Test Win Rate Calculation
    
    func testWinRateCalculation() {
        // Test exact win rate calculation
        manager.recordHand(heroWon: true)
        manager.recordHand(heroWon: true)
        manager.recordHand(heroWon: false)
        
        XCTAssertEqual(manager.heroWinRate, 2.0/3.0, accuracy: 0.01, 
                      "Win rate should be 66.67% (2 wins out of 3)")
        
        print("✅ Win Rate Calculation Test:")
        print("   2 wins, 1 loss → \(String(format: "%.1f%%", manager.heroWinRate * 100))")
    }
    
    func testWinRateWithNoHands() {
        XCTAssertEqual(manager.heroWinRate, 0.5, accuracy: 0.01, 
                      "Win rate should default to 50% with no hands")
        
        print("✅ Default Win Rate Test: 50% with no hands")
    }
    
    func testWinRateWith100Hands() {
        // Test with exactly 100 hands (max history)
        for _ in 0..<55 {
            manager.recordHand(heroWon: true)
        }
        for _ in 0..<45 {
            manager.recordHand(heroWon: false)
        }
        
        XCTAssertEqual(manager.heroWinRate, 0.55, accuracy: 0.01, 
                      "Win rate should be 55% (55 wins out of 100)")
        
        print("✅ Win Rate Test (100 hands): \(String(format: "%.1f%%", manager.heroWinRate * 100))")
    }
    
    func testWinRateHistoryLimit() {
        // Test that history is limited to 100 hands
        for _ in 0..<120 {
            manager.recordHand(heroWon: true)
        }
        
        // Only last 100 hands should be counted
        XCTAssertEqual(manager.heroWinRate, 1.0, accuracy: 0.01, 
                      "Win rate should be 100% (last 100 hands all wins)")
        
        print("✅ History Limit Test: Only last 100 hands counted")
    }
    
    // MARK: - Test Auto-Adjustment Timing
    
    func testAdjustmentEvery20Hands() {
        manager.currentDifficulty = .medium
        
        // Record 19 hands with 70% win rate (should not adjust yet)
        for _ in 0..<13 {
            manager.recordHand(heroWon: true)
        }
        for _ in 0..<6 {
            manager.recordHand(heroWon: false)
        }
        
        XCTAssertEqual(manager.currentDifficulty, .medium, 
                      "Difficulty should not change after 19 hands")
        
        // Record 20th hand (should adjust now)
        manager.recordHand(heroWon: true)
        
        XCTAssertEqual(manager.currentDifficulty, .hard, 
                      "Difficulty should increase after 20 hands")
        
        print("✅ Adjustment Timing Test: Adjusts every 20 hands")
    }
    
    func testNoAdjustmentWhenDisabled() {
        manager.isAutoDifficulty = false
        manager.currentDifficulty = .medium
        
        // Simulate high win rate
        for _ in 0..<14 {
            manager.recordHand(heroWon: true)
        }
        for _ in 0..<6 {
            manager.recordHand(heroWon: false)
        }
        
        XCTAssertEqual(manager.currentDifficulty, .medium, 
                      "Difficulty should not change when auto-adjustment is disabled")
        
        print("✅ Manual Mode Test: No auto-adjustment when disabled")
    }
    
    // MARK: - Test Feature Gating
    
    func testOpponentModelingFeatureGate() {
        manager.currentDifficulty = .easy
        XCTAssertFalse(manager.shouldUseOpponentModeling(), 
                      "Easy difficulty should not use opponent modeling")
        
        manager.currentDifficulty = .medium
        XCTAssertTrue(manager.shouldUseOpponentModeling(), 
                     "Medium difficulty should use opponent modeling")
        
        manager.currentDifficulty = .hard
        XCTAssertTrue(manager.shouldUseOpponentModeling(), 
                     "Hard difficulty should use opponent modeling")
        
        manager.currentDifficulty = .expert
        XCTAssertTrue(manager.shouldUseOpponentModeling(), 
                     "Expert difficulty should use opponent modeling")
        
        print("✅ Opponent Modeling Feature Gate:")
        print("   Easy: \(manager.currentDifficulty == .easy && !manager.shouldUseOpponentModeling() ? "OFF" : "ON")")
        print("   Medium+: ON")
    }
    
    func testRangeThinkingFeatureGate() {
        manager.currentDifficulty = .easy
        XCTAssertFalse(manager.shouldUseRangeThinking(), 
                      "Easy difficulty should not use range thinking")
        
        manager.currentDifficulty = .medium
        XCTAssertFalse(manager.shouldUseRangeThinking(), 
                      "Medium difficulty should not use range thinking")
        
        manager.currentDifficulty = .hard
        XCTAssertTrue(manager.shouldUseRangeThinking(), 
                     "Hard difficulty should use range thinking")
        
        manager.currentDifficulty = .expert
        XCTAssertTrue(manager.shouldUseRangeThinking(), 
                     "Expert difficulty should use range thinking")
        
        print("✅ Range Thinking Feature Gate:")
        print("   Easy/Medium: OFF")
        print("   Hard/Expert: ON")
    }
    
    func testBluffDetectionFeatureGate() {
        manager.currentDifficulty = .easy
        XCTAssertFalse(manager.shouldUseBluffDetection(), 
                      "Easy difficulty should not use bluff detection")
        
        manager.currentDifficulty = .medium
        XCTAssertFalse(manager.shouldUseBluffDetection(), 
                      "Medium difficulty should not use bluff detection")
        
        manager.currentDifficulty = .hard
        XCTAssertFalse(manager.shouldUseBluffDetection(), 
                      "Hard difficulty should not use bluff detection")
        
        manager.currentDifficulty = .expert
        XCTAssertTrue(manager.shouldUseBluffDetection(), 
                     "Expert difficulty should use bluff detection")
        
        print("✅ Bluff Detection Feature Gate:")
        print("   Easy/Medium/Hard: OFF")
        print("   Expert: ON")
    }
    
    // MARK: - Test Difficulty Level Properties
    
    func testDifficultyPrecision() {
        XCTAssertEqual(DifficultyLevel.easy.precision, 0.60, "Easy precision should be 60%")
        XCTAssertEqual(DifficultyLevel.medium.precision, 0.80, "Medium precision should be 80%")
        XCTAssertEqual(DifficultyLevel.hard.precision, 0.95, "Hard precision should be 95%")
        XCTAssertEqual(DifficultyLevel.expert.precision, 1.00, "Expert precision should be 100%")
        
        print("✅ Difficulty Precision Test:")
        print("   Easy: 60%, Medium: 80%, Hard: 95%, Expert: 100%")
    }
    
    func testDifficultyTargetWinRate() {
        XCTAssertTrue(DifficultyLevel.easy.targetWinRate.contains(0.60), 
                     "Easy target should include 60%")
        XCTAssertTrue(DifficultyLevel.medium.targetWinRate.contains(0.50), 
                     "Medium target should include 50%")
        XCTAssertTrue(DifficultyLevel.hard.targetWinRate.contains(0.40), 
                     "Hard target should include 40%")
        XCTAssertTrue(DifficultyLevel.expert.targetWinRate.contains(0.35), 
                     "Expert target should include 35%")
        
        print("✅ Target Win Rate Test:")
        print("   Easy: \(DifficultyLevel.easy.targetWinRate)")
        print("   Medium: \(DifficultyLevel.medium.targetWinRate)")
        print("   Hard: \(DifficultyLevel.hard.targetWinRate)")
        print("   Expert: \(DifficultyLevel.expert.targetWinRate)")
    }
    
    func testDifficultyDescription() {
        XCTAssertFalse(DifficultyLevel.easy.description.isEmpty)
        XCTAssertFalse(DifficultyLevel.medium.description.isEmpty)
        XCTAssertFalse(DifficultyLevel.hard.description.isEmpty)
        XCTAssertFalse(DifficultyLevel.expert.description.isEmpty)
        
        print("✅ Difficulty Descriptions:")
        print("   Easy: \(DifficultyLevel.easy.description)")
        print("   Medium: \(DifficultyLevel.medium.description)")
        print("   Hard: \(DifficultyLevel.hard.description)")
        print("   Expert: \(DifficultyLevel.expert.description)")
    }
    
    // MARK: - Test Difficulty Level Transitions
    
    func testDifficultyIncrease() {
        XCTAssertEqual(DifficultyLevel.easy.increase(), .medium)
        XCTAssertEqual(DifficultyLevel.medium.increase(), .hard)
        XCTAssertEqual(DifficultyLevel.hard.increase(), .expert)
        XCTAssertEqual(DifficultyLevel.expert.increase(), .expert, "Expert should stay at max")
        
        print("✅ Difficulty Increase Test: All transitions work correctly")
    }
    
    func testDifficultyDecrease() {
        XCTAssertEqual(DifficultyLevel.expert.decrease(), .hard)
        XCTAssertEqual(DifficultyLevel.hard.decrease(), .medium)
        XCTAssertEqual(DifficultyLevel.medium.decrease(), .easy)
        XCTAssertEqual(DifficultyLevel.easy.decrease(), .easy, "Easy should stay at min")
        
        print("✅ Difficulty Decrease Test: All transitions work correctly")
    }
    
    // MARK: - Test Edge Cases
    
    func testWinRateAtExactThreshold() {
        manager.currentDifficulty = .medium
        
        // Test at exactly 60% win rate (threshold for increase)
        for _ in 0..<12 {
            manager.recordHand(heroWon: true)
        }
        for _ in 0..<8 {
            manager.recordHand(heroWon: false)
        }
        
        // Should NOT increase at exactly 60% (needs > 60%)
        XCTAssertEqual(manager.currentDifficulty, .medium, 
                      "Difficulty should not increase at exactly 60% win rate")
        
        print("✅ Threshold Edge Case Test: 60% win rate does not trigger increase")
    }
    
    func testWinRateJustAboveThreshold() {
        manager.currentDifficulty = .medium
        
        // Test at 61% win rate (just above threshold)
        for _ in 0..<13 {
            manager.recordHand(heroWon: true)
        }
        for _ in 0..<7 {
            manager.recordHand(heroWon: false)
        }
        
        // Should increase at 65% (> 60%)
        XCTAssertEqual(manager.currentDifficulty, .hard, 
                      "Difficulty should increase at 65% win rate")
        
        print("✅ Above Threshold Test: 65% win rate triggers increase")
    }
    
    func testStableWinRate() {
        manager.currentDifficulty = .medium
        
        // Test at 50% win rate (stable, no change)
        for _ in 0..<10 {
            manager.recordHand(heroWon: true)
        }
        for _ in 0..<10 {
            manager.recordHand(heroWon: false)
        }
        
        XCTAssertEqual(manager.currentDifficulty, .medium, 
                      "Difficulty should remain stable at 50% win rate")
        
        print("✅ Stable Win Rate Test: 50% win rate maintains current difficulty")
    }
}
