import Foundation
import Combine

@MainActor
final class PlayerListViewModel: ObservableObject {
    @Published var players: [PlayerStats] = []
    @Published var filteredPlayers: [PlayerStats] = []
    @Published var searchText: String = ""
    @Published var selectedGameMode: GameMode = .cashGame
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let getAllPlayersStatsUseCase: GetAllPlayersStatsUseCase
    private let getAllPlayerNamesUseCase: GetAllPlayerNamesUseCase
    private var cancellables = Set<AnyCancellable>()

    init(
        getAllPlayersStatsUseCase: GetAllPlayersStatsUseCase = GetAllPlayersStatsUseCase(),
        getAllPlayerNamesUseCase: GetAllPlayerNamesUseCase = GetAllPlayerNamesUseCase()
    ) {
        self.getAllPlayersStatsUseCase = getAllPlayersStatsUseCase
        self.getAllPlayerNamesUseCase = getAllPlayerNamesUseCase
        setupSearchBinding()
    }

    private func setupSearchBinding() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.filterPlayers()
            }
            .store(in: &cancellables)
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            let statsDict = try await getAllPlayersStatsUseCase.execute(gameMode: selectedGameMode)
            let playerNames = getAllPlayerNamesUseCase.execute(gameMode: selectedGameMode)

            players = playerNames.compactMap { name in
                statsDict[name]
            }

            filterPlayers()
        } catch {
            errorMessage = "Failed to load players: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func filterPlayers() {
        if searchText.isEmpty {
            filteredPlayers = players
        } else {
            filteredPlayers = players.filter {
                $0.playerName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    func updateGameMode(_ mode: GameMode) {
        selectedGameMode = mode
        Task {
            await loadData()
        }
    }

    func refresh() async {
        await loadData()
    }
}
