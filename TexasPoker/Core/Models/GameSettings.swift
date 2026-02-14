import SwiftUI
import CoreData
import Combine

// MARK: - Optimized Game Settings
class GameSettings: ObservableObject {
    // Persistence keys
    private let gameSpeedKey = "gameSpeed"
    private let soundEnabledKey = "soundEnabled"
    private let soundVolumeKey = "soundVolume"
    private let difficultyKey = "difficulty"
    private let gameModeKey = "gameMode"
    private let tournamentPresetKey = "tournamentPreset"
    private let playerCountKey = "playerCount"
    private let useRandomOpponentsKey = "useRandomOpponents"
    
    // MARK: - Game Speed
    @Published var gameSpeed: Double {
        didSet { 
            UserDefaults.standard.set(gameSpeed, forKey: gameSpeedKey)
            NotificationCenter.default.post(name: .gameSpeedChanged, object: gameSpeed)
        }
    }
    
    var gameSpeedDescription: String {
        switch gameSpeed {
        case 0.5: return "极慢"
        case 1.0: return "慢速"
        case 1.5: return "正常"
        case 2.0: return "快速"
        case 2.5: return "很快"
        case 3.0: return "极速"
        default: return "\(String(format: "%.1f", gameSpeed))x"
        }
    }
    
    // MARK: - Sound
    @Published var soundEnabled: Bool {
        didSet { 
            UserDefaults.standard.set(soundEnabled, forKey: soundEnabledKey)
            SoundManager.shared.isMuted = !soundEnabled
        }
    }
    
    @Published var soundVolume: Double {
        didSet {
            UserDefaults.standard.set(soundVolume, forKey: soundVolumeKey)
            SoundManager.shared.volume = Float(soundVolume)
        }
    }
    
    var volumePercentage: String {
        "\(Int(soundVolume * 100))%"
    }
    
    // MARK: - AI Difficulty
    @Published var aiDifficulty: AIProfile.Difficulty {
        didSet { 
            UserDefaults.standard.set(aiDifficulty.rawValue, forKey: difficultyKey)
            NotificationCenter.default.post(name: .difficultyChanged, object: aiDifficulty)
        }
    }
    
    @Published var playerCount: Int {
        didSet {
            UserDefaults.standard.set(playerCount, forKey: playerCountKey)
        }
    }
    
    @Published var useRandomOpponents: Bool {
        didSet {
            UserDefaults.standard.set(useRandomOpponents, forKey: useRandomOpponentsKey)
        }
    }
    
    // MARK: - Game Mode
    @Published var gameMode: GameMode {
        didSet { 
            UserDefaults.standard.set(gameMode.rawValue, forKey: gameModeKey)
            NotificationCenter.default.post(name: .gameModeChanged, object: gameMode)
        }
    }
    
    @Published var tournamentPreset: TournamentPreset {
        didSet { 
            UserDefaults.standard.set(tournamentPreset.rawValue, forKey: tournamentPresetKey)
        }
    }
    
    enum TournamentPreset: String, CaseIterable, Identifiable {
        case turbo = "Turbo"
        case standard = "Standard"
        case deepStack = "DeepStack"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .turbo: return "快速锦标赛"
            case .standard: return "标准锦标赛"
            case .deepStack: return "深筹锦标赛"
            }
        }
        
        var description: String {
            switch self {
            case .turbo: return "盲注升级快，适合短时间游戏"
            case .standard: return "标准节奏，平衡体验"
            case .deepStack: return "起始筹码多，技术对抗"
            }
        }
        
        var config: TournamentConfig {
            switch self {
            case .turbo: return .turbo
            case .standard: return .standard
            case .deepStack: return .deepStack
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        let defaults = UserDefaults.standard
        
        // Game speed
        self.gameSpeed = defaults.object(forKey: gameSpeedKey) as? Double ?? 1.5
        
        // Sound
        let initialSoundEnabled = defaults.object(forKey: soundEnabledKey) as? Bool ?? true
        let initialSoundVolume = defaults.object(forKey: soundVolumeKey) as? Double ?? 0.7
        self.soundEnabled = initialSoundEnabled
        self.soundVolume = initialSoundVolume
        
        // Difficulty
        let diffRaw = defaults.string(forKey: difficultyKey) ?? "normal"
        self.aiDifficulty = AIProfile.Difficulty(rawValue: diffRaw) ?? .normal
        
        // Player count
        self.playerCount = defaults.object(forKey: playerCountKey) as? Int ?? 6
        
        // Random opponents
        self.useRandomOpponents = defaults.object(forKey: useRandomOpponentsKey) as? Bool ?? true
        
        // Game mode
        let modeRaw = defaults.string(forKey: gameModeKey) ?? GameMode.cashGame.rawValue
        self.gameMode = GameMode(rawValue: modeRaw) ?? .cashGame
        
        // Tournament preset
        let presetRaw = defaults.string(forKey: tournamentPresetKey) ?? "standard"
        self.tournamentPreset = TournamentPreset(rawValue: presetRaw) ?? .standard
        
        // Sync sound manager after all stored properties are initialized
        SoundManager.shared.volume = Float(initialSoundVolume)
        SoundManager.shared.isMuted = !initialSoundEnabled
    }
    
    // MARK: - Helper Methods
    
    /// Get the tournament config based on current preset
    func getTournamentConfig() -> TournamentConfig? {
        guard gameMode == .tournament else { return nil }
        return tournamentPreset.config
    }
    
    /// Reset all settings to default
    func resetToDefaults() {
        gameSpeed = 1.5
        soundEnabled = true
        soundVolume = 0.7
        aiDifficulty = .normal
        playerCount = 6
        useRandomOpponents = true
        gameMode = .cashGame
        tournamentPreset = .standard
    }
    
    /// Generate game setup based on current settings
    func generateGameSetup(heroName: String = "Hero") -> GameSetup {
        return GameSetup(
            difficulty: aiDifficulty,
            playerCount: playerCount,
            startingChips: gameMode == .tournament 
                ? (getTournamentConfig()?.startingChips ?? 1000)
                : 1000,
            gameMode: gameMode
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let gameSpeedChanged = Notification.Name("gameSpeedChanged")
    static let difficultyChanged = Notification.Name("difficultyChanged")
    static let gameModeChanged = Notification.Name("gameModeChanged")
}

// MARK: - Legacy Support
extension GameSettings {
    /// Legacy difficulty enum for backward compatibility
    enum LegacyDifficulty: String, CaseIterable, Identifiable {
        case easy = "简单"
        case normal = "普通"
        case hard = "困难"
        case pro = "专业"
        
        var id: String { self.rawValue }
        
        var toAIDifficulty: AIProfile.Difficulty {
            switch self {
            case .easy: return .easy
            case .normal: return .normal
            case .hard: return .hard
            case .pro: return .expert
            }
        }
    }
}
