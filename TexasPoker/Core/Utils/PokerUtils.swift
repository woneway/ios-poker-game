import Foundation

/// 共享的扑克工具函数
enum PokerUtils {
    /// 比较两组 kicker 牌面大小
    /// - Returns: 1 if k1 > k2, -1 if k1 < k2, 0 if equal
    static func compareKickers(_ k1: [Int], _ k2: [Int]) -> Int {
        for i in 0..<min(k1.count, k2.count) {
            if k1[i] > k2[i] { return 1 }
            if k1[i] < k2[i] { return -1 }
        }
        return 0
    }
}
