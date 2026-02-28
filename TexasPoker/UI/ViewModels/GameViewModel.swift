import Combine
import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var communityCards: [Card] = []
    @Published var pot: Int = 0
    @Published var currentBet: Int = 0
    @Published var activePlayerIndex: Int = 0
    @Published var currentStreet: Street = .preFlop
    @Published var isHandOver: Bool = false
    @Published var winMessage: String = ""
    @Published var handNumber: Int = 0
    @Published var actionLog: [ActionLogEntry] = []

    private let pokerEngine: PokerEngine
    private var cancellables = Set<AnyCancellable>()

    init(pokerEngine: PokerEngine = PokerEngine()) {
        self.pokerEngine = pokerEngine
        setupBindings()
    }

    private func setupBindings() {
        pokerEngine.$players
            .receive(on: DispatchQueue.main)
            .assign(to: &$players)

        pokerEngine.$communityCards
            .receive(on: DispatchQueue.main)
            .assign(to: &$communityCards)

        pokerEngine.$pot
            .receive(on: DispatchQueue.main)
            .map { $0.total }
            .assign(to: &$pot)

        pokerEngine.$currentBet
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentBet)

        pokerEngine.$activePlayerIndex
            .receive(on: DispatchQueue.main)
            .assign(to: &$activePlayerIndex)

        pokerEngine.$currentStreet
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentStreet)

        pokerEngine.$isHandOver
            .receive(on: DispatchQueue.main)
            .assign(to: &$isHandOver)

        pokerEngine.$winMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$winMessage)

        pokerEngine.$handNumber
            .receive(on: DispatchQueue.main)
            .assign(to: &$handNumber)

        pokerEngine.$actionLog
            .receive(on: DispatchQueue.main)
            .assign(to: &$actionLog)
    }

    var currentPlayer: Player? {
        guard activePlayerIndex < players.count else { return nil }

        return players[activePlayerIndex]
    }

    var isHumanTurn: Bool {
        currentPlayer?.isHuman ?? false
    }

    func processAction(_ action: PlayerAction) {
        pokerEngine.processAction(action)
    }
}
