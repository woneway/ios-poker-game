import Foundation
import XCTest
@testable import TexasPoker

struct TournamentParams: Codable {
    let playerIds: [String]
    let gameCount: Int
    let handsPerGame: Int
    let startingChips: Int
}

final class RealPokerEngineTournamentTest: XCTestCase {

    func testRunTournament() throws {
        var playerIds: [String] = []
        var gameCount = 1
        var handsPerGame = 10
        var startingChips = 1000

        if let envValue = ProcessInfo.processInfo.environment["TEST_RUNNER_PARAMETERS"],
           let data = envValue.data(using: .utf8),
           let params = try? JSONDecoder().decode(TournamentParams.self, from: data) {
            playerIds = params.playerIds
            gameCount = params.gameCount
            handsPerGame = params.handsPerGame
            startingChips = params.startingChips
        }

        if playerIds.isEmpty {
            playerIds = Array(AIProfile.allProfiles.prefix(5).map { $0.id })
        }

        let profiles = AIProfile.allProfiles.filter { playerIds.contains($0.id) }
        guard profiles.count >= 2 else {
            print("Need at least 2 players")
            return
        }

        let results = runTournamentWithProfiles(profiles: profiles, games: gameCount, handsPerGame: handsPerGame, startingChips: startingChips)

        print("=== TOURNAMENT RESULTS ===")
        for (index, result) in results.enumerated() {
            print("\(index + 1). \(result.profile.name): avgRank=\(result.avgRank), chips=\(result.totalChips), wins=\(result.wins)")
        }

        var output: [[String: Any]] = []
        for result in results {
            output.append([
                "id": result.profile.id,
                "name": result.profile.name,
                "avatar": result.profile.avatar.displayValue,
                "avgRank": result.avgRank,
                "totalChips": result.totalChips,
                "wins": result.wins
            ])
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: ["results": output], options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("JSON_OUTPUT:", jsonString)
        }
        print("=========================")
    }

    struct PlayerResult {
        let profile: AIProfile
        var totalPoints: Int = 0
        var gamesPlayed: Int = 0
        var totalChips: Int = 0
        var wins: Int = 0
        var avgRank: Double { gamesPlayed > 0 ? Double(totalPoints) / Double(gamesPlayed) : 52 }
    }

    func runTournamentWithProfiles(profiles: [AIProfile], games: Int, handsPerGame: Int, startingChips: Int) -> [PlayerResult] {
        var results = profiles.map { PlayerResult(profile: $0) }

        for game in 1...games {
            print("Game \(game)/\(games)", terminator: "\r")
            fflush(__stdoutp)

            let gameResults = runSingleGame(profiles: profiles, startingChips: startingChips, maxHands: handsPerGame)

            for result in gameResults {
                if let idx = results.firstIndex(where: { $0.profile.id == result.profile.id }) {
                    results[idx].totalPoints += result.position
                    results[idx].gamesPlayed += 1
                    results[idx].totalChips += result.chips
                    if result.position == 1 {
                        results[idx].wins += 1
                    }
                }
            }
        }

        return results.sorted { $0.avgRank < $1.avgRank }
    }

    struct GameResult {
        let profile: AIProfile
        let position: Int
        let chips: Int
    }

    private func runSingleGame(profiles: [AIProfile], startingChips: Int, maxHands: Int) -> [GameResult] {
        var engine = createEngine(profiles: profiles, startingChips: startingChips)

        for _ in 0..<maxHands {
            let activePlayers = engine.players.filter { $0.chips > 0 }
            if activePlayers.count <= 1 {
                break
            }

            playHand(engine: &engine)

            if engine.isHandOver {
                resetForNextHand(engine: &engine)
            }
        }

        let finalPlayers = engine.players
            .filter { $0.chips > 0 }
            .sorted { $0.chips > $1.chips }

        return finalPlayers.enumerated().map { index, player in
            GameResult(
                profile: player.aiProfile!,
                position: index + 1,
                chips: player.chips
            )
        }
    }

    private func createEngine(profiles: [AIProfile], startingChips: Int) -> PokerEngine {
        let engine = PokerEngine(mode: .cashGame, cashGameConfig: .default)
        engine.players = profiles.map { profile in
            Player(
                name: profile.name,
                chips: startingChips,
                isHuman: false,
                aiProfile: profile
            )
        }
        return engine
    }

    private func playHand(engine: inout PokerEngine) {
        engine.deck.reset()

        for i in 0..<engine.players.count {
            if engine.players[i].chips > 0 {
                if let card1 = engine.deck.deal(), let card2 = engine.deck.deal() {
                    engine.players[i].holeCards = [card1, card2]
                    engine.players[i].status = .active
                    engine.players[i].currentBet = 0
                }
            }
        }

        engine.currentStreet = .preFlop
        engine.dealerIndex = 0
        engine.smallBlindAmount = 10
        engine.bigBlindAmount = 20

        postBlinds(engine: &engine)

        while !engine.isHandOver && engine.activePlayerCount > 1 {
            let player = engine.players[engine.activePlayerIndex]

            if player.isHuman || player.status != .active {
                engine.activePlayerIndex = (engine.activePlayerIndex + 1) % engine.players.count
                continue
            }

            if let action = getAIAction(player: player, engine: engine) {
                engine.processAction(action)
            }

            if engine.isHandOver {
                break
            }
        }

        if !engine.isHandOver && engine.activePlayerCount > 0 {
            while engine.currentStreet != .river {
                engine.dealNextStreet()
            }
            engine.endHand()
        }
    }

    private func postBlinds(engine: inout PokerEngine) {
        let sbIndex = (engine.dealerIndex + 1) % engine.players.count
        let bbIndex = (engine.dealerIndex + 2) % engine.players.count

        if engine.players[sbIndex].chips >= engine.smallBlindAmount {
            engine.players[sbIndex].chips -= engine.smallBlindAmount
            engine.players[sbIndex].currentBet = engine.smallBlindAmount
        }

        if engine.players[bbIndex].chips >= engine.bigBlindAmount {
            engine.players[bbIndex].chips -= engine.bigBlindAmount
            engine.players[bbIndex].currentBet = engine.bigBlindAmount
        }

        engine.currentBet = engine.bigBlindAmount
        engine.activePlayerIndex = (bbIndex + 1) % engine.players.count
    }

    private func getAIAction(player: Player, engine: PokerEngine) -> PlayerAction? {
        let profile = player.aiProfile ?? .fox

        let callAmount = engine.currentBet - player.currentBet
        let canCheck = callAmount == 0
        let potSize = engine.pot.total
        let stackSize = player.chips

        if stackSize <= callAmount {
            return .allIn
        }

        if canCheck {
            let aggression = profile.aggression
            if Double.random(in: 0...1) < aggression * 0.3 && potSize > 50 {
                return .raise(max(engine.bigBlindAmount * 2, potSize / 3))
            }
            return .check
        } else {
            let equity = estimateEquity(profile: profile, street: engine.currentStreet)
            let potOdds = Double(callAmount) / Double(potSize + callAmount)

            if equity > potOdds + 0.1 {
                if stackSize <= callAmount * 3 {
                    return .allIn
                }
                return .call
            } else if equity > potOdds && Double.random(in: 0...1) < profile.bluffFreq {
                return .raise(engine.bigBlindAmount * 3)
            } else if profile.tightness < 0.3 && Double.random(in: 0...1) < profile.tightness {
                return .raise(engine.bigBlindAmount * 3)
            }

            return .fold
        }
    }

    private func estimateEquity(profile: AIProfile, street: Street) -> Double {
        let base = 0.3 + profile.aggression * 0.3 + profile.positionAwareness * 0.2

        switch street {
        case .preFlop:
            return base * 0.8
        case .flop:
            return base
        case .turn:
            return base * 1.1
        case .river:
            return base * 1.2
        }
    }

    private func resetForNextHand(engine: inout PokerEngine) {
        engine.isHandOver = false
        engine.winners = []
        engine.communityCards = []
        engine.pot = Pot()
        engine.currentBet = 0

        for i in 0..<engine.players.count {
            engine.players[i].currentBet = 0
            if engine.players[i].chips <= 0 {
                engine.players[i].status = .eliminated
            } else if engine.players[i].status == .allIn {
                engine.players[i].status = .active
            }
        }

        engine.dealerIndex = (engine.dealerIndex + 1) % engine.players.count
    }
}
