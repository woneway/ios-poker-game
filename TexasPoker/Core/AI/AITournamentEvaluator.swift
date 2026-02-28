import Foundation

final class AITournamentEvaluator {

    struct PlayerResult {
        let profile: AIProfile
        var totalPoints: Int = 0
        var gamesPlayed: Int = 0
        var totalChips: Int = 0
        var wins: Int = 0
        var avgRank: Double { gamesPlayed > 0 ? Double(totalPoints) / Double(gamesPlayed) : 52 }
    }

    struct GameResult {
        let profile: AIProfile
        let position: Int
        let chips: Int
    }

    struct TournamentConfig {
        let playerCount: Int
        let games: Int
        let startingChips: Int
        let maxHandsPerGame: Int
    }

    private let config: TournamentConfig
    var profilesMap: [String: AIProfile] = [:]

    init(config: TournamentConfig = TournamentConfig(
        playerCount: 52,
        games: 10,
        startingChips: 1000,
        maxHandsPerGame: 100
    )) {
        self.config = config
    }

    func runEvaluation() -> [PlayerResult] {
        let profiles = AIProfile.allProfiles
        var results = profiles.map { PlayerResult(profile: $0) }

        print("开始评估 \(profiles.count) 名AI牌手...")
        print("配置: \(config.games) 场比赛, 初始筹码 \(config.startingChips)\n")

        for game in 1...config.games {
            let gameResults = runSingleGame(profiles: profiles)

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

            print("第 \(game)/\(config.games) 场完成")
        }

        return results.sorted { $0.avgRank < $1.avgRank }
    }
    
    func runEvaluationWithProfiles(_ profiles: [AIProfile]) -> [PlayerResult] {
        var results = profiles.map { PlayerResult(profile: $0) }

        for game in 1...config.games {
            let gameResults = runSingleGame(profiles: profiles)

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
    
    func runSingleGameForProgress(profiles: [AIProfile]) -> Bool {
        _ = runSingleGame(profiles: profiles)
        return true
    }

    private func runSingleGame(profiles: [AIProfile]) -> [GameResult] {
        var engine = createEngine(profiles: profiles)

        for _ in 0..<config.maxHandsPerGame {
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

    private func createEngine(profiles: [AIProfile]) -> PokerEngine {
        let engine = PokerEngine(mode: .cashGame, cashGameConfig: .default)
        engine.aiDecisionDelay = 0
        engine.useSyncAIDecision = true
        engine.players = profiles.map { profile in
            Player(
                name: profile.name,
                chips: config.startingChips,
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
        engine.minRaise = 0

        engine.dealerIndex = (engine.dealerIndex + 1) % engine.players.count
    }

    func generateReport(results: [PlayerResult]) -> String {
        var report = """
        ╔════════════════════════════════════════════════════════════════════════╗
        ║                    52人AI牌手实力评估报告                               ║
        ║                    Tournament Championship Report                      ║
        ╚════════════════════════════════════════════════════════════════════════╝

        评估配置:
        - 玩家数量: \(config.playerCount)
        - 比赛场次: \(config.games)
        - 初始筹码: \(config.startingChips)
        - 每场最大手牌: \(config.maxHandsPerGame)

        """

        report += "\n🏆 最终排名 (按平均名次排序，越低越强):\n"
        report += String(repeating: "─", count: 80) + "\n"
        report += String(format: "%-4s %-20s %-10s %-10s %-10s %-8s\n",
                        "排名", "选手", "平均名次", "总积分", "总筹码", "夺冠次数")
        report += String(repeating: "─", count: 80) + "\n"

        for (i, result) in results.enumerated() {
            let rank = i + 1
            let medal = rank == 1 ? "🥇" : rank == 2 ? "🥈" : rank == 3 ? "🥉" : "  "
            let name = String(result.profile.name.prefix(18))
            let avg = String(format: "%.1f", result.avgRank)
            let totalPts = "\(result.totalPoints)"
            let chips = formatChips(result.totalChips)
            let wins = "\(result.wins)"

            report += String(format: "%@ %-2d  %-20s %-10s %-10s %-10s %-8s\n",
                            medal, rank, name, avg, totalPts, chips, wins)
        }

        report += "\n" + String(repeating: "═", count: 80) + "\n"
        report += "\n📊 统计分析:\n\n"

        let avgAggression = results.map { $0.profile.aggression }.reduce(0, +) / Double(results.count)
        let avgTightness = results.map { $0.profile.tightness }.reduce(0, +) / Double(results.count)
        let avgPosition = results.map { $0.profile.positionAwareness }.reduce(0, +) / Double(results.count)

        report += "  平均侵略性: \(String(format: "%.2f", avgAggression))\n"
        report += "  平均紧度: \(String(format: "%.2f", avgTightness))\n"
        report += "  平均位置意识: \(String(format: "%.2f", avgPosition))\n"

        let topAggression = results.prefix(10).map { $0.profile.aggression }.reduce(0, +) / 10.0
        let bottomAggression = results.suffix(10).map { $0.profile.aggression }.reduce(0, +) / 10.0

        report += "\n  前10名平均侵略性: \(String(format: "%.2f", topAggression))\n"
        report += "  后10名平均侵略性: \(String(format: "%.2f", bottomAggression))\n"

        report += "\n" + String(repeating: "═", count: 80) + "\n"
        report += "\n🏅 冠军榜:\n\n"

        let winners = results.filter { $0.wins > 0 }.sorted { $0.wins > $1.wins }
        for w in winners.prefix(10) {
            report += "  \(w.profile.name): \(w.wins) 次冠军\n"
        }

        report += "\n" + String(repeating: "═", count: 80) + "\n"
        report += "\n生成时间: \(Date())\n"
        report += "评估完成!\n"

        return report
    }

    private func formatChips(_ chips: Int) -> String {
        if chips >= 1000000 {
            return "\(chips / 1000000)M"
        } else if chips >= 1000 {
            return "\(chips / 1000)K"
        }
        return "\(chips)"
    }
}
