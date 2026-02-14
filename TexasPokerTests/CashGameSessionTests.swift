import XCTest
@testable import TexasPoker

class CashGameSessionTests: XCTestCase {

    // MARK: - Net Profit Tests

    func testNetProfitCalculation() {
        let session = CashGameSession(buyIn: 100)
        XCTAssertEqual(session.initialBuyIn, 100)
        XCTAssertEqual(session.topUpTotal, 0)
        XCTAssertEqual(session.finalChips, 0)
        XCTAssertEqual(session.netProfit, -100) // 0 - 100 - 0 = -100
    }

    func testNetProfitWithTopUps() {
        var session = CashGameSession(buyIn: 100)
        session.topUpTotal = 50
        session.finalChips = 200

        // netProfit = finalChips - initialBuyIn - topUpTotal
        // = 200 - 100 - 50 = 50
        XCTAssertEqual(session.netProfit, 50)
    }

    func testNetProfitWithNoProfit() {
        var session = CashGameSession(buyIn: 100)
        session.finalChips = 100

        // netProfit = 100 - 100 - 0 = 0
        XCTAssertEqual(session.netProfit, 0)
    }

    func testNetProfitWithLoss() {
        var session = CashGameSession(buyIn: 100)
        session.topUpTotal = 20
        session.finalChips = 80

        // netProfit = 80 - 100 - 20 = -40
        XCTAssertEqual(session.netProfit, -40)
    }

    // MARK: - Max Win / Max Loss Tests

    func testMaxWinWithEmptyHandProfits() {
        let session = CashGameSession(buyIn: 100)
        XCTAssertEqual(session.maxWin, 0)
    }

    func testMaxLossWithEmptyHandProfits() {
        let session = CashGameSession(buyIn: 100)
        XCTAssertEqual(session.maxLoss, 0)
    }

    func testMaxWinWithProfits() {
        var session = CashGameSession(buyIn: 100)
        session.handProfits = [10, -20, 50, -5, 30]

        XCTAssertEqual(session.maxWin, 50)
    }

    func testMaxLossWithProfits() {
        var session = CashGameSession(buyIn: 100)
        session.handProfits = [10, -20, 50, -5, 30]

        XCTAssertEqual(session.maxLoss, -20)
    }

    func testMaxWinWithAllWins() {
        var session = CashGameSession(buyIn: 100)
        session.handProfits = [10, 20, 30, 40]

        XCTAssertEqual(session.maxWin, 40)
        XCTAssertEqual(session.maxLoss, 10)
    }

    func testMaxLossWithAllLosses() {
        var session = CashGameSession(buyIn: 100)
        session.handProfits = [-10, -20, -30, -5]

        XCTAssertEqual(session.maxWin, -5)
        XCTAssertEqual(session.maxLoss, -30)
    }

    // MARK: - Duration Tests

    func testDurationWithNoEndTime() {
        let session = CashGameSession(buyIn: 100)
        // Duration should be positive (time since start)
        XCTAssertGreaterThan(session.duration, 0)
    }

    func testDurationWithEndTime() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600) // 1 hour later

        var session = CashGameSession(buyIn: 100)
        session.endTime = endTime

        // Duration should be approximately 3600 seconds (1 hour)
        XCTAssertEqual(session.duration, 3600, accuracy: 1)
    }

    func testDurationWithShortSession() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(60) // 1 minute later

        var session = CashGameSession(buyIn: 100)
        session.endTime = endTime

        XCTAssertEqual(session.duration, 60, accuracy: 1)
    }

    // MARK: - Codable Tests

    func testCodable() throws {
        var session = CashGameSession(buyIn: 100)
        session.topUpTotal = 50
        session.finalChips = 200
        session.handsPlayed = 10
        session.handProfits = [10, -5, 20, -10, 15]
        session.endTime = Date()

        let encoder = JSONEncoder()
        let data = try encoder.encode(session)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CashGameSession.self, from: data)

        XCTAssertEqual(decoded.id, session.id)
        XCTAssertEqual(decoded.initialBuyIn, session.initialBuyIn)
        XCTAssertEqual(decoded.topUpTotal, session.topUpTotal)
        XCTAssertEqual(decoded.finalChips, session.finalChips)
        XCTAssertEqual(decoded.handsPlayed, session.handsPlayed)
        XCTAssertEqual(decoded.handProfits, session.handProfits)
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        let session = CashGameSession(buyIn: 200)

        XCTAssertNotNil(session.id)
        XCTAssertNotNil(session.startTime)
        XCTAssertNil(session.endTime)
        XCTAssertEqual(session.initialBuyIn, 200)
        XCTAssertEqual(session.topUpTotal, 0)
        XCTAssertEqual(session.finalChips, 0)
        XCTAssertEqual(session.handsPlayed, 0)
        XCTAssertTrue(session.handProfits.isEmpty)
    }
}
