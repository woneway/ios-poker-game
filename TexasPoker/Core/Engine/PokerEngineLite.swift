import Foundation

/// 轻量级扑克引擎 - 可在任意线程安全运行
/// 用于批量验证、AI评估等后台任务
final class PokerEngineLite {

    private var state: LiteGameState
    private let profilesMap: [String: AIProfile]

    /// 构造函数
    init(profiles: [AIProfile], startingChips: Int = 1000, smallBlind: Int = 10, bigBlind: Int = 20) {
        self.profilesMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.name, $0) })

        let players = profiles.map { profile in
            LitePlayer(
                name: profile.name,
                chips: startingChips,
                isHuman: false,
                aiProfile: profile
            )
        }

        self.state = LiteGameState(players: players, smallBlind: smallBlind, bigBlind: bigBlind)
    }

    /// 获取当前游戏状态（只读副本）
    var gameState: LiteGameState {
        state
    }

    /// 开始新手牌
    func startNewHand() {
        state.resetForNewHand()
    }

    /// 检查手牌是否结束
    var isHandOver: Bool {
        state.isHandOver
    }

    /// 活跃玩家数量
    var activePlayerCount: Int {
        state.activePlayerCount
    }

    /// 公共牌
    var communityCards: [Card] {
        state.communityCards
    }

    /// 底池
    var pot: Int {
        state.pot.total
    }

    /// 当前街道
    var currentStreet: Street {
        state.currentStreet
    }

    /// 处理当前玩家动作
    func processCurrentPlayerAction(_ action: PlayerAction) -> Bool {
        guard let player = state.currentPlayer else { return false }

        // 检查动作是否有效
        let isValid: Bool
        switch action {
        case .check:
            isValid = state.currentPlayerCanCheck()
        case .call:
            isValid = true
        case .raise(let amount):
            isValid = amount >= state.minRaise && player.chips >= amount
        case .allIn:
            isValid = true
        case .fold:
            isValid = true
        }

        guard isValid else { return false }

        // 处理动作
        switch action {
        case .fold:
            // 玩家弃牌
            if let index = state.players.firstIndex(where: { $0.id == player.id }) {
                state.players[index].status = .folded
            }
            state.hasActed[player.id] = true

            // 检查是否只剩一个玩家
            if state.nonFoldedPlayers.count == 1 {
                let winner = state.nonFoldedPlayers.first!
                if let index = state.players.firstIndex(where: { $0.id == winner.id }) {
                    state.players[index].chips += state.pot.total
                }
                state.endHand(with: [winner.id])
                return true
            }

        case .check:
            state.hasActed[player.id] = true

        case .call:
            let callAmount = state.currentPlayerCallAmount()
            if let index = state.players.firstIndex(where: { $0.id == player.id }) {
                let actualCall = min(callAmount, state.players[index].chips)
                state.players[index].chips -= actualCall
                state.players[index].currentBet += actualCall
                state.players[index].totalBetThisHand += actualCall
                state.pot.add(actualCall)
            }
            state.hasActed[player.id] = true

        case .raise(let amount):
            if let index = state.players.firstIndex(where: { $0.id == player.id }) {
                let totalBet = state.currentPlayerCallAmount() + amount
                let actualBet = min(totalBet, state.players[index].chips)
                state.players[index].chips -= actualBet
                state.players[index].currentBet += actualBet
                state.players[index].totalBetThisHand += actualBet
                state.pot.add(actualBet)

                // 更新当前下注和最低加注
                state.currentBet = state.players[index].currentBet
                state.minRaise = max(state.currentBet * 2, amount)

                // 记录攻击者
                if state.currentStreet == .preFlop {
                    state.preflopAggressorID = player.id
                }
                state.lastRaiserID = player.id

                // 重置所有玩家行动状态（除了当前玩家）
                state.hasActed = [player.id: true]
            }

        case .allIn:
            if let index = state.players.firstIndex(where: { $0.id == player.id }) {
                let allInAmount = state.players[index].chips
                state.players[index].chips = 0
                state.players[index].status = .allIn
                state.players[index].currentBet += allInAmount
                state.players[index].totalBetThisHand += allInAmount
                state.pot.add(allInAmount)
                state.hasActed[player.id] = true
            }
        }

        // 移动到下一个玩家
        _ = state.nextActivePlayer()

        // 检查下注轮是否结束
        if isBettingRoundComplete() {
            // 进入下一条街
            advanceToNextStreet()
        }

        return true
    }

    /// 检查下注轮是否结束
    private func isBettingRoundComplete() -> Bool {
        let active = state.activePlayers

        // 所有人必须都已行动
        for player in active {
            if state.hasActed[player.id] != true {
                return false
            }
        }

        // 所有可继续行动玩家的下注必须相等
        // 注意：allIn玩家的下注可能不同，不应影响下注轮结束判断
        let actionablePlayers = active.filter { $0.status == .active && $0.chips > 0 }
        if actionablePlayers.isEmpty {
            // 没有可继续行动的玩家（下注轮结束）
            return true
        }
        let bets = Set(actionablePlayers.map { $0.currentBet })
        return bets.count == 1
    }

    /// 进入下一条街
    private func advanceToNextStreet() {
        // 重置行动状态
        state.hasActed = [:]

        // 关闭底池，开启新一轮下注
        state.currentBet = 0

        // 翻牌后更新最低加注
        if state.currentStreet != .preFlop {
            state.minRaise = state.bigBlindAmount
        }

        // 如果不是河牌，发下一条街
        if state.currentStreet != .river {
            state.dealNextStreet()
        } else {
            // 河牌发出后进入摊牌
            evaluateShowdown()
        }
    }

    /// 摊牌判定胜负
    private func evaluateShowdown() {
        let eligible = state.players.filter { $0.status == .active || $0.status == .allIn }

        guard eligible.count >= 2 else {
            // 少于2人，直接处理
            if let winner = eligible.first {
                if let index = state.players.firstIndex(where: { $0.id == winner.id }) {
                    state.players[index].chips += state.pot.total
                }
                state.endHand(with: [winner.id])
            }
            return
        }

        // 评估所有玩家手牌强度
        var bestScore: (playerID: UUID, score: (Int, [Int]))?

        for player in eligible {
            let score = HandEvaluator.evaluate(holeCards: player.holeCards, communityCards: state.communityCards)

            var isBetter = false
            if bestScore == nil {
                isBetter = true
            } else if score.0 > bestScore!.score.0 {
                isBetter = true
            } else if score.0 == bestScore!.score.0 {
                // 比较 kickers
                let myKickers = score.1
                let bestKickers = bestScore!.score.1
                for i in 0..<min(myKickers.count, bestKickers.count) {
                    if myKickers[i] > bestKickers[i] {
                        isBetter = true
                        break
                    } else if myKickers[i] < bestKickers[i] {
                        break
                    }
                }
            }

            if isBetter {
                bestScore = (player.id, score)
            }
        }

        // 分配奖金
        if let winnerID = bestScore?.playerID {
            if let index = state.players.firstIndex(where: { $0.id == winnerID }) {
                state.players[index].chips += state.pot.total
            }
            state.endHand(with: [winnerID])
        }
    }

    /// 让AI进行决策
    func runAIDecision() -> PlayerAction? {
        guard let player = state.currentPlayer else { return nil }

        // 非AI玩家跳过
        guard let profile = player.aiProfile else { return nil }

        let callAmount = state.currentPlayerCallAmount()
        let canCheck = state.currentPlayerCanCheck()
        let potSize = state.pot.total
        let stackSize = player.chips

        // 全下
        if stackSize <= callAmount {
            return .allIn
        }

        if canCheck {
            // 可以过牌
            let aggression = profile.aggression
            if Double.random(in: 0...1) < aggression * 0.3 && potSize > 50 {
                return .raise(max(state.bigBlindAmount * 2, potSize / 3))
            }
            return .check
        } else {
            // 需要跟注/加注
            let equity = estimateEquity(profile: profile, street: state.currentStreet)
            let potOdds = potSize + callAmount > 0 ? Double(callAmount) / Double(potSize + callAmount) : 0

            if equity > potOdds + 0.1 {
                if stackSize <= callAmount * 3 {
                    return .allIn
                }
                return .call
            } else if equity > potOdds && Double.random(in: 0...1) < profile.bluffFreq {
                return .raise(state.bigBlindAmount * 3)
            } else if profile.tightness < 0.3 && Double.random(in: 0...1) < profile.tightness {
                return .raise(state.bigBlindAmount * 3)
            }

            return .fold
        }
    }

    /// 估算胜率
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

    /// 运行完整的手牌（AI自动决策）
    func runHand() {
        startNewHand()

        var loopGuard = 0
        let maxLoops = 500 // 防止无限循环

        while !isHandOver && state.playersWithChips > 1 && loopGuard < maxLoops {
            loopGuard += 1

            // 检查是否有可行动的玩家
            guard let player = state.currentPlayer else {
                #if DEBUG
                print("⚠️ PokerEngineLite: 无当前玩家，提前结束手牌")
                #endif
                break
            }

            // 检查玩家是否还有AI profile
            guard player.aiProfile != nil else {
                // 非AI玩家，跳过
                _ = state.nextActivePlayer()
                continue
            }

            // 检查玩家是否还有可行动的能力（筹码大于0且状态为active）
            guard player.status == .active && player.chips > 0 else {
                // 无法行动的玩家，跳过
                _ = state.nextActivePlayer()
                continue
            }

            if let action = runAIDecision() {
                _ = processCurrentPlayerAction(action)
            } else {
                // 无法获取有效动作，跳过当前玩家
                _ = state.nextActivePlayer()
            }
        }

        #if DEBUG
        if loopGuard >= maxLoops {
            print("⚠️ PokerEngineLite: 达到最大循环次数 \(maxLoops)，强制结束手牌")
        }
        #endif
    }

    /// 获取当前玩家排名（按筹码）
    func getRankings() -> [LitePlayer] {
        return state.players
            .filter { $0.chips > 0 }
            .sorted { $0.chips > $1.chips }
    }
}
