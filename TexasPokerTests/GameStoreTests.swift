import XCTest
@testable import TexasPoker

class GameStoreTests: XCTestCase {
    
    // MARK: - Test 1: Initial state is .idle
    
    func testInitialStateIsIdle() {
        let store = PokerGameStore()
        XCTAssertEqual(store.state, .idle)
    }
    
    // MARK: - Test 2: .start transitions from .idle to .dealing
    
    func testStartTransitionsToDealing() {
        let store = PokerGameStore()
        store.send(.start)
        XCTAssertEqual(store.state, .dealing)
    }
    
    // MARK: - Test 3: .dealComplete transitions from .dealing to .betting
    
    func testDealCompleteTransitionsToBetting() {
        let store = PokerGameStore()
        store.send(.start)        // .idle → .dealing
        store.send(.dealComplete)  // .dealing → .betting
        XCTAssertEqual(store.state, .betting)
    }
    
    // MARK: - Test 4: .handOver transitions from .betting to .showdown
    
    func testHandOverTransitionsToShowdown() {
        let store = PokerGameStore()
        store.send(.start)        // .idle → .dealing
        store.send(.dealComplete)  // .dealing → .betting
        store.send(.handOver)      // .betting → .showdown
        XCTAssertEqual(store.state, .showdown)
    }
    
    // MARK: - Test 5: Invalid event does not change state
    
    func testInvalidTransitionDoesNotChangeState() {
        let store = PokerGameStore()
        // In .idle, sending .dealComplete is invalid
        store.send(.dealComplete)
        XCTAssertEqual(store.state, .idle, "Invalid event should not change state")
        
        // In .idle, sending .handOver is also invalid
        store.send(.handOver)
        XCTAssertEqual(store.state, .idle, "Invalid event should not change state")
    }
}
