import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    // 使用与GameSettings一致的UserDefaults key
    private let soundEnabledKey = "soundEnabled"
    private let soundVolumeKey = "soundVolume"
    
    private var audioPlayers: [SoundType: AVAudioPlayer] = [:]
    var isMuted: Bool {
        get { !UserDefaults.standard.bool(forKey: soundEnabledKey) }
        set {
            UserDefaults.standard.set(!newValue, forKey: soundEnabledKey)
        }
    }
    var volume: Float {
        get { UserDefaults.standard.float(forKey: soundVolumeKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: soundVolumeKey)
        }
    }
    
    init() {
        // Set default volume if not set
        if UserDefaults.standard.object(forKey: soundVolumeKey) == nil {
            UserDefaults.standard.set(Float(0.7), forKey: soundVolumeKey)
        }
        if UserDefaults.standard.object(forKey: soundEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: soundEnabledKey)
        }
        loadSounds()
    }
    
    private func loadSounds() {
        // Try to load custom sounds (if available)
        let sounds: [SoundType: String] = [
            .fold: "fold",
            .check: "check",
            .call: "call",
            .raise: "raise",
            .allIn: "allin",
            .win: "win",
            .deal: "deal",
            .flip: "flip"
        ]
        
        for (type, filename) in sounds {
            if let url = Bundle.main.url(forResource: filename, withExtension: "mp3") {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    audioPlayers[type] = player
                } catch {
                    #if DEBUG
                    print("Failed to load sound: \(filename)")
                    #endif
                }
            }
        }
    }
    
    func playSound(_ type: SoundType) {
        guard !isMuted else { return }
        
        if let player = audioPlayers[type] {
            player.volume = volume
            player.currentTime = 0
            player.play()
        } else {
            // Fallback to system sounds
            playSystemSound(type)
        }
    }
    
    private func playSystemSound(_ type: SoundType) {
        let soundID: SystemSoundID
        switch type {
        case .deal, .flip: soundID = 1104
        case .chip, .call, .raise: soundID = 1103
        case .check: soundID = 1105
        case .fold: soundID = 1057
        case .win: soundID = 1001
        case .allIn: soundID = 1016
        case .turnStart: soundID = 1000
        }
        AudioServicesPlaySystemSound(soundID)
    }
}

enum SoundType {
    case deal
    case chip
    case check
    case fold
    case call
    case raise
    case allIn
    case win
    case flip
    case turnStart
}
