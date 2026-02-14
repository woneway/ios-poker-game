import XCTest
@testable import TexasPoker

class CashGameConfigTests: XCTestCase {

    // MARK: - Default Configuration Tests

    func testDefaultConfigurationSmallBlind() {
        XCTAssertEqual(CashGameConfig.default.smallBlind, 10)
    }

    func testDefaultConfigurationBigBlind() {
        XCTAssertEqual(CashGameConfig.default.bigBlind, 20)
    }

    func testDefaultConfigurationMinBuyIn() {
        XCTAssertEqual(CashGameConfig.default.minBuyIn, 400)
    }

    func testDefaultConfigurationMaxBuyIn() {
        XCTAssertEqual(CashGameConfig.default.maxBuyIn, 2000)
    }

    // MARK: - From Factory Method Tests

    func testFromFactoryMethodWithStandardBlinds() {
        let config = CashGameConfig.from(smallBlind: 5, bigBlind: 10)

        XCTAssertEqual(config.smallBlind, 5)
        XCTAssertEqual(config.bigBlind, 10)
        XCTAssertEqual(config.minBuyIn, 200)  // 10 * 20
        XCTAssertEqual(config.maxBuyIn, 1000) // 10 * 100
    }

    func testFromFactoryMethodWithHigherBlinds() {
        let config = CashGameConfig.from(smallBlind: 25, bigBlind: 50)

        XCTAssertEqual(config.smallBlind, 25)
        XCTAssertEqual(config.bigBlind, 50)
        XCTAssertEqual(config.minBuyIn, 1000)  // 50 * 20
        XCTAssertEqual(config.maxBuyIn, 5000)  // 50 * 100
    }

    func testFromFactoryMethodWithDefaultBlinds() {
        let config = CashGameConfig.from(smallBlind: 10, bigBlind: 20)

        XCTAssertEqual(config.smallBlind, 10)
        XCTAssertEqual(config.bigBlind, 20)
        XCTAssertEqual(config.minBuyIn, 400)
        XCTAssertEqual(config.maxBuyIn, 2000)
    }

    // MARK: - Codable Tests

    func testCodableRoundTrip() throws {
        let config = CashGameConfig.default

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CashGameConfig.self, from: data)

        XCTAssertEqual(decoded.smallBlind, config.smallBlind)
        XCTAssertEqual(decoded.bigBlind, config.bigBlind)
        XCTAssertEqual(decoded.minBuyIn, config.minBuyIn)
        XCTAssertEqual(decoded.maxBuyIn, config.maxBuyIn)
    }
}
