import Foundation
import Combine

struct ChipAnimationEvent {
    let seatIndex: Int
    let amount: Int
}

struct WinnerChipAnimationEvent {
    let seatIndex: Int
    let amount: Int
}

struct HandCompleteEvent {
    let handNumber: Int
}

struct PlayerWonEvent {
    let playerID: UUID
}

struct PlayerStatsUpdatedEvent {}

struct PlayerActionEvent {
    let playerID: UUID
    let action: String
    let isThinking: Bool
}

struct PlayerEmotionEvent {
    let playerID: UUID
    let emotion: String
}

struct AIDecisionEvent {
    let playerID: UUID
    let playerName: String
    let action: String
    let reasoning: String
    let equity: Double
    let potOdds: Double
    let confidence: Double
}

@Observable
final class GameEventPublisher {
    static let shared = GameEventPublisher()
    
    let chipAnimation = PassthroughSubject<ChipAnimationEvent, Never>()
    let winnerChipAnimation = PassthroughSubject<WinnerChipAnimationEvent, Never>()
    let handComplete = PassthroughSubject<HandCompleteEvent, Never>()
    let playerWon = PassthroughSubject<PlayerWonEvent, Never>()
    let playerStatsUpdated = PassthroughSubject<PlayerStatsUpdatedEvent, Never>()
    let playerAction = PassthroughSubject<PlayerActionEvent, Never>()
    let playerEmotion = PassthroughSubject<PlayerEmotionEvent, Never>()
    let aiDecision = PassthroughSubject<AIDecisionEvent, Never>()
    
    private init() {}
    
    func publishChipAnimation(seatIndex: Int, amount: Int) {
        chipAnimation.send(ChipAnimationEvent(seatIndex: seatIndex, amount: amount))
    }
    
    func publishWinnerChipAnimation(seatIndex: Int, amount: Int) {
        winnerChipAnimation.send(WinnerChipAnimationEvent(seatIndex: seatIndex, amount: amount))
    }
    
    func publishHandComplete(handNumber: Int) {
        handComplete.send(HandCompleteEvent(handNumber: handNumber))
    }
    
    func publishPlayerWon(playerID: UUID) {
        playerWon.send(PlayerWonEvent(playerID: playerID))
    }
    
    func publishPlayerStatsUpdated() {
        playerStatsUpdated.send(PlayerStatsUpdatedEvent())
    }
    
    func publishPlayerAction(playerID: UUID, action: String, isThinking: Bool = false) {
        playerAction.send(PlayerActionEvent(playerID: playerID, action: action, isThinking: isThinking))
    }
    
    func publishPlayerEmotion(playerID: UUID, emotion: String) {
        playerEmotion.send(PlayerEmotionEvent(playerID: playerID, emotion: emotion))
    }
    
    func publishAIDecision(
        playerID: UUID,
        playerName: String,
        action: String,
        reasoning: String,
        equity: Double,
        potOdds: Double,
        confidence: Double
    ) {
        aiDecision.send(AIDecisionEvent(
            playerID: playerID,
            playerName: playerName,
            action: action,
            reasoning: reasoning,
            equity: equity,
            potOdds: potOdds,
            confidence: confidence
        ))
    }
}
