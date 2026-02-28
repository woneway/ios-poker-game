import Combine
import Foundation

@MainActor
final class LobbyViewModel: ObservableObject {
    @Published var settings: GameSettings
    @Published var availableProfiles: [AIProfile] = []
    @Published var selectedDifficulty: AIProfile.Difficulty = .normal
    @Published var playerCount: Int = 6
    @Published var selectedGameMode: GameMode = .cashGame

    private let gameSettings: GameSettings

    init(settings: GameSettings = GameSettings()) {
        self.settings = settings
        self.gameSettings = settings
        loadProfiles()
    }

    func loadProfiles() {
        availableProfiles = AIProfile.Difficulty.expert.availableProfiles
    }

    func updateDifficulty(_ difficulty: AIProfile.Difficulty) {
        selectedDifficulty = difficulty
        settings.aiDifficulty = difficulty
    }

    func updatePlayerCount(_ count: Int) {
        playerCount = count
        settings.playerCount = count
    }

    func updateGameMode(_ mode: GameMode) {
        selectedGameMode = mode
        settings.gameMode = mode
    }

    func startCashGame() -> GameSettings {
        settings.gameMode = .cashGame
        return settings
    }

    func startTournament() -> GameSettings {
        settings.gameMode = .tournament
        return settings
    }
}
