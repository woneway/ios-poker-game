import XCTest
@testable import TexasPoker

class UncalledBetTests: XCTestCase {
    
    func testReturnUncalledBets() {
        let engine = PokerEngine()
        
        // Setup players
        // Hero: 2658 (All-in)
        // Mike: 970 (All-in)
        // Amy: 398 (All-in)
        // Anna: 10 (Folded)
        // Fox: 20 (Folded)
        
        var hero = Player(name: "Hero", chips: 0, isHuman: false)
        hero.totalBetThisHand = 2658
        hero.currentBet = 2658
        hero.status = .allIn
        
        var mike = Player(name: "Mike", chips: 0, isHuman: false)
        mike.totalBetThisHand = 970
        mike.currentBet = 970
        mike.status = .allIn
        
        var amy = Player(name: "Amy", chips: 0, isHuman: false)
        amy.totalBetThisHand = 398
        amy.currentBet = 398
        amy.status = .allIn
        
        var anna = Player(name: "Anna", chips: 990, isHuman: false)
        anna.totalBetThisHand = 10
        anna.currentBet = 10
        anna.status = .folded
        
        var fox = Player(name: "Fox", chips: 980, isHuman: false)
        fox.totalBetThisHand = 20
        fox.currentBet = 20
        fox.status = .folded
        
        engine.players = [hero, mike, amy, anna, fox]
        
        // Pot total = 2658 + 970 + 398 + 10 + 20 = 4056
        engine.pot.reset()
        engine.pot.add(4056)
        
        // Run returnUncalledBets
        engine.returnUncalledBets()
        
        // Assertions
        // Hero should get back 2658 - 970 = 1688
        let updatedHero = engine.players[0]
        XCTAssertEqual(updatedHero.chips, 1688, "Hero should receive refund of 1688")
        XCTAssertEqual(updatedHero.totalBetThisHand, 970, "Hero's total bet should be reduced to match second highest (970)")
        
        // Pot should be reduced by 1688
        // 4056 - 1688 = 2368
        XCTAssertEqual(engine.pot.total, 2368, "Pot total should be reduced by refund amount")
        
        // Calculate pots
        engine.pot.calculatePots(players: engine.players)
        
        // Should have 2 pots now (Main + Side 1), not 3
        XCTAssertEqual(engine.pot.portions.count, 2, "Should have 2 pots (Main + Side 1)")
        
        // Main Pot (398 level): 398*3 + 10 + 20 = 1224
        XCTAssertEqual(engine.pot.portions[0].amount, 1224, "Main pot should be 1224")
        
        // Side Pot 1 (970 level): (970-398)*2 = 572*2 = 1144
        XCTAssertEqual(engine.pot.portions[1].amount, 1144, "Side pot 1 should be 1144")
    }
    
    func testReturnUncalledBets_FoldedPlayerHasMax() {
        // Case where folded player has max bet (e.g. they bet big then folded? No, they can't fold if they bet big unless they folded to a reraise).
        // Scenario:
        // A bets 1000.
        // B raises to 2000.
        // A folds.
        // B wins immediately? No, B gets 1000 back? No.
        // If A folds, B wins the pot (A's 1000 + B's 2000?). No.
        // If A folds, B wins A's 1000. B takes back his 2000?
        // No. If A bets 1000, B raises to 2000. A folds.
        // B wins the pot. The pot contains A's 1000. B's 2000 is returned?
        // B's 1000 (call) goes into pot. B's 1000 (raise) is uncalled.
        // So B gets 1000 back. Pot is 2000 (A's 1000 + B's 1000). B wins 2000.
        
        let engine = PokerEngine()
        
        var pA = Player(name: "A", chips: 1000, isHuman: false)
        pA.totalBetThisHand = 1000
        pA.status = .folded
        
        var pB = Player(name: "B", chips: 1000, isHuman: false)
        pB.totalBetThisHand = 2000
        pB.status = .active
        
        engine.players = [pA, pB]
        engine.pot.reset()
        engine.pot.add(3000)
        
        engine.returnUncalledBets()
        
        // B should get back 1000 (2000 - 1000)
        let updatedB = engine.players[1]
        XCTAssertEqual(updatedB.chips, 2000, "B should get 1000 back (start 1000 + refund 1000)") // Wait, start chips was 1000. He bet 2000 (so he had 3000?).
        // Let's say chips = remaining chips.
        // Start: A=2000, B=3000.
        // A bets 1000. Chips=1000.
        // B raises to 2000. Chips=1000.
        // A folds.
        // Pot = 3000.
        // Refund: B gets 1000 back. Chips=2000.
        // Pot = 2000.
        // B wins pot (2000). Total chips = 4000.
        // Net: A -1000. B +1000. Correct.
        
        XCTAssertEqual(updatedB.totalBetThisHand, 1000)
        XCTAssertEqual(engine.pot.total, 2000)
    }
}
