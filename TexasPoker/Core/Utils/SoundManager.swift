import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    private var audioPlayers: [SoundType: AVAudioPlayer] = [:]
    var isMuted: Bool = UserDefaults.standard.bool(forKey: "soundMuted") {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: "soundMuted")
        }
    }
    var volume: Float = UserDefaults.standard.float(forKey: "soundVolume") {
        didSet {
            UserDefaults.standard.set(volume, forKey: "soundVolume")
        }
    }
    
    init() {
        // Set default volume if not set
        if UserDefaults.standard.object(forKey: "soundVolume") == nil {
            volume = 1.0
            UserDefaults.standard.set(1.0, forKey: "soundVolume")
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
