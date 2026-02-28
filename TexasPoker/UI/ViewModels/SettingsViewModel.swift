import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: GameSettings
    @Published var availableProfiles: [AIProfile] = []
    @Published var quickStats: QuickStats = QuickStats()

    private let gameHistoryManager: GameHistoryManager
    private var cancellables = Set<AnyCancellable>()

    struct QuickStats {
        var totalGames: Int = 0
        var wins: Int = 0
        var winRate: Int = 0
        var avgRank: Int = 0
    }

    init(settings: GameSettings = GameSettings()) {
        self.settings = settings
        self.gameHistoryManager = .shared
        loadData()
    }

    func loadData() {
        availableProfiles = AIProfile.Difficulty.expert.availableProfiles
        loadQuickStats()
    }

    func loadQuickStats() {
        let records = gameHistoryManager.records
        quickStats.totalGames = records.count

        if records.isEmpty {
            quickStats = QuickStats()
            return
        }

        quickStats.wins = records.filter { $0.heroRank == 1 }.count
        quickStats.winRate = Int(round(Double(quickStats.wins) * 100.0 / Double(records.count)))

        let totalRank = records.map { $0.heroRank }.reduce(0, +)
        quickStats.avgRank = Int(round(Double(totalRank) / Double(records.count)))
    }

    func updateGameSpeed(_ speed: Double) {
        settings.gameSpeed = speed
    }

    func updateSoundEnabled(_ enabled: Bool) {
        settings.soundEnabled = enabled
    }

    func updateSoundVolume(_ volume: Double) {
        settings.soundVolume = volume
    }

    func updateDifficulty(_ difficulty: AIProfile.Difficulty) {
        settings.aiDifficulty = difficulty
    }

    func updatePlayerCount(_ count: Int) {
        settings.playerCount = count
    }

    func updateGameMode(_ mode: GameMode) {
        settings.gameMode = mode
    }

    func updateUseRandomOpponents(_ useRandom: Bool) {
        settings.useRandomOpponents = useRandom
    }

    func updateCashGameMaxBuyIns(_ maxBuyIns: Int) {
        settings.cashGameMaxBuyIns = maxBuyIns
    }

    func resetToDefaults() {
        settings = GameSettings()
        loadData()
    }
}
