import XCTest
@testable import TexasPoker

class RangeAnalyzerTests: XCTestCase {
    
    // MARK: - Test Preflop Opening Ranges by Position
    
    func testUTGOpenRange() {
        let range = RangeAnalyzer.estimateRange(
            position: .utg,
            action: .raise,
            facingRaise: false
        )
        
        XCTAssertEqual(range.position, .utg)
        XCTAssertEqual(range.action, .raise)
        XCTAssertEqual(range.rangeWidth, 0.30, accuracy: 0.05, "UTG should open ~14% of hands")
        XCTAssertTrue(range.description.contains("UTG"), "Description should mention position")
        
        print("✅ UTG Open Range: \(String(format: "%.1f%%", range.rangeWidth * 100))")
        print("   Description: \(range.description)")
    }
    
    func testUTGPlus1OpenRange() {
        let range = RangeAnalyzer.estimateRange(
            position: .utgPlus1,
            action: .raise,
            facingRaise: false
        )
        
        XCTAssertEqual(range.rangeWidth, 0.35, accuracy: 0.05, "UTG+1 should open ~17% of hands")
        
        print("✅ UTG+1 Open Range: \(String(format: "%.1f%%", range.rangeWidth * 100))")
    }
    
    func testMPOpenRange() {
        let range = RangeAnalyzer.estimateRange(
            position: .mp,
            action: .raise,
            facingRaise: false
        )
        
        XCTAssertEqual(range.rangeWidth, 0.40, accuracy: 0.05, "MP should open ~20% of hands")
        
        print("✅ MP Open Range: \(String(format: "%.1f%%", range.rangeWidth * 100))")
    }
    
    func testHJOpenRange() {
        let range = RangeAnalyzer.estimateRange(
            position: .hj,
            action: .raise,
            facingRaise: false
        )
        
        XCTAssertEqual(range.rangeWidth, 0.50, accuracy: 0.05, "HJ should open ~25% of hands")
        
        print("✅ HJ Open Range: \(String(format: "%.1f%%", range.rangeWidth * 100))")
    }
    
    func testCOOpenRange() {
        let range = RangeAnalyzer.estimateRange(
            position: .co,
            action: .raise,
            facingRaise: false
        )
        
        XCTAssertEqual(range.rangeWidth, 0.60, accuracy: 0.05, "CO should open ~30% of hands")
        
        print("✅ CO Open Range: \(String(format: "%.1f%%", range.rangeWidth * 100))")
    }
    
    func testBTNOpenRange() {
        let range = RangeAnalyzer.estimateRange(
            position: .btn,
            action: .raise,
            facingRaise: false
        )
        
        XCTAssertEqual(range.rangeWidth, 0.70, accuracy: 0.05, "BTN should open ~42% of hands")
        
        print("✅ BTN Open Range: \(String(format: "%.1f%%", range.rangeWidth * 100))")
    }
    
    func testSBOpenRange() {
        let range = RangeAnalyzer.estimateRange(
            position: .sb,
            action: .raise,
            facingRaise: false
        )
        
        XCTAssertEqual(range.rangeWidth, 0.55, accuracy: 0.05, "SB should open ~30% of hands")
        
        print("✅ SB Open Range: \(String(format: "%.1f%%", range.rangeWidth * 100))")
    }
    
    func testBBDefendRange() {
        let range = RangeAnalyzer.estimateRange(
            position: .bb,
            action: .raise,
            facingRaise: false
        )
        
        XCTAssertEqual(range.rangeWidth, 0.80, accuracy: 0.05, "BB should defend ~45% of hands")
        
        print("✅ BB Defend Range: \(String(format: "%.1f%%", range.rangeWidth * 100))")
    }
    
    // MARK: - Test 3-bet and 4-bet Ranges
    
    func testThreeBetRange() {
        let range = RangeAnalyzer.estimateRange(
            position: .co,
            action: .threebet,
            facingRaise: true
        )
        
        XCTAssertEqual(range.action, .threebet)
        XCTAssertEqual(range.rangeWidth, 0.15, "3-bet range should be ~15%")
        XCTAssertTrue(range.description.contains("3-bet"), "Description should mention 3-bet")
        XCTAssertTrue(range.description.contains("JJ+") || range.description.contains("AQ"), 
                     "Description should mention premium hands")
        
        print("✅ 3-bet Range: \(String(format: "%.1f%%", range.rangeWidth * 100))")
        print("   Description: \(range.description)")
    }
    
    func testFourBetRange() {
        let range = RangeAnalyzer.estimateRange(
            position: .btn,
            action: .fourbet,
            facingRaise: true
        )
        
        XCTAssertEqual(range.action, .fourbet)
        XCTAssertEqual(range.rangeWidth, 0.05, "4-bet range should be ~5%")
        XCTAssertTrue(range.description.contains("4-bet"), "Description should mention 4-bet")
        XCTAssertTrue(range.description.contains("QQ+") || range.description.contains("AK"), 
                     "Description should mention super premium hands")
        
        print("✅ 4-bet Range: \(String(format: "%.1f%%", range.rangeWidth * 100))")
        print("   Description: \(range.description)")
    }
    
    func testCallRange() {
        let rangeNoRaise = RangeAnalyzer.estimateRange(
            position: .mp,
            action: .call,
            facingRaise: false
        )
        
        let rangeFacingRaise = RangeAnalyzer.estimateRange(
            position: .mp,
            action: .call,
            facingRaise: true
        )
        
        XCTAssertEqual(rangeNoRaise.rangeWidth, 0.25, "Limp range should be ~25%")
        XCTAssertEqual(rangeFacingRaise.rangeWidth, 0.15, "Call range facing raise should be ~15%")
        XCTAssertLessThan(rangeFacingRaise.rangeWidth, rangeNoRaise.rangeWidth, 
                         "Call range should narrow when facing raise")
        
        print("✅ Call Range:")
        print("   No raise: \(String(format: "%.1f%%", rangeNoRaise.rangeWidth * 100))")
        print("   Facing raise: \(String(format: "%.1f%%", rangeFacingRaise.rangeWidth * 100))")
    }
    
    func testFoldRange() {
        let range = RangeAnalyzer.estimateRange(
            position: .utg,
            action: .fold,
            facingRaise: false
        )
        
        XCTAssertEqual(range.rangeWidth, 0.0, "Fold range should be 0%")
        XCTAssertEqual(range.description, "已弃牌")
        
        print("✅ Fold Range: 0% (已弃牌)")
    }
    
    // MARK: - Test Postflop Range Narrowing
    
    func testRangeNarrowingOnCheck() {
        var range = RangeAnalyzer.estimateRange(
            position: .btn,
            action: .raise,
            facingRaise: false
        )
        let originalWidth = range.rangeWidth
        
        let board = BoardTexture(
            wetness: 0.5,
            isPaired: false,
            isMonotone: false,
            isTwoTone: true,
            hasHighCards: true,
            connectivity: 0.6
        )
        
        RangeAnalyzer.narrowRange(range: &range, action: .check, board: board)
        
        XCTAssertLessThan(range.rangeWidth, originalWidth, "Check should narrow range")
        XCTAssertEqual(range.rangeWidth, originalWidth * 0.70, accuracy: 0.01, 
                      "Check should narrow range by 30%")
        XCTAssertTrue(range.description.contains("Check"), "Description should mention check")
        
        print("✅ Range Narrowing on Check:")
        print("   Original: \(String(format: "%.1f%%", originalWidth * 100))")
        print("   After check: \(String(format: "%.1f%%", range.rangeWidth * 100))")
        print("   Narrowed by: \(String(format: "%.1f%%", (1 - range.rangeWidth / originalWidth) * 100))")
    }
    
    func testRangeNarrowingOnBetWetBoard() {
        var range = RangeAnalyzer.estimateRange(
            position: .co,
            action: .raise,
            facingRaise: false
        )
        let originalWidth = range.rangeWidth
        
        let wetBoard = BoardTexture(
            wetness: 0.8,
            isPaired: false,
            isMonotone: true,
            isTwoTone: false,
            hasHighCards: true,
            connectivity: 0.7
        )
        
        RangeAnalyzer.narrowRange(range: &range, action: .bet, board: wetBoard)
        
        XCTAssertLessThan(range.rangeWidth, originalWidth, "Bet should narrow range")
        XCTAssertEqual(range.rangeWidth, originalWidth * 0.85, accuracy: 0.01, 
                      "Bet on wet board should narrow range by 15%")
        XCTAssertTrue(range.description.contains("wet board"), "Description should mention wet board")
        
        print("✅ Range Narrowing on Bet (Wet Board):")
        print("   Original: \(String(format: "%.1f%%", originalWidth * 100))")
        print("   After bet: \(String(format: "%.1f%%", range.rangeWidth * 100))")
    }
    
    func testRangeNarrowingOnBetDryBoard() {
        var range = RangeAnalyzer.estimateRange(
            position: .co,
            action: .raise,
            facingRaise: false
        )
        let originalWidth = range.rangeWidth
        
        let dryBoard = BoardTexture(
            wetness: 0.2,
            isPaired: false,
            isMonotone: false,
            isTwoTone: false,
            hasHighCards: false,
            connectivity: 0.1
        )
        
        RangeAnalyzer.narrowRange(range: &range, action: .bet, board: dryBoard)
        
        XCTAssertLessThan(range.rangeWidth, originalWidth, "Bet should narrow range")
        XCTAssertEqual(range.rangeWidth, originalWidth * 0.95, accuracy: 0.01, 
                      "Bet on dry board should narrow range by 5%")
        XCTAssertTrue(range.description.contains("dry board"), "Description should mention dry board")
        
        print("✅ Range Narrowing on Bet (Dry Board):")
        print("   Original: \(String(format: "%.1f%%", originalWidth * 100))")
        print("   After bet: \(String(format: "%.1f%%", range.rangeWidth * 100))")
    }
    
    func testRangeNarrowingOnRaise() {
        var range = RangeAnalyzer.estimateRange(
            position: .mp,
            action: .raise,
            facingRaise: false
        )
        let originalWidth = range.rangeWidth
        
        let board = BoardTexture(
            wetness: 0.5,
            isPaired: false,
            isMonotone: false,
            isTwoTone: true,
            hasHighCards: true,
            connectivity: 0.5
        )
        
        RangeAnalyzer.narrowRange(range: &range, action: .raise, board: board)
        
        XCTAssertLessThan(range.rangeWidth, originalWidth, "Raise should narrow range significantly")
        XCTAssertEqual(range.rangeWidth, originalWidth * 0.50, accuracy: 0.01, 
                      "Raise should narrow range by 50%")
        XCTAssertTrue(range.description.contains("Raise"), "Description should mention raise")
        
        print("✅ Range Narrowing on Raise:")
        print("   Original: \(String(format: "%.1f%%", originalWidth * 100))")
        print("   After raise: \(String(format: "%.1f%%", range.rangeWidth * 100))")
    }
    
    func testRangeNarrowingOnCall() {
        var range = RangeAnalyzer.estimateRange(
            position: .hj,
            action: .raise,
            facingRaise: false
        )
        let originalWidth = range.rangeWidth
        
        let board = BoardTexture(
            wetness: 0.6,
            isPaired: false,
            isMonotone: false,
            isTwoTone: true,
            hasHighCards: true,
            connectivity: 0.6
        )
        
        RangeAnalyzer.narrowRange(range: &range, action: .call, board: board)
        
        XCTAssertLessThan(range.rangeWidth, originalWidth, "Call should narrow range")
        XCTAssertEqual(range.rangeWidth, originalWidth * 0.75, accuracy: 0.01, 
                      "Call should narrow range by 25%")
        XCTAssertTrue(range.description.contains("Call"), "Description should mention call")
        
        print("✅ Range Narrowing on Call:")
        print("   Original: \(String(format: "%.1f%%", originalWidth * 100))")
        print("   After call: \(String(format: "%.1f%%", range.rangeWidth * 100))")
    }
    
    func testRangeNarrowingOnFold() {
        var range = RangeAnalyzer.estimateRange(
            position: .btn,
            action: .raise,
            facingRaise: false
        )
        
        let board = BoardTexture(
            wetness: 0.5,
            isPaired: false,
            isMonotone: false,
            isTwoTone: false,
            hasHighCards: false,
            connectivity: 0.5
        )
        
        RangeAnalyzer.narrowRange(range: &range, action: .fold, board: board)
        
        XCTAssertEqual(range.rangeWidth, 0.0, "Fold should result in 0% range")
        XCTAssertEqual(range.description, "已弃牌")
        
        print("✅ Range Narrowing on Fold: 0% (已弃牌)")
    }
    
    // MARK: - Test Range Width Calculations
    
    func testRangeWidthProgression() {
        // Test that ranges get tighter from late to early position
        let positions: [Position] = [.btn, .co, .hj, .mp, .utgPlus1, .utg]
        var previousWidth = 1.0
        
        for position in positions {
            let range = RangeAnalyzer.estimateRange(
                position: position,
                action: .raise,
                facingRaise: false
            )
            
            XCTAssertLessThan(range.rangeWidth, previousWidth, 
                            "\(position.rawValue) should be tighter than previous position")
            previousWidth = range.rangeWidth
            
            print("   \(position.rawValue.uppercased()): \(String(format: "%.1f%%", range.rangeWidth * 100))")
        }
        
        print("✅ Range Width Progression Test: Ranges get tighter from BTN to UTG")
    }
    
    func testActionRangeProgression() {
        // Test that ranges get tighter with more aggressive actions
        let position = Position.co
        
        let raiseRange = RangeAnalyzer.estimateRange(position: position, action: .raise, facingRaise: false)
        let threebetRange = RangeAnalyzer.estimateRange(position: position, action: .threebet, facingRaise: true)
        let fourbetRange = RangeAnalyzer.estimateRange(position: position, action: .fourbet, facingRaise: true)
        
        XCTAssertGreaterThan(raiseRange.rangeWidth, threebetRange.rangeWidth, 
                            "Raise range should be wider than 3-bet range")
        XCTAssertGreaterThan(threebetRange.rangeWidth, fourbetRange.rangeWidth, 
                            "3-bet range should be wider than 4-bet range")
        
        print("✅ Action Range Progression Test:")
        print("   Raise: \(String(format: "%.1f%%", raiseRange.rangeWidth * 100))")
        print("   3-bet: \(String(format: "%.1f%%", threebetRange.rangeWidth * 100))")
        print("   4-bet: \(String(format: "%.1f%%", fourbetRange.rangeWidth * 100))")
    }
    
    // MARK: - Test Position Conversion
    
    func testPositionFromSeatOffset() {
        XCTAssertEqual(Position.from(seatOffset: 0), .btn)
        XCTAssertEqual(Position.from(seatOffset: 1), .sb)
        XCTAssertEqual(Position.from(seatOffset: 2), .bb)
        XCTAssertEqual(Position.from(seatOffset: 3), .utg)
        XCTAssertEqual(Position.from(seatOffset: 4), .utgPlus1)
        XCTAssertEqual(Position.from(seatOffset: 5), .mp)
        XCTAssertEqual(Position.from(seatOffset: 6), .hj)
        XCTAssertEqual(Position.from(seatOffset: 7), .co)
        
        print("✅ Position Conversion Test: All seat offsets map correctly")
    }
    
    func testPositionSeatOffset() {
        XCTAssertEqual(Position.btn.seatOffset, 0)
        XCTAssertEqual(Position.sb.seatOffset, 1)
        XCTAssertEqual(Position.bb.seatOffset, 2)
        XCTAssertEqual(Position.utg.seatOffset, 3)
        
        print("✅ Position Seat Offset Test: All positions have correct offsets")
    }
}
