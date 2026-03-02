import Foundation
import SwiftUI

/// 默认动画管理器适配器 - 包装现有单例实现 AnimationManagerProtocol
final class DefaultAnimationManager: AnimationManagerProtocol {
    private let animationManager = PlayerAnimationManager.shared

    func startAnimation(for playerId: String, type: PlayerAnimationType) {
        animationManager.startAnimation(for: playerId, type: type)
    }

    func stopAnimation(for playerId: String) {
        animationManager.stopAnimation(for: playerId)
    }

    func setEmotion(for playerId: String, emotion: PlayerEmotion) {
        animationManager.setEmotion(for: playerId, emotion: emotion)
    }
}
