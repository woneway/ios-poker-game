import Foundation

/// 默认动作记录器适配器 - 包装现有单例实现 ActionRecorderProtocol
final class DefaultActionRecorder: ActionRecorderProtocol {
    private let recorder = ActionRecorder.shared

    func startHand(handNumber: Int, gameMode: GameMode, players: [Player]) {
        recorder.startHand(handNumber: handNumber, gameMode: gameMode, players: players)
    }

    func recordAction(
        playerName: String,
        playerUniqueId: String?,
        action: PlayerAction,
        amount: Int,
        street: Street,
        isVoluntary: Bool,
        position: String,
        isHuman: Bool
    ) {
        recorder.recordAction(
            playerName: playerName,
            playerUniqueId: playerUniqueId,
            action: action,
            amount: amount,
            street: street,
            isVoluntary: isVoluntary,
            position: position,
            isHuman: isHuman
        )
    }

    func endHand(
        finalPot: Int,
        communityCards: [Card],
        heroCards: [Card],
        winners: [String]
    ) {
        recorder.endHand(
            finalPot: finalPot,
            communityCards: communityCards,
            heroCards: heroCards,
            winners: winners
        )
    }
}
