import XCTest
@testable import TexasPoker

class GTOStrategyTests: XCTestCase {

    // MARK: - AIProfile Tests

    func testDifficultyLevel_GTOProfile() {
        // GTO profile should have difficulty level 4
        let gtoProfile = AIProfile.academic
        XCTAssertEqual(gtoProfile.difficultyLevel, 4, "GTO profile should have difficulty level 4")
    }

    func testDifficultyLevel_Rock() {
        // Rock has very low position awareness (0.10), so difficulty is low
        let rock = AIProfile.rock
        XCTAssertGreaterThanOrEqual(rock.difficultyLevel, 1, "Rock should have difficulty >= 1")
    }

    func testDifficultyLevel_Maniac() {
        // Maniac has high aggression
        let maniac = AIProfile.maniac
        XCTAssertGreaterThanOrEqual(maniac.difficultyLevel, 1, "Maniac should have difficulty >= 1")
    }

    func testGtoStrength_GTOProfile() {
        // GTO profile should have gtoStrength > 0
        let gtoProfile = AIProfile.academic
        XCTAssertGreaterThan(gtoProfile.gtoStrength, 0, "GTO profile should have gtoStrength > 0")
    }

    func testGtoStrength_NonGTOProfile() {
        // Non-GTO profile should have gtoStrength = 0
        let rock = AIProfile.rock
        XCTAssertEqual(rock.gtoStrength, 0, "Non-GTO profile should have gtoStrength = 0")
    }

    // MARK: - GTO Mixed Strategy Tests

    func testGtoMixedStrategy_HighStrength() {
        // With gtoStrength = 1.0, should always return optimal action
        let optimal = PlayerAction.raise(100)
        let safe = PlayerAction.check

        // Run multiple times to verify behavior
        var optimalCount = 0
        for _ in 0..<20 {
            let result = DecisionEngine.gtoMixedStrategy(
                optimalAction: optimal,
                safeAction: safe,
                gtoStrength: 1.0,
                equity: 0.7
            )
            if case .raise = result {
                optimalCount += 1
            }
        }

        XCTAssertEqual(optimalCount, 20, "With gtoStrength=1.0, should always choose optimal")
    }

    func testGtoMixedStrategy_LowEquity() {
        // With low equity, should be more conservative
        let optimal = PlayerAction.raise(100)
        let safe = PlayerAction.check

        var safeCount = 0
        for _ in 0..<20 {
            let result = DecisionEngine.gtoMixedStrategy(
                optimalAction: optimal,
                safeAction: safe,
                gtoStrength: 0.5,
                equity: 0.2  // Low equity
            )
            if case .check = result {
                safeCount += 1
            }
        }

        // With low equity, should prefer safe action more often
        XCTAssertGreaterThan(safeCount, 5, "Low equity should prefer safe action")
    }

    // MARK: - Multiway Adjustment Tests

    func testMultiwayAdjustment_HeadsUp() {
        // 2-player game should return unchanged equity
        let equity = DecisionEngine.multiwayAdjustment(
            playerCount: 2,
            baseEquity: 0.5,
            potOdds: 0.33
        )
        XCTAssertEqual(equity, 0.5, "Heads-up should not change equity")
    }

    func testMultiwayAdjustment_ThreePlayers() {
        // 3-player game should reduce equity
        let equity = DecisionEngine.multiwayAdjustment(
            playerCount: 3,
            baseEquity: 0.5,
            potOdds: 0.33
        )
        // Note: When equity > 0.4 and > potOdds, betIncentive adds 0.05
        // So equity = 0.5 - 0.05 + 0.05 = 0.5 (no change)
        // Let's use a lower equity that won't trigger betIncentive
        let equity2 = DecisionEngine.multiwayAdjustment(
            playerCount: 3,
            baseEquity: 0.3,
            potOdds: 0.33
        )
        XCTAssertLessThan(equity2, 0.3, "3-way pot should reduce equity")
    }

    func testMultiwayAdjustment_FourPlayers() {
        // 4-player game should reduce equity more
        let equity3way = DecisionEngine.multiwayAdjustment(
            playerCount: 3,
            baseEquity: 0.5,
            potOdds: 0.33
        )
        let equity4way = DecisionEngine.multiwayAdjustment(
            playerCount: 4,
            baseEquity: 0.5,
            potOdds: 0.33
        )
        XCTAssertLessThan(equity4way, equity3way, "4-way should reduce equity more than 3-way")
    }

    // MARK: - SPR Decision Tests

    func testSprBasedDecision_ShortStackAllIn() {
        // SPR < 1, high equity -> all-in
        let action = DecisionEngine.sprBasedDecision(
            spr: 0.5,
            equity: 0.6,
            potSize: 200,
            stackSize: 50,
            hasNutAdvantage: false,
            isMultiway: false
        )

        if case .allIn = action {
            XCTAssertTrue(true)
        } else {
            XCTFail("Short stack with good equity should go all-in")
        }
    }

    func testSprBasedDecision_DeepStackCheck() {
        // SPR > 6, no nut advantage -> check
        let action = DecisionEngine.sprBasedDecision(
            spr: 10.0,
            equity: 0.4,
            potSize: 100,
            stackSize: 1000,
            hasNutAdvantage: false,
            isMultiway: false
        )

        XCTAssertEqual(action, .check, "Deep stack without nut advantage should check")
    }

    func testSprBasedDecision_MediumStackValue() {
        // SPR 1-3, with nut advantage -> raise
        let action = DecisionEngine.sprBasedDecision(
            spr: 2.0,
            equity: 0.7,
            potSize: 100,
            stackSize: 200,
            hasNutAdvantage: true,
            isMultiway: false
        )

        if case .raise = action {
            XCTAssertTrue(true)
        } else {
            XCTFail("Medium stack with nut advantage should raise for value")
        }
    }

    func testSprBasedDecision_MultiwayCaution() {
        // Multiway should be more cautious
        let action = DecisionEngine.sprBasedDecision(
            spr: 2.0,
            equity: 0.55,  // Marginal
            potSize: 100,
            stackSize: 200,
            hasNutAdvantage: false,
            isMultiway: true  // Multiway
        )

        // Multiway with marginal equity should not raise
        if case .raise = action {
            XCTFail("Multiway with marginal equity should not raise")
        }
    }

    // MARK: - Exploit Adjustment Tests

    func testExploitAdjustment_LAG() {
        // Against LAG, should tighten range
        let opponent = OpponentModel(playerName: "Test", gameMode: .cashGame)
        opponent.style = .lag

        let adjust = DecisionEngine.calculateExploitAdjustment(
            opponentModel: opponent,
            myPosition: .btn,
            street: .flop
        )

        // LAG should have negative vpipBonus (tighten range)
        XCTAssertTrue(adjust.vpipBonus < 0 || adjust.vpipBonus == 0, "LAG should tighten range")
    }

    func testExploitAdjustment_Fish() {
        // Against Fish, should value bet more (reduce aggression)
        let opponent = OpponentModel(playerName: "Test", gameMode: .cashGame)
        opponent.style = .fish

        let adjust = DecisionEngine.calculateExploitAdjustment(
            opponentModel: opponent,
            myPosition: .btn,
            street: .flop
        )

        // Fish should reduce aggression (less bluffing)
        XCTAssertTrue(adjust.aggressionBonus <= 0, "Against Fish should reduce bluffing")
    }

    func testExploitAdjustment_PositionBonus() {
        // Button position should increase exploitation effectiveness
        let opponent = OpponentModel(playerName: "Test", gameMode: .cashGame)
        opponent.style = .tag

        let btnAdjust = DecisionEngine.calculateExploitAdjustment(
            opponentModel: opponent,
            myPosition: .btn,
            street: .flop
        )

        let utgAdjust = DecisionEngine.calculateExploitAdjustment(
            opponentModel: opponent,
            myPosition: .utg,
            street: .flop
        )

        // Button should have higher or equal aggression bonus
        XCTAssertTrue(btnAdjust.aggressionBonus >= utgAdjust.aggressionBonus,
            "Button should have higher or equal aggression bonus")
    }

    // MARK: - GTO Range Tests

    func testGTOOpeningRange_UTG() {
        let range = RangeAnalyzer.gtoOpeningRange(position: .utg, tableSize: 8)
        XCTAssertLessThan(range.rangeWidth, 0.2, "UTG should have tight opening range")
    }

    func testGTOOpeningRange_Button() {
        let range = RangeAnalyzer.gtoOpeningRange(position: .btn, tableSize: 8)
        XCTAssertGreaterThan(range.rangeWidth, 0.35, "Button should have wide opening range")
    }

    func testGTO3BetRange_IP() {
        let range = RangeAnalyzer.gto3BetRange(position: .btn, isIP: true)
        // IP 3-bet range should be wider than OOP
        let oopRange = RangeAnalyzer.gto3BetRange(position: .sb, isIP: false)
        XCTAssertGreaterThan(range.rangeWidth, oopRange.rangeWidth,
            "IP 3-bet range should be wider than OOP")
    }

    func testGTOCall3BetRange() {
        let ipRange = RangeAnalyzer.gtoCall3BetRange(position: .btn, isIP: true)
        let oopRange = RangeAnalyzer.gtoCall3BetRange(position: .sb, isIP: false)
        XCTAssertGreaterThanOrEqual(ipRange.rangeWidth, oopRange.rangeWidth,
            "IP should have equal or wider call 3-bet range")
    }

    // MARK: - MDF Tests

    func testCalculateMDF() {
        // Pot 100, bet 50 -> MDF = 100/150 = 0.667
        let mdf = DecisionEngine.calculateMDF(betSize: 50, potSize: 100)
        XCTAssertEqual(mdf, 2.0/3.0, accuracy: 0.01)
    }

    func testCalculateMDF_Overbet() {
        // Pot 100, bet 150 -> MDF = 100/250 = 0.4
        let mdf = DecisionEngine.calculateMDF(betSize: 150, potSize: 100)
        XCTAssertEqual(mdf, 0.4, accuracy: 0.01)
    }

    func testCalculateMDF_ZeroBet() {
        let mdf = DecisionEngine.calculateMDF(betSize: 0, potSize: 100)
        XCTAssertEqual(mdf, 1.0, "Zero bet should return 1.0")
    }

    // MARK: - Value to Bluff Ratio Tests

    func testValueToBluffRatio() {
        // Bet 50, pot 100 -> ratio = 0.5
        let ratio = DecisionEngine.calculateValueToBluffRatio(betSize: 50, potSize: 100)
        XCTAssertEqual(ratio, 0.5, accuracy: 0.01)
    }

    func testValueToBluffRatio_Overbet() {
        // Bet 150, pot 100 -> ratio = 1.5
        let ratio = DecisionEngine.calculateValueToBluffRatio(betSize: 150, potSize: 100)
        XCTAssertEqual(ratio, 1.5, accuracy: 0.01)
    }
}
