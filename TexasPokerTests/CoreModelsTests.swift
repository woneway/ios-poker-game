import XCTest
@testable import TexasPoker

// MARK: - Card Tests

class CardModelTests: XCTestCase {

    func testCardCreation() {
        let card = Card(rank: .ace, suit: .spades)
        XCTAssertEqual(card.rank, .ace)
        XCTAssertEqual(card.suit, .spades)
    }

    func testCardEquality() {
        let card1 = Card(rank: .ace, suit: .spades)
        let card2 = Card(rank: .ace, suit: .spades)
        XCTAssertEqual(card1, card2)
    }

    func testCardHash() {
        let card = Card(rank: .ace, suit: .spades)
        XCTAssertNotEqual(card.hashValue, 0)
    }

    func testCardId() {
        let card = Card(rank: .ace, suit: .spades)
        // id format is rank.rawValue-suit.rawValue
        XCTAssertEqual(card.id, "12-♠️") // ace rawValue = 12, spades rawValue = "♠️"
    }

    func testRankRawValue() {
        let ace = Card(rank: .ace, suit: .spades)
        let two = Card(rank: .two, suit: .spades)
        XCTAssertEqual(ace.rank.rawValue, 12) // ace = 12
        XCTAssertEqual(two.rank.rawValue, 0)   // two = 0
    }
}

// MARK: - Deck Tests

class DeckModelTests: XCTestCase {

    func testDeckCreation() {
        let deck = Deck()
        XCTAssertEqual(deck.remainingCount, 52)
    }

    func testDealCard() {
        let deck = Deck()
        let card = deck.deal()
        XCTAssertNotNil(card)
        XCTAssertEqual(deck.remainingCount, 51)
    }

    func testDealMultipleCards() {
        let deck = Deck()
        let cards = deck.deal(count: 5)
        XCTAssertEqual(cards.count, 5)
        XCTAssertEqual(deck.remainingCount, 47)
    }

    func testDealAllCards() {
        let deck = Deck()
        for _ in 0..<52 { _ = deck.deal() }
        XCTAssertEqual(deck.remainingCount, 0)
    }

    func testDealFromEmptyDeck() {
        let deck = Deck()
        for _ in 0..<52 { _ = deck.deal() }
        let card = deck.deal()
        XCTAssertNil(card)
    }

    func testDeckReset() {
        let deck = Deck()
        _ = deck.deal(count: 10)
        deck.reset()
        XCTAssertEqual(deck.remainingCount, 52)
    }
}

// MARK: - Player Tests

class PlayerModelTests: XCTestCase {

    func testPlayerCreation() {
        let player = Player(name: "Test", chips: 1000)
        XCTAssertEqual(player.name, "Test")
        XCTAssertEqual(player.chips, 1000)
    }

    func testPlayerWithAIProfile() {
        // Test basic player creation without AI profile
        let player = Player(name: "Test", chips: 1000)
        XCTAssertNil(player.aiProfile)
        XCTAssertFalse(player.isHuman)
    }

    func testPlayerHumanFlag() {
        let human = Player(name: "Human", chips: 1000, isHuman: true)
        XCTAssertTrue(human.isHuman)
    }

    func testPlayerStatus() {
        var player = Player(name: "Test", chips: 1000)
        XCTAssertEqual(player.status, .active)

        player.status = .folded
        XCTAssertEqual(player.status, .folded)

        player.status = .allIn
        XCTAssertEqual(player.status, .allIn)
    }

    func testPlayerUniqueId() {
        // Test player without profile - should use name
        let player = Player(name: "TestPlayer", chips: 1000, entryIndex: 1)
        XCTAssertEqual(player.playerUniqueId, "TestPlayer#1")
    }
}

// MARK: - PlayerAction Tests

class PlayerActionModelTests: XCTestCase {

    func testActionDescriptions() {
        XCTAssertEqual(PlayerAction.fold.description, "Fold")
        XCTAssertEqual(PlayerAction.check.description, "Check")
        XCTAssertEqual(PlayerAction.call.description, "Call")
        XCTAssertEqual(PlayerAction.raise(100).description, "Raise to 100")
        XCTAssertEqual(PlayerAction.allIn.description, "All In")
    }

    func testActionEquality() {
        XCTAssertEqual(PlayerAction.fold, .fold)
        XCTAssertEqual(PlayerAction.raise(100), .raise(100))
        XCTAssertNotEqual(PlayerAction.fold, .check)
    }
}

// MARK: - Pot Tests

class PotModelTests: XCTestCase {

    func testPotCreation() {
        let pot = Pot()
        XCTAssertEqual(pot.total, 0)
    }

    func testPotAdd() {
        var pot = Pot()
        pot.add(100)
        XCTAssertEqual(pot.total, 100)
    }

    func testPotMultipleAdds() {
        var pot = Pot()
        pot.add(100)
        pot.add(100)
        pot.add(100)
        XCTAssertEqual(pot.total, 300)
    }

    func testPotReset() {
        var pot = Pot()
        pot.add(100)
        pot.reset()
        XCTAssertEqual(pot.total, 0)
    }

    func testPotRefund() {
        var pot = Pot()
        pot.add(100)
        pot.refund(30)
        XCTAssertEqual(pot.total, 70)
    }
}

// MARK: - Street Tests

class StreetModelTests: XCTestCase {

    func testStreetRawValues() {
        XCTAssertEqual(Street.preFlop.rawValue, "preFlop")
        XCTAssertEqual(Street.flop.rawValue, "flop")
        XCTAssertEqual(Street.turn.rawValue, "turn")
        XCTAssertEqual(Street.river.rawValue, "river")
    }

    func testStreetCaseIterable() {
        let allStreets = Street.allCases
        XCTAssertEqual(allStreets.count, 4)
    }

    func testStreetEquality() {
        XCTAssertEqual(Street.flop, .flop)
        XCTAssertNotEqual(Street.flop, .turn)
    }
}
