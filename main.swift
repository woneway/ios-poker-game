// 8-Player Texas Hold'em Logic Test
// Tests: card equality, hand evaluation, 8-player engine, AI decisions, full game simulation

import Foundation

var passCount = 0
var failCount = 0

func check(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition {
        passCount += 1
    } else {
        failCount += 1
        print("  ❌ FAIL [\(line)]: \(msg)")
    }
}

// ===== Test 1: Card Equality & Hashing =====
func testCardEquality() {
    print("Test 1: Card Equality & Hashing")
    let c1 = Card(rank: .ace, suit: .spades)
    let c2 = Card(rank: .ace, suit: .spades)
    let c3 = Card(rank: .ace, suit: .hearts)
    
    check(c1 == c2, "Same rank+suit should be equal")
    check(c1 != c3, "Different suit should not be equal")
    
    let set: Set<Card> = [c1, c2, c3]
    check(set.count == 2, "Set should have 2 unique cards, got \(set.count)")
    
    // Deck uniqueness
    let deck = Deck()
    check(deck.cards.count == 52, "Deck should have 52 cards")
    check(Set(deck.cards).count == 52, "All 52 cards should be unique")
    print("  ✅ Passed\n")
}

// ===== Test 2: HandEvaluator =====
func testHandEvaluator() {
    print("Test 2: HandEvaluator")
    
    // Straight Flush (A-K-Q-J-T suited)
    let sf = HandEvaluator.evaluate(
        holeCards: [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades)],
        communityCards: [Card(rank: .queen, suit: .spades), Card(rank: .jack, suit: .spades),
                         Card(rank: .ten, suit: .spades), Card(rank: .two, suit: .hearts),
                         Card(rank: .three, suit: .hearts)]
    )
    check(sf.0 == 8, "Royal flush = category 8, got \(sf.0)")
    
    // Four of a Kind
    let quads = HandEvaluator.evaluate(
        holeCards: [Card(rank: .ace, suit: .spades), Card(rank: .ace, suit: .hearts)],
        communityCards: [Card(rank: .ace, suit: .diamonds), Card(rank: .ace, suit: .clubs),
                         Card(rank: .king, suit: .spades), Card(rank: .two, suit: .hearts),
                         Card(rank: .three, suit: .hearts)]
    )
    check(quads.0 == 7, "Quads = category 7, got \(quads.0)")
    
    // Full House
    let fh = HandEvaluator.evaluate(
        holeCards: [Card(rank: .king, suit: .spades), Card(rank: .king, suit: .hearts)],
        communityCards: [Card(rank: .king, suit: .diamonds), Card(rank: .queen, suit: .clubs),
                         Card(rank: .queen, suit: .spades), Card(rank: .two, suit: .hearts),
                         Card(rank: .three, suit: .hearts)]
    )
    check(fh.0 == 6, "Full house = category 6, got \(fh.0)")
    
    // Wheel (A-2-3-4-5 straight)
    let wheel = HandEvaluator.evaluate(
        holeCards: [Card(rank: .ace, suit: .spades), Card(rank: .two, suit: .hearts)],
        communityCards: [Card(rank: .three, suit: .diamonds), Card(rank: .four, suit: .clubs),
                         Card(rank: .five, suit: .spades), Card(rank: .jack, suit: .hearts),
                         Card(rank: .king, suit: .diamonds)]
    )
    check(wheel.0 == 4, "Wheel = category 4 (straight), got \(wheel.0)")
    check(wheel.1 == [3], "Wheel kicker = [3] (5-high), got \(wheel.1)")
    
    // A-high straight beats Wheel
    let ahs = HandEvaluator.evaluate(
        holeCards: [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .hearts)],
        communityCards: [Card(rank: .queen, suit: .diamonds), Card(rank: .jack, suit: .clubs),
                         Card(rank: .ten, suit: .hearts), Card(rank: .two, suit: .clubs),
                         Card(rank: .three, suit: .clubs)]
    )
    check(ahs.0 == 4 && ahs.1[0] > wheel.1[0], "A-high straight beats wheel")
    
    // High Card
    let hc = HandEvaluator.evaluate(
        holeCards: [Card(rank: .ace, suit: .spades), Card(rank: .nine, suit: .hearts)],
        communityCards: [Card(rank: .two, suit: .diamonds), Card(rank: .four, suit: .clubs),
                         Card(rank: .six, suit: .hearts), Card(rank: .eight, suit: .clubs),
                         Card(rank: .king, suit: .diamonds)]
    )
    check(hc.0 == 0, "High card = category 0, got \(hc.0)")
    
    print("  ✅ Passed\n")
}

// ===== Test 3: Preflop Hand Strength =====
func testPreflopHandStrength() {
    print("Test 3: Preflop Hand Strength")
    
    let aa = DecisionEngine.preflopHandStrength([Card(rank: .ace, suit: .spades), Card(rank: .ace, suit: .hearts)])
    let kk = DecisionEngine.preflopHandStrength([Card(rank: .king, suit: .spades), Card(rank: .king, suit: .hearts)])
    let aks = DecisionEngine.preflopHandStrength([Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades)])
    let ako = DecisionEngine.preflopHandStrength([Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .hearts)])
    let s72o = DecisionEngine.preflopHandStrength([Card(rank: .seven, suit: .spades), Card(rank: .two, suit: .hearts)])
    
    check(aa > 0.90, "AA should be > 0.90, got \(String(format: "%.3f", aa))")
    check(kk > 0.85, "KK should be > 0.85, got \(String(format: "%.3f", kk))")
    check(aks > ako, "AKs should be > AKo, got \(String(format: "%.3f", aks)) vs \(String(format: "%.3f", ako))")
    check(aa > kk, "AA > KK: \(String(format: "%.3f", aa)) > \(String(format: "%.3f", kk))")
    check(kk > aks, "KK > AKs: \(String(format: "%.3f", kk)) > \(String(format: "%.3f", aks))")
    check(s72o < 0.35, "72o should be < 0.35, got \(String(format: "%.3f", s72o))")
    
    print("  Hand strengths: AA=\(String(format:"%.3f",aa)) KK=\(String(format:"%.3f",kk)) AKs=\(String(format:"%.3f",aks)) AKo=\(String(format:"%.3f",ako)) 72o=\(String(format:"%.3f",s72o))")
    print("  ✅ Passed\n")
}

// ===== Test 4: 8-Player Engine Setup =====
func testEngineSetup() {
    print("Test 4: 8-Player Engine Setup")
    
    let engine = PokerEngine()
    check(engine.players.count == 8, "Should have 8 players, got \(engine.players.count)")
    
    let human = engine.players.filter { $0.isHuman }
    check(human.count == 1, "Should have 1 human, got \(human.count)")
    
    let bots = engine.players.filter { !$0.isHuman }
    check(bots.count == 7, "Should have 7 bots, got \(bots.count)")
    
    // Each bot should have a unique AI profile
    let profileNames = bots.compactMap { $0.aiProfile?.name }
    check(Set(profileNames).count == 7, "All 7 bots should have unique profiles, got \(Set(profileNames).count): \(profileNames)")
    
    // Verify specific profiles
    check(profileNames.contains("石头"), "Should have Rock profile")
    check(profileNames.contains("疯子麦克"), "Should have Maniac profile")
    check(profileNames.contains("安娜"), "Should have Calling Station profile")
    check(profileNames.contains("老狐狸"), "Should have Fox profile")
    check(profileNames.contains("鲨鱼汤姆"), "Should have Shark profile")
    check(profileNames.contains("艾米"), "Should have Academic profile")
    check(profileNames.contains("大卫"), "Should have Tilt David profile")
    
    print("  ✅ Passed\n")
}

// ===== Test 5: Start Hand (blinds, dealing, positions) =====
func testStartHand() {
    print("Test 5: Start Hand")
    
    let engine = PokerEngine()
    engine.startHand()
    
    // All non-eliminated players should have 2 hole cards
    let activePlayers = engine.players.filter { $0.status == .active || $0.status == .allIn }
    for p in activePlayers {
        check(p.holeCards.count == 2, "\(p.name) should have 2 cards, got \(p.holeCards.count)")
    }
    
    // Pot should have blinds (10 + 20 = 30)
    check(engine.pot.total == 30, "Pot should be 30, got \(engine.pot.total)")
    
    // Current bet should be 20 (BB)
    check(engine.currentBet == 20, "Current bet should be 20, got \(engine.currentBet)")
    
    // Dealer index should be valid
    check(engine.dealerIndex >= 0 && engine.dealerIndex < 8, "Dealer index valid: \(engine.dealerIndex)")
    
    print("  Dealer: \(engine.players[engine.dealerIndex].name)")
    print("  ✅ Passed\n")
}

// ===== Test 6: Fold-to-Win =====
func testFoldToWin() {
    print("Test 6: Fold-to-Win")
    
    let engine = PokerEngine()
    engine.startHand()
    
    var foldCount = 0
    for _ in 0..<20 {
        if engine.isHandOver { break }
        let nonFolded = engine.players.filter { $0.status != .folded && $0.status != .eliminated }
        if nonFolded.count <= 1 { break }
        if engine.players[engine.activePlayerIndex].status == .active {
            engine.processAction(.fold)
            foldCount += 1
        }
    }
    
    check(engine.isHandOver, "Hand should be over")
    check(!engine.winners.isEmpty, "Should have a winner")
    
    let winner = engine.players.first { engine.winners.contains($0.id) }
    print("  Folded \(foldCount) times, winner: \(winner?.name ?? "?")")
    print("  ✅ Passed\n")
}

// ===== Test 7: AI Profile Behavior Differences =====
func testAIProfileDifferences() {
    print("Test 7: AI Profile Behavior Differences")
    
    // Simulate many decisions and track fold/call/raise rates per profile
    let profiles: [AIProfile] = [.rock, .maniac, .callingStation, .fox, .shark, .academic, .tiltDavid]
    
    for profile in profiles {
        var folds = 0, calls = 0, raises = 0
        let trials = 100
        
        for _ in 0..<trials {
            let engine = PokerEngine()
            engine.startHand()
            
            // Create a test scenario: player facing a raise of 60 (3x BB)
            let player = Player(name: "Test", chips: 1000, aiProfile: profile)
            var testPlayer = player
            testPlayer.holeCards = [
                Card(rank: .jack, suit: .spades),
                Card(rank: .ten, suit: .hearts)
            ]
            // Temporarily set engine state for decision
            let action = DecisionEngine.makeDecision(player: testPlayer, engine: engine)
            
            switch action {
            case .fold: folds += 1
            case .call, .check: calls += 1
            case .raise, .allIn: raises += 1
            }
        }
        
        let foldPct = folds * 100 / trials
        let callPct = calls * 100 / trials
        let raisePct = raises * 100 / trials
        
        print("  \(profile.name.padding(toLength: 8, withPad: " ", startingAt: 0)): Fold=\(foldPct)% Call=\(callPct)% Raise=\(raisePct)%")
    }
    
    // Check broad behavioral differences
    check(AIProfile.rock.tightness > AIProfile.maniac.tightness, "Rock tighter than Maniac")
    check(AIProfile.maniac.aggression > AIProfile.callingStation.aggression, "Maniac more aggressive than Station")
    check(AIProfile.shark.positionAwareness > AIProfile.callingStation.positionAwareness, "Shark more position-aware")
    check(AIProfile.tiltDavid.tiltSensitivity > AIProfile.fox.tiltSensitivity, "David more tilt-prone")
    
    print("  ✅ Passed\n")
}

// ===== Test 8: Full Game Simulation (multiple hands) =====
func testFullGameSimulation() {
    print("Test 8: Full 8-Player Game Simulation (10 hands)")
    
    let engine = PokerEngine()
    let handsToPlay = 10
    var handResults: [(Int, String, Int)] = [] // (hand#, winner, potSize)
    
    for h in 1...handsToPlay {
        engine.startHand()
        
        // Play until hand is over (with safety limit)
        var actionCount = 0
        let maxActions = 200
        
        while !engine.isHandOver && actionCount < maxActions {
            let player = engine.players[engine.activePlayerIndex]
            guard player.status == .active else {
                // Skip non-active (shouldn't happen but safety)
                break
            }
            
            let action: PlayerAction
            if player.isHuman {
                // Simulate human as a balanced player
                action = DecisionEngine.makeDecision(
                    player: player,
                    engine: engine
                )
            } else {
                action = DecisionEngine.makeDecision(
                    player: player,
                    engine: engine
                )
            }
            
            engine.processAction(action)
            actionCount += 1
        }
        
        let winner = engine.players.first { engine.winners.contains($0.id) }
        handResults.append((h, winner?.name ?? "?", engine.pot.total))
        
        check(engine.isHandOver, "Hand \(h) should complete")
    }
    
    // Print results summary
    print("  Results:")
    for r in handResults {
        print("    Hand \(r.0): \(r.1) won pot $\(r.2)")
    }
    
    // Check chip distribution (all chips should be accounted for)
    let totalChips = engine.players.reduce(0) { $0 + $1.chips }
    check(totalChips == 8000, "Total chips should be 8000 (8x1000), got \(totalChips)")
    
    // Print final standings
    print("  Final standings:")
    let sorted = engine.players.sorted { $0.chips > $1.chips }
    for (i, p) in sorted.enumerated() {
        let profile = p.aiProfile?.name ?? "Human"
        print("    \(i+1). \(p.name) [\(profile)]: $\(p.chips)")
    }
    
    // Check nobody has negative chips
    for p in engine.players {
        check(p.chips >= 0, "\(p.name) chips >= 0, got \(p.chips)")
    }
    
    print("  ✅ Passed\n")
}

// ===== Test 9: Monte Carlo with 8 players =====
func testMonteCarloMultiplayer() {
    print("Test 9: Monte Carlo (8-player equity)")
    
    let aa = [Card(rank: .ace, suit: .spades), Card(rank: .ace, suit: .hearts)]
    let eq8 = MonteCarloSimulator.calculateEquity(holeCards: aa, communityCards: [], playerCount: 8, iterations: 300)
    let eq2 = MonteCarloSimulator.calculateEquity(holeCards: aa, communityCards: [], playerCount: 2, iterations: 300)
    
    check(eq8 < eq2, "AA equity should be lower with more opponents: 8p=\(String(format:"%.3f",eq8)) < 2p=\(String(format:"%.3f",eq2))")
    check(eq8 > 0.25, "AA vs 7 opponents should still be > 0.25, got \(String(format:"%.3f",eq8))")
    
    print("  AA equity: 2p=\(String(format:"%.3f",eq2)) 8p=\(String(format:"%.3f",eq8))")
    print("  ✅ Passed\n")
}

// ===== Test 10: Tilt System =====
func testTiltSystem() {
    print("Test 10: Tilt System (David)")
    
    // David has high tilt sensitivity (0.85)
    var david = AIProfile.tiltDavid
    check(david.currentTilt == 0.0, "David starts with 0 tilt")
    check(david.tiltSensitivity == 0.85, "David tilt sensitivity = 0.85")
    
    // Simulate losing a big pot
    david.currentTilt = min(1.0, david.currentTilt + david.tiltSensitivity * 500.0 / 1000.0)
    check(david.currentTilt > 0.3, "After big loss, tilt > 0.3, got \(String(format:"%.2f", david.currentTilt))")
    
    // When tilted, David plays looser and more aggressive
    let normalTight = AIProfile.tiltDavid.effectiveTightness
    let tiltedTight = david.effectiveTightness
    check(tiltedTight < normalTight, "Tilted David is looser: \(String(format:"%.2f",tiltedTight)) < \(String(format:"%.2f",normalTight))")
    
    let normalAgg = AIProfile.tiltDavid.effectiveAggression
    let tiltedAgg = david.effectiveAggression
    check(tiltedAgg > normalAgg, "Tilted David is more aggressive: \(String(format:"%.2f",tiltedAgg)) > \(String(format:"%.2f",normalAgg))")
    
    print("  Normal: tight=\(String(format:"%.2f",normalTight)) agg=\(String(format:"%.2f",normalAgg))")
    print("  Tilted: tight=\(String(format:"%.2f",tiltedTight)) agg=\(String(format:"%.2f",tiltedAgg))")
    print("  ✅ Passed\n")
}

// ===== Run All Tests =====
print("🃏 Texas Hold'em 8-Player Logic Tests\n" + String(repeating: "=", count: 45) + "\n")

testCardEquality()
testHandEvaluator()
testPreflopHandStrength()
testEngineSetup()
testStartHand()
testFoldToWin()
testAIProfileDifferences()
testFullGameSimulation()
testMonteCarloMultiplayer()
testTiltSystem()

print(String(repeating: "=", count: 45))
if failCount == 0 {
    print("🎉 ALL \(passCount) checks PASSED!")
} else {
    print("⚠️  \(passCount) passed, \(failCount) FAILED")
}
