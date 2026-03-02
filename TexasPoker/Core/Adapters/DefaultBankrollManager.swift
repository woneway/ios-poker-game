import Foundation

/// 默认资金管理器适配器 - 包装现有单例实现 BankrollManagerProtocol
final class DefaultBankrollManager: BankrollManagerProtocol {
    private let bankrollManager = AIBankrollManager.shared

    func recordWin(_ playerId: String, amount: Int) {
        bankrollManager.recordWin(playerId, amount: amount)
    }

    func recordLoss(_ playerId: String, amount: Int) {
        bankrollManager.recordLoss(playerId, amount: amount)
    }
}
