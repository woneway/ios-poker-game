// import XCTest

// Mocking the module import since we are in a file-based structure
// In Xcode, this would be @testable import TexasPoker

class HandEvaluatorTests: XCTestCase {
    
    func testRoyalFlushBeatsStraightFlush() {
        // Royal Flush: A, K, Q, J, 10 of Spades
        let royal = [
            Card(rank: .ace, suit: .spades),
            Card(rank: .king, suit: .spades),
            Card(rank: .queen, suit: .spades),
            Card(rank: .jack, suit: .spades),
            Card(rank: .ten, suit: .spades)
        ]
        
        // Straight Flush: 9, 8, 7, 6, 5 of Hearts
        let straightFlush = [
            Card(rank: .nine, suit: .hearts),
            Card(rank: .eight, suit: .hearts),
            Card(rank: .seven, suit: .hearts),
            Card(rank: .six, suit: .hearts),
            Card(rank: .five, suit: .hearts)
        ]
        
        let score1 = HandEvaluator.evaluate(holeCards: Array(royal.prefix(2)), communityCards: Array(royal.suffix(3)))
        let score2 = HandEvaluator.evaluate(holeCards: Array(straightFlush.prefix(2)), communityCards: Array(straightFlush.suffix(3)))
        
        // Score.0 is category (8 = Straight Flush/Royal). 
        // Wait, naive evaluator treats Royal as just the highest Straight Flush (8).
        // So categories should be equal, but kickers (ranks) should be higher for Royal.
        
        XCTAssertEqual(score1.0, 8)
        XCTAssertEqual(score2.0, 8)
        
        // Compare kickers
        XCTAssertTrue(PokerUtils.compareKickers(score1.1, score2.1) > 0, "Royal Flush should beat lower Straight Flush")
    }
    
    func testFourOfAKindBeatsFullHouse() {
        // Quads: 4 Aces
        let quads = [
            Card(rank: .ace, suit: .spades),
            Card(rank: .ace, suit: .hearts),
            Card(rank: .ace, suit: .diamonds),
            Card(rank: .ace, suit: .clubs),
            Card(rank: .king, suit: .spades)
        ]
        
        // Full House: KKK QQ
        let fullHouse = [
            Card(rank: .king, suit: .hearts),
            Card(rank: .king, suit: .diamonds),
            Card(rank: .king, suit: .clubs),
            Card(rank: .queen, suit: .spades),
            Card(rank: .queen, suit: .hearts)
        ]
        
        let score1 = HandEvaluator.evaluate(holeCards: [], communityCards: quads)
        let score2 = HandEvaluator.evaluate(holeCards: [], communityCards: fullHouse)
        
        XCTAssertEqual(score1.0, 7) // Quads
        XCTAssertEqual(score2.0, 6) // Full House
        XCTAssertTrue(score1.0 > score2.0)
    }
    
    func testKickerMatters() {
        // Pair of Aces, King Kicker
        let hand1 = [
            Card(rank: .ace, suit: .spades),
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .diamonds),
            Card(rank: .two, suit: .clubs),
            Card(rank: .three, suit: .spades)
        ]
        
        // Pair of Aces, Queen Kicker
        let hand2 = [
            Card(rank: .ace, suit: .clubs),
            Card(rank: .ace, suit: .diamonds),
            Card(rank: .queen, suit: .hearts),
            Card(rank: .two, suit: .spades),
            Card(rank: .three, suit: .hearts)
        ]
        
        let score1 = HandEvaluator.evaluate(holeCards: [], communityCards: hand1)
        let score2 = HandEvaluator.evaluate(holeCards: [], communityCards: hand2)
        
        XCTAssertEqual(score1.0, 1) // Pair
        XCTAssertEqual(score2.0, 1) // Pair
        
        XCTAssertTrue(PokerUtils.compareKickers(score1.1, score2.1) > 0, "King kicker should beat Queen kicker")
    }
    
}
