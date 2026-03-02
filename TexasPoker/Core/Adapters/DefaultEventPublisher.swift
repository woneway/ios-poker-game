import Foundation
import Combine

/// 默认事件发布器适配器 - 包装现有单例实现 EventPublisherProtocol
final class DefaultEventPublisher: EventPublisherProtocol {
    private let publisher = GameEventPublisher.shared

    func publishPlayerAction(playerID: UUID, action: String, isThinking: Bool) {
        publisher.publishPlayerAction(playerID: playerID, action: action, isThinking: isThinking)
    }

    func publishChipAnimation(seatIndex: Int, amount: Int) {
        publisher.publishChipAnimation(seatIndex: seatIndex, amount: amount)
    }

    func publishWinnerChipAnimation(seatIndex: Int, amount: Int) {
        publisher.publishWinnerChipAnimation(seatIndex: seatIndex, amount: amount)
    }

    func publishPlayerWon(playerID: UUID) {
        publisher.publishPlayerWon(playerID: playerID)
    }

    func publishPlayerStatsUpdated() {
        publisher.publishPlayerStatsUpdated()
    }
}
