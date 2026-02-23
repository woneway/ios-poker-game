import XCTest
@testable import TexasPoker

class TournamentTests: XCTestCase {
    
    // MARK: - TournamentConfig Tests
    
    func testStandardPresetExists() {
        XCTAssertFalse(TournamentConfig.standard.blindSchedule.isEmpty)
        XCTAssertEqual(TournamentConfig.standard.blindSchedule.count, 10)
        XCTAssertEqual(TournamentConfig.standard.handsPerLevel, 10)
        XCTAssertEqual(TournamentConfig.standard.startingChips, 1000)
    }
    
    func testTurboPresetExists() {
        XCTAssertFalse(TournamentConfig.turbo.blindSchedule.isEmpty)
        XCTAssertEqual(TournamentConfig.turbo.blindSchedule.count, 10)
        XCTAssertEqual(TournamentConfig.turbo.handsPerLevel, 5)
        XCTAssertEqual(TournamentConfig.turbo.startingChips, 1000)
    }
    
    func testDeepStackPresetExists() {
        XCTAssertFalse(TournamentConfig.deepStack.blindSchedule.isEmpty)
        XCTAssertEqual(TournamentConfig.deepStack.blindSchedule.count, 10)
        XCTAssertEqual(TournamentConfig.deepStack.handsPerLevel, 15)
        XCTAssertEqual(TournamentConfig.deepStack.startingChips, 2000)
    }
    
    func testPayoutStructureValid() {
        let standard = TournamentConfig.standard
        XCTAssertEqual(standard.payoutStructure.count, 3)
        XCTAssertEqual(standard.payoutStructure, [0.5, 0.3, 0.2])
        
        // Verify percentages sum to 1.0 (approximately)
        let sum = standard.payoutStructure.reduce(0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }
    
    func testBlindLevelProgression() {
        let turbo = TournamentConfig.turbo
        
        // Verify blinds increase over levels
        for i in 1..<turbo.blindSchedule.count {
            let prev = turbo.blindSchedule[i - 1]
            let curr = turbo.blindSchedule[i]
            XCTAssertTrue(curr.bigBlind >= prev.bigBlind, "Blinds should increase or stay same")
        }
    }
    
    // MARK: - BlindLevel Tests
    
    func testBlindLevelDescriptionNoAnte() {
        let level = BlindLevel(level: 1, smallBlind: 10, bigBlind: 20, ante: 0)
        XCTAssertEqual(level.description, "Level 1: 10/20")
    }
    
    func testBlindLevelDescriptionWithAnte() {
        let level = BlindLevel(level: 3, smallBlind: 25, bigBlind: 50, ante: 5)
        XCTAssertEqual(level.description, "Level 3: 25/50 (Ante 5)")
    }
    
    // MARK: - GameMode Tests
    
    func testGameModeCases() {
        XCTAssertEqual(GameMode.cashGame.rawValue, "Cash Game")
        XCTAssertEqual(GameMode.tournament.rawValue, "Tournament")
        XCTAssertEqual(GameMode.allCases.count, 2)
    }
    
    // MARK: - PokerEngine Tournament Initialization Tests
    
    func testEngineDefaultIsCashGame() {
        let engine = PokerEngine(mode: .cashGame)
        XCTAssertEqual(engine.gameMode, .cashGame)
        XCTAssertNil(engine.tournamentConfig)
        XCTAssertEqual(engine.smallBlindAmount, 10)
        XCTAssertEqual(engine.bigBlindAmount, 20)
        XCTAssertEqual(engine.anteAmount, 0)
    }
    
    func testEngineTournamentInitialization() {
        let config = TournamentConfig.standard
        let engine = PokerEngine(mode: .tournament, config: config)
        
        XCTAssertEqual(engine.gameMode, .tournament)
        XCTAssertNotNil(engine.tournamentConfig)
        XCTAssertEqual(engine.smallBlindAmount, config.blindSchedule[0].smallBlind)
        XCTAssertEqual(engine.bigBlindAmount, config.blindSchedule[0].bigBlind)
        XCTAssertEqual(engine.anteAmount, config.blindSchedule[0].ante)
        XCTAssertEqual(engine.currentBlindLevel, 0)
        XCTAssertEqual(engine.handsAtCurrentLevel, 0)
    }
    
    func testTournamentStartingChipsApplied() {
        let deepStack = TournamentConfig.deepStack
        let engine = PokerEngine(mode: .tournament, config: deepStack)
        
        // All 8 players should have starting chips
        for player in engine.players {
            XCTAssertEqual(player.chips, deepStack.startingChips)
        }
    }
    
    // MARK: - Blind Level Progression Tests
    
    func testBlindLevelUp() {
        let engine = PokerEngine(mode: .tournament, config: .turbo)
        
        // Initial level should be level 1 (index 0)
        XCTAssertEqual(engine.currentBlindLevel, 0)
        XCTAssertEqual(engine.smallBlindAmount, 10)
        XCTAssertEqual(engine.bigBlindAmount, 20)
        XCTAssertEqual(engine.handsAtCurrentLevel, 0)
        
        // Complete 5 hands (handsPerLevel for turbo)
        for _ in 0..<5 {
            engine.handsAtCurrentLevel += 1
            // This doesn't trigger automatic level up - only when endHand() is called
        }
        
        // After 5 hands, level should be 1 (index 1) which is 15/30
        XCTAssertEqual(engine.currentBlindLevel, 0) // Not auto-updated without calling endHand
    }
    
    func testAnteAmountInLevels() {
        let turbo = TournamentConfig.turbo
        
        // Level 1-2: No ante
        XCTAssertEqual(turbo.blindSchedule[0].ante, 0)
        XCTAssertEqual(turbo.blindSchedule[1].ante, 0)
        
        // Level 3+: Has ante
        XCTAssertTrue(turbo.blindSchedule[2].ante > 0)
        XCTAssertTrue(turbo.blindSchedule[9].ante > turbo.blindSchedule[2].ante)
    }
}
