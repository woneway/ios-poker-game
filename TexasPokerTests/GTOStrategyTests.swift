import XCTest
@testable import TexasPoker

class GTOStrategyTests: XCTestCase {

    // MARK: - AIProfile Tests

    func testDifficultyLevel_GTOProfile() {
        let gtoProfile = AIProfile.academic
        XCTAssertEqual(gtoProfile.difficultyLevel, 4, "GTO profile should have difficulty level 4")
    }

    func testDifficultyLevel_Rock() {
        let rock = AIProfile.rock
        XCTAssertGreaterThanOrEqual(rock.difficultyLevel, 1, "Rock should have difficulty >= 1")
    }

    func testDifficultyLevel_Maniac() {
        let maniac = AIProfile.maniac
        XCTAssertGreaterThanOrEqual(maniac.difficultyLevel, 1, "Maniac should have difficulty >= 1")
    }

    func testGtoStrength_GTOProfile() {
        let gtoProfile = AIProfile.academic
        XCTAssertGreaterThan(gtoProfile.gtoStrength, 0, "GTO profile should have gtoStrength > 0")
    }

    func testGtoStrength_NonGTOProfile() {
        let rock = AIProfile.rock
        XCTAssertEqual(rock.gtoStrength, 0, "Non-GTO profile should have gtoStrength = 0")
    }

    func testDifficultyLevel_NonGTOProfiles() {
        let shark = AIProfile.shark
        let fox = AIProfile.fox
        XCTAssertGreaterThan(shark.difficultyLevel, 0)
        XCTAssertGreaterThan(fox.difficultyLevel, 0)
    }

    func testGtoStrength_DifferentProfiles() {
        let academic = AIProfile.academic
        let gtoMachine = AIProfile.gtoMachine
        let solver = AIProfile.solver

        XCTAssertGreaterThan(academic.gtoStrength, 0)
        XCTAssertGreaterThan(gtoMachine.gtoStrength, 0)
        XCTAssertGreaterThan(solver.gtoStrength, 0)
    }

    // MARK: - GTO Mixed Strategy Tests

    func testGtoMixedStrategy_HighStrength() {
        let optimal = PlayerAction.raise(100)
        let safe = PlayerAction.check

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
        let optimal = PlayerAction.raise(100)
        let safe = PlayerAction.check

        var safeCount = 0
        for _ in 0..<20 {
            let result = DecisionEngine.gtoMixedStrategy(
                optimalAction: optimal,
                safeAction: safe,
                gtoStrength: 0.5,
                equity: 0.2
            )
            if case .check = result {
                safeCount += 1
            }
        }

        XCTAssertGreaterThan(safeCount, 5, "Low equity should prefer safe action")
    }

    func testGtoMixedStrategy_MediumStrength() {
        let optimal = PlayerAction.raise(100)
        let safe = PlayerAction.call

        var raiseCount = 0
        var callCount = 0

        for _ in 0..<50 {
            let result = DecisionEngine.gtoMixedStrategy(
                optimalAction: optimal,
                safeAction: safe,
                gtoStrength: 0.5,
                equity: 0.6
            )
            if case .raise = result {
                raiseCount += 1
            } else if case .call = result {
                callCount += 1
            }
        }

        XCTAssertGreaterThan(raiseCount, 0, "Should sometimes raise")
        XCTAssertGreaterThan(callCount, 0, "Should sometimes call")
    }

    // MARK: - Multiway Adjustment Tests

    func testMultiwayAdjustment_HeadsUp() {
        let equity = DecisionEngine.multiwayAdjustment(
            playerCount: 2,
            baseEquity: 0.5,
            potOdds: 0.33
        )
        XCTAssertEqual(equity, 0.5, "Heads-up should not change equity")
    }

    func testMultiwayAdjustment_ThreePlayers() {
        let equity = DecisionEngine.multiwayAdjustment(
            playerCount: 3,
            baseEquity: 0.3,
            potOdds: 0.33
        )
        XCTAssertLessThan(equity, 0.3, "3-way pot should reduce equity")
    }

    func testMultiwayAdjustment_FourPlayers() {
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

    func testMultiwayAdjustment_FivePlayers() {
        let equity = DecisionEngine.multiwayAdjustment(
            playerCount: 5,
            baseEquity: 0.5,
            potOdds: 0.25
        )
        XCTAssertLessThan(equity, 0.5, "5-way pot should reduce equity significantly")
    }

    // MARK: - SPR Decision Tests

    func testSprBasedDecision_ShortStackAllIn() {
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

    func testSprBasedDecision_ShortStackFold() {
        let action = DecisionEngine.sprBasedDecision(
            spr: 0.5,
            equity: 0.2,
            potSize: 200,
            stackSize: 50,
            hasNutAdvantage: false,
            isMultiway: false
        )
        XCTAssertEqual(action, .fold, "Short stack with weak hand should fold")
    }

    func testSprBasedDecision_DeepStackCheck() {
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
        let action = DecisionEngine.sprBasedDecision(
            spr: 2.0,
            equity: 0.55,
            potSize: 100,
            stackSize: 200,
            hasNutAdvantage: false,
            isMultiway: true
        )

        if case .raise = action {
            XCTFail("Multiway with marginal equity should not raise")
        }
    }

    func testSprBasedDecision_DeepStackNutAdvantage() {
        let action = DecisionEngine.sprBasedDecision(
            spr: 15.0,
            equity: 0.55,
            potSize: 100,
            stackSize: 1500,
            hasNutAdvantage: true,
            isMultiway: false
        )
        if case .raise = action {
            XCTAssertTrue(true)
        } else {
            XCTFail("Deep stack with nut advantage should raise")
        }
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

    func testGTOOpeningRange_SB() {
        let range = RangeAnalyzer.gtoOpeningRange(position: .sb, tableSize: 8)
        XCTAssertGreaterThan(range.rangeWidth, 0.25, "SB should have wide opening range")
    }

    func testGTOOpeningRange_BB() {
        let range = RangeAnalyzer.gtoOpeningRange(position: .bb, tableSize: 8)
        XCTAssertGreaterThan(range.rangeWidth, 0.35, "BB should have widest range")
    }

    func testGTO3BetRange_IP() {
        let range = RangeAnalyzer.gto3BetRange(position: .btn, isIP: true)
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
        let mdf = DecisionEngine.calculateMDF(betSize: 50, potSize: 100)
        XCTAssertEqual(mdf, 2.0/3.0, accuracy: 0.01)
    }

    func testCalculateMDF_Overbet() {
        let mdf = DecisionEngine.calculateMDF(betSize: 150, potSize: 100)
        XCTAssertEqual(mdf, 0.4, accuracy: 0.01)
    }

    func testCalculateMDF_ZeroBet() {
        let mdf = DecisionEngine.calculateMDF(betSize: 0, potSize: 100)
        XCTAssertEqual(mdf, 1.0, "Zero bet should return 1.0")
    }

    // MARK: - Value to Bluff Ratio Tests

    func testValueToBluffRatio() {
        let ratio = DecisionEngine.calculateValueToBluffRatio(betSize: 50, potSize: 100)
        XCTAssertEqual(ratio, 0.5, accuracy: 0.01)
    }

    func testValueToBluffRatio_Overbet() {
        let ratio = DecisionEngine.calculateValueToBluffRatio(betSize: 150, potSize: 100)
        XCTAssertEqual(ratio, 1.5, accuracy: 0.01)
    }

    // MARK: - Call EV Tests

    func testCalculateCallEV() {
        let ev = DecisionEngine.calculateCallEV(equity: 0.5, potSize: 100, callAmount: 50)
        XCTAssertEqual(ev, 50.0, accuracy: 1.0)
    }

    func testCalculateCallEV_Profitable() {
        let ev = DecisionEngine.calculateCallEV(equity: 0.6, potSize: 100, callAmount: 30)
        XCTAssertGreaterThan(ev, 0, "Profitable call should have positive EV")
    }

    func testCalculateCallEV_Free() {
        let ev = DecisionEngine.calculateCallEV(equity: 0.5, potSize: 100, callAmount: 0)
        XCTAssertEqual(ev, 50.0, "Free card EV = equity * pot")
    }

    // MARK: - Raise EV Tests

    func testCalculateRaiseEV() {
        let ev = DecisionEngine.calculateRaiseEV(
            equity: 0.6,
            currentPot: 100,
            raiseSize: 50,
            opponentCallProb: 0.5
        )
        XCTAssertGreaterThan(ev, 0, "Value raise should be profitable")
    }

    // MARK: - Bet Size Tests

    func testGTOBetSize_Small() {
        let size = DecisionEngine.GTOBetSize.small.calculate(potSize: 150, bb: 10)
        XCTAssertEqual(size, 50, "Small bet = 1/3 pot")
    }

    func testGTOBetSize_Medium() {
        let size = DecisionEngine.GTOBetSize.medium.calculate(potSize: 150, bb: 10)
        XCTAssertEqual(size, 75, "Medium bet = 1/2 pot")
    }

    func testGTOBetSize_Large() {
        let size = DecisionEngine.GTOBetSize.large.calculate(potSize: 150, bb: 10)
        XCTAssertEqual(size, 100, "Large bet = 2/3 pot")
    }

    func testGTOBetSize_Overbet() {
        let size = DecisionEngine.GTOBetSize.overbet.calculate(potSize: 100, bb: 10)
        XCTAssertEqual(size, 100, "Overbet = pot size")
    }
}
