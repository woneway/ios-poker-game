// import XCTest

class PokerUtilsTests: XCTestCase {
    
    func testEqualKickers() {
        XCTAssertEqual(PokerUtils.compareKickers([12, 10, 8], [12, 10, 8]), 0)
    }
    
    func testFirstKickerHigher() {
        XCTAssertEqual(PokerUtils.compareKickers([12, 10, 8], [11, 10, 8]), 1)
    }
    
    func testSecondKickerLower() {
        XCTAssertEqual(PokerUtils.compareKickers([12, 9, 8], [12, 10, 8]), -1)
    }
    
    func testEmptyKickers() {
        XCTAssertEqual(PokerUtils.compareKickers([], []), 0)
    }
    
    func testDifferentLengths() {
        // When lengths differ, compare up to shorter length only
        XCTAssertEqual(PokerUtils.compareKickers([12, 10], [12, 10, 8]), 0)
    }
    
    func testSingleElement() {
        XCTAssertEqual(PokerUtils.compareKickers([5], [3]), 1)
        XCTAssertEqual(PokerUtils.compareKickers([3], [5]), -1)
    }
    
    func testAllEqualWithLongerArrays() {
        XCTAssertEqual(PokerUtils.compareKickers([12, 11, 10, 9, 8], [12, 11, 10, 9, 8]), 0)
    }
    
    func testLastKickerDiffers() {
        XCTAssertEqual(PokerUtils.compareKickers([12, 10, 8], [12, 10, 7]), 1)
        XCTAssertEqual(PokerUtils.compareKickers([12, 10, 7], [12, 10, 8]), -1)
    }
}
