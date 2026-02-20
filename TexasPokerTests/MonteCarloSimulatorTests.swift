import XCTest
@testable import TexasPoker

final class MonteCarloSimulatorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        MonteCarloSimulator.clearCache()
    }
    
    override func tearDown() {
        MonteCarloSimulator.clearCache()
        super.tearDown()
    }
    
    func testEquityCalculation() {
        let holeCards = [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades)]
        let communityCards: [Card] = []
        
        let equity = MonteCarloSimulator.calculateEquity(
            holeCards: holeCards,
            communityCards: communityCards,
            playerCount: 2,
            iterations: 500
        )
        
        XCTAssertGreaterThan(equity, 0.5, "AA should have >50% equity")
        XCTAssertLessThan(equity, 1.0, "AA should have <100% equity")
    }
    
    func testEquityWithCommunityCards() {
        let holeCards = [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades)]
        let communityCards = [
            Card(rank: .queen, suit: .spades),
            Card(rank: .jack, suit: .spades),
            Card(rank: .ten, suit: .hearts)
        ]
        
        let equity = MonteCarloSimulator.calculateEquity(
            holeCards: holeCards,
            communityCards: communityCards,
            playerCount: 2,
            iterations: 500
        )
        
        XCTAssertGreaterThan(equity, 0.5, "AK suited on flop should have >50% equity")
    }
    
    func testEquityCache() {
        let holeCards = [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades)]
        
        let equity1 = MonteCarloSimulator.calculateEquity(
            holeCards: holeCards,
            communityCards: [],
            playerCount: 2,
            iterations: 100
        )
        
        let equity2 = MonteCarloSimulator.calculateEquity(
            holeCards: holeCards,
            communityCards: [],
            playerCount: 2,
            iterations: 100
        )
        
        XCTAssertEqual(equity1, equity2, "Cached result should be equal")
    }
    
    func testDynamicIterations() {
        let iterations1 = MonteCarloSimulator.dynamicIterations(
            hasDrawingHand: false,
            communityCardsCount: 5,
            baseIterations: 1000
        )
        
        let iterations2 = MonteCarloSimulator.dynamicIterations(
            hasDrawingHand: true,
            communityCardsCount: 0,
            baseIterations: 1000
        )
        
        XCTAssertGreaterThan(iterations2, iterations1, "Drawing hand should have more iterations")
    }
    
    func testAsyncEquity() async {
        let holeCards = [Card(rank: .queen, suit: .hearts), Card(rank: .jack, suit: .hearts)]
        
        let equity = await MonteCarloSimulator.calculateEquityAsync(
            holeCards: holeCards,
            communityCards: [],
            playerCount: 3,
            iterations: 200
        )
        
        XCTAssertGreaterThan(equity, 0.0, "Equity should be positive")
        XCTAssertLessThan(equity, 1.0, "Equity should be less than 1")
    }
    
    func testPerformance() {
        let holeCards = [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades)]
        
        measure {
            _ = MonteCarloSimulator.calculateEquity(
                holeCards: holeCards,
                communityCards: [],
                playerCount: 4,
                iterations: 1000
            )
        }
    }
}
