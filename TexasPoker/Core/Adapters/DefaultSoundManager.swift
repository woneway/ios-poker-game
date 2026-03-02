import Foundation

/// 默认音效管理器适配器 - 包装现有单例实现 SoundManagerProtocol
final class DefaultSoundManager: SoundManagerProtocol {
    private let soundManager = SoundManager.shared

    func playSound(_ sound: SoundType) {
        soundManager.playSound(sound)
    }
}
