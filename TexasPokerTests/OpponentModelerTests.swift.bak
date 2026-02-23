import XCTest
@testable import TexasPoker

class OpponentModelerTests: XCTestCase {
    
    // MARK: - Test Style Classification
    
    func testClassifyRock() {
        // Rock: VPIP<20%, PFR<15%, AF>2.5
        let style = OpponentModeler.classifyStyle(vpip: 15, pfr: 12, af: 3.0)
        XCTAssertEqual(style, .rock, "Should classify as Rock with VPIP=15%, PFR=12%, AF=3.0")
        
        print("✅ Rock Classification Test: VPIP=15%, PFR=12%, AF=3.0 → \(style.description)")
    }
    
    func testClassifyFish() {
        // Fish: VPIP>45%, PFR<15%, AF<1.5
        let style = OpponentModeler.classifyStyle(vpip: 50, pfr: 8, af: 0.8)
        XCTAssertEqual(style, .fish, "Should classify as Fish with VPIP=50%, PFR=8%, AF=0.8")
        
        print("✅ Fish Classification Test: VPIP=50%, PFR=8%, AF=0.8 → \(style.description)")
    }
    
    func testClassifyLAG() {
        // LAG: VPIP 30-45%, PFR 25-35%, AF 3-4
        let style = OpponentModeler.classifyStyle(vpip: 35, pfr: 28, af: 3.5)
        XCTAssertEqual(style, .lag, "Should classify as LAG with VPIP=35%, PFR=28%, AF=3.5")
        
        print("✅ LAG Classification Test: VPIP=35%, PFR=28%, AF=3.5 → \(style.description)")
    }
    
    func testClassifyTAG() {
        // TAG: VPIP 20-30%, PFR 15-25%, AF 2-3
        let style = OpponentModeler.classifyStyle(vpip: 25, pfr: 20, af: 2.5)
        XCTAssertEqual(style, .tag, "Should classify as TAG with VPIP=25%, PFR=20%, AF=2.5")
        
        print("✅ TAG Classification Test: VPIP=25%, PFR=20%, AF=2.5 → \(style.description)")
    }
    
    func testClassifyUnknown() {
        // Unknown: No data
        let style = OpponentModeler.classifyStyle(vpip: 0, pfr: 0, af: 0)
        XCTAssertEqual(style, .unknown, "Should classify as Unknown with no data")
        
        print("✅ Unknown Classification Test: VPIP=0%, PFR=0%, AF=0 → \(style.description)")
    }
    
    // MARK: - Test Boundary Cases
    
    func testBoundaryRockToTAG() {
        // Boundary: VPIP=20% (edge of Rock/TAG)
        let style1 = OpponentModeler.classifyStyle(vpip: 19, pfr: 14, af: 2.6)
        let style2 = OpponentModeler.classifyStyle(vpip: 20, pfr: 15, af: 2.0)
        
        XCTAssertEqual(style1, .rock, "VPIP=19% should be Rock")
        XCTAssertEqual(style2, .tag, "VPIP=20% should be TAG")
        
        print("✅ Boundary Rock/TAG Test: 19% → Rock, 20% → TAG")
    }
    
    func testBoundaryTAGToLAG() {
        // Boundary: VPIP=30% (edge of TAG/LAG)
        let style1 = OpponentModeler.classifyStyle(vpip: 29, pfr: 24, af: 2.9)
        let style2 = OpponentModeler.classifyStyle(vpip: 30, pfr: 25, af: 3.0)
        
        XCTAssertEqual(style1, .tag, "VPIP=29% should be TAG")
        XCTAssertEqual(style2, .lag, "VPIP=30% should be LAG")
        
        print("✅ Boundary TAG/LAG Test: 29% → TAG, 30% → LAG")
    }
    
    func testBoundaryLAGToFish() {
        // Boundary: VPIP=45% (edge of LAG/Fish)
        let style1 = OpponentModeler.classifyStyle(vpip: 45, pfr: 35, af: 3.0)
        let style2 = OpponentModeler.classifyStyle(vpip: 46, pfr: 14, af: 1.4)
        
        XCTAssertEqual(style1, .lag, "VPIP=45% with high PFR should be LAG")
        XCTAssertEqual(style2, .fish, "VPIP=46% with low PFR should be Fish")
        
        print("✅ Boundary LAG/Fish Test: 45% (high PFR) → LAG, 46% (low PFR) → Fish")
    }
    
    func testEdgeCaseHighVPIPHighPFR() {
        // Edge case: Very loose and aggressive (but not LAG range)
        let style = OpponentModeler.classifyStyle(vpip: 50, pfr: 40, af: 4.0)
        
        // Should be classified as Fish based on VPIP > 40
        XCTAssertEqual(style, .fish, "VPIP=50% should be Fish regardless of high PFR")
        
        print("✅ Edge Case Test: VPIP=50%, PFR=40%, AF=4.0 → \(style.description)")
    }
    
    func testEdgeCaseLowVPIPLowAF() {
        // Edge case: Tight but passive
        let style = OpponentModeler.classifyStyle(vpip: 18, pfr: 10, af: 1.5)
        
        // Should be TAG based on VPIP < 25
        XCTAssertEqual(style, .tag, "VPIP=18% with low AF should default to TAG")
        
        print("✅ Edge Case Test: VPIP=18%, PFR=10%, AF=1.5 → \(style.description)")
    }
    
    // MARK: - Test Strategy Adjustments
    
    func testStrategyAdjustmentForRock() {
        let adjustment = OpponentModeler.getStrategyAdjustment(style: .rock)
        
        XCTAssertEqual(adjustment.stealFreqBonus, 0.30, "Rock: +30% steal frequency")
        XCTAssertEqual(adjustment.bluffFreqAdjust, -0.50, "Rock: -50% bluff frequency")
        XCTAssertEqual(adjustment.valueSizeAdjust, -0.25, "Rock: -25% value bet size")
        XCTAssertEqual(adjustment.callDownAdjust, -0.30, "Rock: -30% call down range")
        
        print("✅ Rock Strategy Adjustment:")
        print("   Steal: +\(adjustment.stealFreqBonus * 100)%")
        print("   Bluff: \(adjustment.bluffFreqAdjust * 100)%")
        print("   Value Size: \(adjustment.valueSizeAdjust * 100)%")
        print("   Call Down: \(adjustment.callDownAdjust * 100)%")
    }
    
    func testStrategyAdjustmentForTAG() {
        let adjustment = OpponentModeler.getStrategyAdjustment(style: .tag)
        
        XCTAssertEqual(adjustment.stealFreqBonus, 0.0, "TAG: No adjustments (balanced)")
        XCTAssertEqual(adjustment.bluffFreqAdjust, 0.0, "TAG: No adjustments (balanced)")
        XCTAssertEqual(adjustment.valueSizeAdjust, 0.0, "TAG: No adjustments (balanced)")
        XCTAssertEqual(adjustment.callDownAdjust, 0.0, "TAG: No adjustments (balanced)")
        
        print("✅ TAG Strategy Adjustment: All balanced (0.0)")
    }
    
    func testStrategyAdjustmentForLAG() {
        let adjustment = OpponentModeler.getStrategyAdjustment(style: .lag)
        
        XCTAssertEqual(adjustment.stealFreqBonus, -0.10, "LAG: -10% steal frequency")
        XCTAssertEqual(adjustment.bluffFreqAdjust, -0.30, "LAG: -30% bluff frequency")
        XCTAssertEqual(adjustment.valueSizeAdjust, 0.30, "LAG: +30% value bet size")
        XCTAssertEqual(adjustment.callDownAdjust, 0.20, "LAG: +20% call down range")
        
        print("✅ LAG Strategy Adjustment:")
        print("   Steal: \(adjustment.stealFreqBonus * 100)%")
        print("   Bluff: \(adjustment.bluffFreqAdjust * 100)%")
        print("   Value Size: +\(adjustment.valueSizeAdjust * 100)%")
        print("   Call Down: +\(adjustment.callDownAdjust * 100)%")
    }
    
    func testStrategyAdjustmentForFish() {
        let adjustment = OpponentModeler.getStrategyAdjustment(style: .fish)
        
        XCTAssertEqual(adjustment.stealFreqBonus, 0.0, "Fish: No steal adjustment")
        XCTAssertEqual(adjustment.bluffFreqAdjust, -0.70, "Fish: -70% bluff frequency")
        XCTAssertEqual(adjustment.valueSizeAdjust, 0.40, "Fish: +40% value bet size")
        XCTAssertEqual(adjustment.callDownAdjust, -0.20, "Fish: -20% call down range")
        
        print("✅ Fish Strategy Adjustment:")
        print("   Steal: \(adjustment.stealFreqBonus * 100)%")
        print("   Bluff: \(adjustment.bluffFreqAdjust * 100)%")
        print("   Value Size: +\(adjustment.valueSizeAdjust * 100)%")
        print("   Call Down: \(adjustment.callDownAdjust * 100)%")
    }
    
    func testStrategyAdjustmentForUnknown() {
        let adjustment = OpponentModeler.getStrategyAdjustment(style: .unknown)
        
        XCTAssertEqual(adjustment.stealFreqBonus, 0.0, "Unknown: No adjustments (balanced)")
        XCTAssertEqual(adjustment.bluffFreqAdjust, 0.0, "Unknown: No adjustments (balanced)")
        XCTAssertEqual(adjustment.valueSizeAdjust, 0.0, "Unknown: No adjustments (balanced)")
        XCTAssertEqual(adjustment.callDownAdjust, 0.0, "Unknown: No adjustments (balanced)")
        
        print("✅ Unknown Strategy Adjustment: All balanced (0.0)")
    }
    
    // MARK: - Test OpponentModel
    
    func testOpponentModelConfidence() {
        let model = OpponentModel(playerName: "Test Player", gameMode: .cashGame)
        
        // Test confidence scaling with sample size
        model.totalHands = 0
        XCTAssertEqual(model.confidence, 0.0, accuracy: 0.01, "0 hands → 0% confidence")
        
        model.totalHands = 25
        XCTAssertEqual(model.confidence, 0.5, accuracy: 0.01, "25 hands → 50% confidence")
        
        model.totalHands = 50
        XCTAssertEqual(model.confidence, 1.0, accuracy: 0.01, "50 hands → 100% confidence")
        
        model.totalHands = 100
        XCTAssertEqual(model.confidence, 1.0, accuracy: 0.01, "100 hands → 100% confidence (capped)")
        
        print("✅ Confidence Calculation Test:")
        print("   0 hands → 0% confidence")
        print("   25 hands → 50% confidence")
        print("   50+ hands → 100% confidence")
    }
    
    func testOpponentModelStyleUpdate() {
        let model = OpponentModel(playerName: "Test Player", gameMode: .cashGame)
        
        // With insufficient hands, should be unknown
        model.totalHands = 15
        model.vpip = 25
        model.pfr = 20
        model.af = 2.5
        model.updateStyle()
        XCTAssertEqual(model.style, .unknown, "< 20 hands should be unknown")
        
        // With sufficient hands, should classify correctly
        model.totalHands = 30
        model.updateStyle()
        XCTAssertEqual(model.style, .tag, "30 hands with TAG stats should be TAG")
        
        print("✅ Style Update Test:")
        print("   < 20 hands → Unknown")
        print("   30 hands with TAG stats → TAG")
    }
    
    // MARK: - Test All Player Styles
    
    func testAllPlayerStyleDescriptions() {
        let styles: [PlayerStyle] = [.rock, .tag, .lag, .fish, .unknown]
        
        for style in styles {
            XCTAssertFalse(style.description.isEmpty, "\(style) should have a description")
            print("   \(style.rawValue) → \(style.description)")
        }
        
        print("✅ All Player Style Descriptions Validated")
    }
}
