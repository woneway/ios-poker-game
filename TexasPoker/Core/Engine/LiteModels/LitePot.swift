import Foundation

/// 轻量级奖池数据结构
struct LitePot: Equatable {
    var runningTotal: Int = 0

    var total: Int {
        runningTotal
    }

    mutating func add(_ amount: Int) {
        runningTotal += amount
    }

    mutating func reset() {
        runningTotal = 0
    }
}
