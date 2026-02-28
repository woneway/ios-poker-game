import Combine
import Foundation

@MainActor
final class TournamentViewModel: ObservableObject {
    @Published var tournamentState: TournamentState = .notStarted
    @Published var players: [TournamentPlayer] = []
    @Published var currentLevel: Int = 0
    @Published var blinds: (small: Int, big: Int) = (10, 20)
    @Published var remainingPlayers: Int = 0
    @Published var prizePool: Int = 0
    @Published var levelTimeRemaining: Int = 600

    private let tournamentManager: TournamentManager

    enum TournamentState {
        case notStarted
        case registrationOpen
        case running
        case paused
        case finished
        case winnerDeclared
    }

    struct TournamentPlayer: Identifiable {
        let id: UUID
        let name: String
        var chips: Int
        var rank: Int?
        var isEliminated: Bool
    }

    init(tournamentManager: TournamentManager = TournamentManager()) {
        self.tournamentManager = tournamentManager
    }

    func startTournament(playerCount: Int, startingChips: Int, blindLevelTime: Int) {
        tournamentState = .running
        currentLevel = 1
        updateBlinds()

        players = (0..<playerCount).map { index in
            TournamentPlayer(
                id: UUID(),
                name: "Player \(index + 1)",
                chips: startingChips,
                rank: nil,
                isEliminated: false
            )
        }

        remainingPlayers = playerCount
        prizePool = calculatePrizePool(playerCount: playerCount)
    }

    func eliminatePlayer(id: UUID) {
        if let index = players.firstIndex(where: { $0.id == id }) {
            players[index].isEliminated = true
            remainingPlayers -= 1

            let rank = remainingPlayers + 1
            players[index].rank = rank

            if remainingPlayers == 1 {
                tournamentState = .winnerDeclared
                players[0].rank = 1
            }
        }
    }

    func nextLevel() {
        currentLevel += 1
        updateBlinds()
        levelTimeRemaining = 600
    }

    private func updateBlinds() {
        let blindLevels: [(Int, Int)] = [
            (10, 20), (15, 30), (20, 40), (25, 50),
            (50, 100), (75, 150), (100, 200), (150, 300),
            (200, 400), (300, 600), (400, 800), (500, 1000)
        ]
        let levelIndex = min(currentLevel - 1, blindLevels.count - 1)
        blinds = blindLevels[levelIndex]
    }

    private func calculatePrizePool(playerCount: Int) -> Int {
        return playerCount * 100
    }
}
