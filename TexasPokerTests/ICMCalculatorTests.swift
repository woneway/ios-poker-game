import XCTest
@testable import TexasPoker

class ICMCalculatorTests: XCTestCase {
    
    // MARK: - Test Bubble Detection
    
    func testBubbleDetection() {
        // 4 players remaining, 3 payout spots → Bubble!
        let situation = ICMCalculator.analyze(
            myChips: 1000,
            allChips: [1000, 800, 600, 400],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertTrue(situation.isBubble, "Should detect bubble when players = payouts + 1")
        XCTAssertEqual(situation.playersRemaining, 4)
        XCTAssertEqual(situation.payoutSpots, 3)
        
        print("✅ Bubble Detection Test:")
        print("   Players: \(situation.playersRemaining), Payouts: \(situation.payoutSpots)")
        print("   Is Bubble: \(situation.isBubble)")
    }
    
    func testNotBubble() {
        // 5 players remaining, 3 payout spots → Not bubble yet
        let situation = ICMCalculator.analyze(
            myChips: 1000,
            allChips: [1500, 1000, 800, 600, 400],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertFalse(situation.isBubble, "Should not detect bubble when players > payouts + 1")
        
        print("✅ Not Bubble Test:")
        print("   Players: \(situation.playersRemaining), Payouts: \(situation.payoutSpots)")
        print("   Is Bubble: \(situation.isBubble)")
    }
    
    func testInTheMoney() {
        // 3 players remaining, 3 payout spots → In the money
        let situation = ICMCalculator.analyze(
            myChips: 1000,
            allChips: [1200, 1000, 800],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertFalse(situation.isBubble, "Should not be bubble when in the money")
        XCTAssertEqual(situation.playersRemaining, 3)
        XCTAssertEqual(situation.payoutSpots, 3)
        
        print("✅ In The Money Test:")
        print("   Players: \(situation.playersRemaining), Payouts: \(situation.payoutSpots)")
        print("   Is Bubble: \(situation.isBubble)")
    }
    
    // MARK: - Test Stack Category Classification
    
    func testBigStackCategory() {
        // 2000 chips, average 950 → Stack ratio 2.1x → Big stack
        let situation = ICMCalculator.analyze(
            myChips: 2000,
            allChips: [2000, 800, 600, 400],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertEqual(situation.stackCategory, .big, "Stack ratio > 1.5x should be Big")
        XCTAssertGreaterThan(situation.stackRatio, 1.5)
        
        print("✅ Big Stack Test:")
        print("   My chips: \(situation.myChips), Avg: \(situation.avgChips)")
        print("   Stack ratio: \(String(format: "%.2f", situation.stackRatio))x")
        print("   Category: Big")
    }
    
    func testMediumStackCategory() {
        // 1000 chips, average 950 → Stack ratio 1.05x → Medium stack
        let situation = ICMCalculator.analyze(
            myChips: 1000,
            allChips: [1500, 1000, 800, 500],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertEqual(situation.stackCategory, .medium, "Stack ratio 0.7-1.5x should be Medium")
        XCTAssertGreaterThan(situation.stackRatio, 0.7)
        XCTAssertLessThan(situation.stackRatio, 1.5)
        
        print("✅ Medium Stack Test:")
        print("   My chips: \(situation.myChips), Avg: \(situation.avgChips)")
        print("   Stack ratio: \(String(format: "%.2f", situation.stackRatio))x")
        print("   Category: Medium")
    }
    
    func testShortStackCategory() {
        // 400 chips, average 1225 → Stack ratio 0.33x → Short stack
        let situation = ICMCalculator.analyze(
            myChips: 400,
            allChips: [2000, 1500, 1000, 400],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertEqual(situation.stackCategory, .short, "Stack ratio < 0.7x should be Short")
        XCTAssertLessThan(situation.stackRatio, 0.7)
        
        print("✅ Short Stack Test:")
        print("   My chips: \(situation.myChips), Avg: \(situation.avgChips)")
        print("   Stack ratio: \(String(format: "%.2f", situation.stackRatio))x")
        print("   Category: Short")
    }
    
    func testStackCategoryBoundaries() {
        // Test at exact boundaries
        let avgChips = 1000
        
        // Just above short stack threshold (0.7x)
        let situation1 = ICMCalculator.analyze(
            myChips: 701,
            allChips: [1299, 1000, 1000, 701],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        XCTAssertEqual(situation1.stackCategory, .medium, "0.7x should be Medium")
        
        // Just below medium stack threshold (1.5x)
        let situation2 = ICMCalculator.analyze(
            myChips: 1499,
            allChips: [1499, 1000, 1000, 501],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        XCTAssertEqual(situation2.stackCategory, .medium, "1.49x should be Medium")
        
        print("✅ Stack Category Boundary Test:")
        print("   0.7x → Medium, 1.49x → Medium")
    }
    
    // MARK: - Test ICM Pressure Calculation
    
    func testBigStackPressureOnBubble() {
        let situation = ICMCalculator.analyze(
            myChips: 2500,
            allChips: [2500, 1000, 800, 700],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertTrue(situation.isBubble)
        XCTAssertEqual(situation.stackCategory, .big)
        XCTAssertGreaterThan(situation.pressure, 0, "Big stack on bubble should have positive pressure")
        
        print("✅ Big Stack Bubble Pressure:")
        print("   Pressure: \(String(format: "%.2f", situation.pressure))")
        print("   Should apply aggression")
    }
    
    func testMediumStackPressureOnBubble() {
        let situation = ICMCalculator.analyze(
            myChips: 1000,
            allChips: [2000, 1000, 800, 700],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertTrue(situation.isBubble)
        XCTAssertEqual(situation.stackCategory, .medium)
        XCTAssertLessThan(situation.pressure, 0, "Medium stack on bubble should have negative pressure")
        
        print("✅ Medium Stack Bubble Pressure:")
        print("   Pressure: \(String(format: "%.2f", situation.pressure))")
        print("   Should play conservatively")
    }
    
    func testShortStackPressureOnBubble() {
        let situation = ICMCalculator.analyze(
            myChips: 500,
            allChips: [2500, 1500, 1000, 500],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertTrue(situation.isBubble)
        XCTAssertEqual(situation.stackCategory, .short)
        XCTAssertLessThan(situation.pressure, 0, "Short stack on bubble should have negative pressure")
        XCTAssertLessThan(situation.pressure, -0.3, "Short stack pressure should be significant")
        
        print("✅ Short Stack Bubble Pressure:")
        print("   Pressure: \(String(format: "%.2f", situation.pressure))")
        print("   Should be very conservative")
    }
    
    func testPressureNotOnBubble() {
        let situation = ICMCalculator.analyze(
            myChips: 2000,
            allChips: [2000, 1500, 1000, 800, 700],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertFalse(situation.isBubble)
        XCTAssertEqual(situation.stackCategory, .big)
        
        // Pressure should be lower when not on bubble
        let bubbleSituation = ICMCalculator.analyze(
            myChips: 2000,
            allChips: [2000, 1000, 800, 700],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertLessThan(situation.pressure, bubbleSituation.pressure, 
                         "Pressure should be higher on bubble")
        
        print("✅ Non-Bubble Pressure Test:")
        print("   Not bubble: \(String(format: "%.2f", situation.pressure))")
        print("   On bubble: \(String(format: "%.2f", bubbleSituation.pressure))")
    }
    
    // MARK: - Test Strategy Adjustments
    
    func testStrategyAdjustmentForBigStack() {
        let situation = ICMSituation(
            isBubble: true,
            myChips: 2500,
            avgChips: 1250,
            stackRatio: 2.0,
            playersRemaining: 4,
            payoutSpots: 3
        )
        
        let adjustment = ICMCalculator.getStrategyAdjustment(situation: situation)
        
        XCTAssertGreaterThan(adjustment.vpipAdjust, 0, "Big stack should widen VPIP")
        XCTAssertGreaterThan(adjustment.aggressionAdjust, 0, "Big stack should increase aggression")
        XCTAssertGreaterThan(adjustment.stealBonus, 0, "Big stack should steal more")
        XCTAssertEqual(adjustment.description, "大筹码：利用筹码压力")
        
        print("✅ Big Stack Strategy Adjustment:")
        print("   VPIP: +\(String(format: "%.2f", adjustment.vpipAdjust))")
        print("   Aggression: +\(String(format: "%.2f", adjustment.aggressionAdjust))")
        print("   Steal: +\(String(format: "%.2f", adjustment.stealBonus))")
        print("   Description: \(adjustment.description)")
    }
    
    func testStrategyAdjustmentForMediumStack() {
        let situation = ICMSituation(
            isBubble: true,
            myChips: 1000,
            avgChips: 1000,
            stackRatio: 1.0,
            playersRemaining: 4,
            payoutSpots: 3
        )
        
        let adjustment = ICMCalculator.getStrategyAdjustment(situation: situation)
        
        XCTAssertLessThan(adjustment.vpipAdjust, 0, "Medium stack should tighten VPIP")
        XCTAssertLessThan(adjustment.aggressionAdjust, 0, "Medium stack should decrease aggression")
        XCTAssertLessThan(adjustment.stealBonus, 0, "Medium stack should steal less")
        XCTAssertEqual(adjustment.description, "中筹码：保守进钱圈")
        
        print("✅ Medium Stack Strategy Adjustment:")
        print("   VPIP: \(String(format: "%.2f", adjustment.vpipAdjust))")
        print("   Aggression: \(String(format: "%.2f", adjustment.aggressionAdjust))")
        print("   Steal: \(String(format: "%.2f", adjustment.stealBonus))")
        print("   Description: \(adjustment.description)")
    }
    
    func testStrategyAdjustmentForShortStack() {
        let situation = ICMSituation(
            isBubble: true,
            myChips: 400,
            avgChips: 1250,
            stackRatio: 0.32,
            playersRemaining: 4,
            payoutSpots: 3
        )
        
        let adjustment = ICMCalculator.getStrategyAdjustment(situation: situation)
        
        XCTAssertGreaterThan(adjustment.vpipAdjust, 0, "Short stack should widen VPIP (push-or-fold)")
        XCTAssertGreaterThan(adjustment.aggressionAdjust, 0, "Short stack should increase aggression")
        XCTAssertEqual(adjustment.stealBonus, 0.0, "Short stack should not steal (push-or-fold)")
        XCTAssertEqual(adjustment.description, "小筹码：Push-or-fold 策略")
        
        print("✅ Short Stack Strategy Adjustment:")
        print("   VPIP: +\(String(format: "%.2f", adjustment.vpipAdjust))")
        print("   Aggression: +\(String(format: "%.2f", adjustment.aggressionAdjust))")
        print("   Steal: \(String(format: "%.2f", adjustment.stealBonus))")
        print("   Description: \(adjustment.description)")
    }
    
    // MARK: - Test Real Tournament Scenarios
    
    func testFinalTableScenario() {
        // 9 players at final table, 6 paid
        let situation = ICMCalculator.analyze(
            myChips: 15000,
            allChips: [25000, 18000, 15000, 12000, 10000, 8000, 6000, 4000, 2000],
            payoutStructure: [0.35, 0.25, 0.15, 0.10, 0.08, 0.07]
        )
        
        XCTAssertFalse(situation.isBubble, "Not bubble yet with 9 players, 6 paid")
        XCTAssertEqual(situation.stackCategory, .medium)
        
        print("✅ Final Table Scenario:")
        print("   Players: \(situation.playersRemaining), Payouts: \(situation.payoutSpots)")
        print("   Stack: \(situation.stackCategory), Ratio: \(String(format: "%.2f", situation.stackRatio))x")
    }
    
    func testBubbleBoyScenario() {
        // 4 players, 3 paid, I'm the short stack
        let situation = ICMCalculator.analyze(
            myChips: 2000,
            allChips: [10000, 8000, 5000, 2000],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertTrue(situation.isBubble, "Should be bubble")
        XCTAssertEqual(situation.stackCategory, .short)
        
        let adjustment = ICMCalculator.getStrategyAdjustment(situation: situation)
        
        print("✅ Bubble Boy Scenario:")
        print("   Is Bubble: \(situation.isBubble)")
        print("   Stack: Short (\(String(format: "%.2f", situation.stackRatio))x avg)")
        print("   Strategy: \(adjustment.description)")
    }
    
    func testChipLeaderBubbleScenario() {
        // 4 players, 3 paid, I'm the chip leader
        let situation = ICMCalculator.analyze(
            myChips: 10000,
            allChips: [10000, 5000, 3000, 2000],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertTrue(situation.isBubble, "Should be bubble")
        XCTAssertEqual(situation.stackCategory, .big)
        
        let adjustment = ICMCalculator.getStrategyAdjustment(situation: situation)
        
        XCTAssertGreaterThan(adjustment.aggressionAdjust, 0, "Chip leader should be aggressive")
        
        print("✅ Chip Leader Bubble Scenario:")
        print("   Is Bubble: \(situation.isBubble)")
        print("   Stack: Big (\(String(format: "%.2f", situation.stackRatio))x avg)")
        print("   Strategy: \(adjustment.description)")
        print("   Aggression boost: +\(String(format: "%.2f", adjustment.aggressionAdjust))")
    }
    
    // MARK: - Test Edge Cases
    
    func testEqualStacks() {
        // All players have equal stacks
        let situation = ICMCalculator.analyze(
            myChips: 1000,
            allChips: [1000, 1000, 1000, 1000],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertEqual(situation.stackRatio, 1.0, "Equal stacks should have ratio 1.0")
        XCTAssertEqual(situation.stackCategory, .medium)
        
        print("✅ Equal Stacks Test:")
        print("   All stacks equal → Ratio 1.0, Category: Medium")
    }
    
    func testExtremeChipLeader() {
        // One player has 90% of chips
        let situation = ICMCalculator.analyze(
            myChips: 18000,
            allChips: [18000, 1000, 500, 500],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertEqual(situation.stackCategory, .big)
        XCTAssertGreaterThan(situation.stackRatio, 3.0, "Extreme chip leader should have ratio > 3x")
        
        print("✅ Extreme Chip Leader Test:")
        print("   90% of chips → Ratio \(String(format: "%.2f", situation.stackRatio))x")
    }
    
    func testMinimumChips() {
        // Player with minimum chips (1 chip)
        let situation = ICMCalculator.analyze(
            myChips: 1,
            allChips: [10000, 5000, 3000, 1],
            payoutStructure: [0.5, 0.3, 0.2]
        )
        
        XCTAssertEqual(situation.stackCategory, .short)
        XCTAssertLessThan(situation.stackRatio, 0.01, "1 chip should have very low ratio")
        
        print("✅ Minimum Chips Test:")
        print("   1 chip → Ratio \(String(format: "%.4f", situation.stackRatio))x")
    }
    
    // MARK: - Test Payout Structure Variations
    
    func testWinnerTakesAll() {
        let situation = ICMCalculator.analyze(
            myChips: 1500,
            allChips: [2000, 1500, 500],
            payoutStructure: [1.0]
        )
        
        XCTAssertEqual(situation.payoutSpots, 1)
        XCTAssertTrue(situation.isBubble, "2 players left, 1 paid → Bubble")
        
        print("✅ Winner Takes All Test:")
        print("   2 players, 1 paid → Bubble situation")
    }
    
    func testDeepPayoutStructure() {
        // 10 players, 5 paid
        let situation = ICMCalculator.analyze(
            myChips: 5000,
            allChips: [10000, 8000, 6000, 5000, 4000, 3000, 2500, 2000, 1500, 1000],
            payoutStructure: [0.30, 0.20, 0.15, 0.10, 0.05]
        )
        
        XCTAssertEqual(situation.payoutSpots, 5)
        XCTAssertFalse(situation.isBubble, "10 players, 5 paid → Not bubble yet")
        
        print("✅ Deep Payout Structure Test:")
        print("   10 players, 5 paid → Not bubble")
    }
}
