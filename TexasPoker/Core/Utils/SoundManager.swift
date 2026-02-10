import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    func playSound(_ type: SoundType) {
        switch type {
        case .deal:
            AudioServicesPlaySystemSound(1104)
        case .chip:
            AudioServicesPlaySystemSound(1103)
        case .check:
            AudioServicesPlaySystemSound(1105)
        case .fold:
            AudioServicesPlaySystemSound(1057)
        case .win:
            AudioServicesPlaySystemSound(1001)
        case .turnStart:
            AudioServicesPlaySystemSound(1000)
        }
    }
}

enum SoundType {
    case deal
    case chip
    case check
    case fold
    case win
    case turnStart
}
