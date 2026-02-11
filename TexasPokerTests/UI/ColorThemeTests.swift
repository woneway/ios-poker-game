import XCTest
import SwiftUI
@testable import TexasPoker

class ColorThemeTests: XCTestCase {
    func test_gradients_exist() {
        let _ = Color.tableGradient
        let _ = Color.cardBackGradient
    }
}
