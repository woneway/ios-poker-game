import Foundation

/// 下注动作处理结果
struct BetActionResult {
    var playerUpdate: Player       // 更新后的玩家状态
    var potAddition: Int           // 本次加入奖池的金额
    var newCurrentBet: Int         // 更新后的当前下注额
    var newMinRaise: Int           // 更新后的最小加注额
    var newLastRaiserID: UUID?     // 新的最后加注者（nil = 未改变）
    var isNewAggressor: Bool       // 是否成为新的翻前攻击者
    var reopenAction: Bool         // 是否需要重新开启其他玩家的行动
    var isValid: Bool             // 操作是否有效
}

/// 下注管理器 — 处理下注动作和轮次判断
enum BettingManager {

    /// 处理玩家的下注动作
    static func processAction(
        _ action: PlayerAction,
        player: Player,
        currentBet: Int,
        minRaise: Int
    ) -> BetActionResult {
        var p = player
        var potAdd = 0
        var newCurrentBet = currentBet
        var newMinRaise = minRaise
        var newLastRaiser: UUID? = nil
        var isNewAggressor = false
        var reopenAction = false

        switch action {
        case .fold:
            p.status = .folded

        case .check:
            // 检查是否可以check（下注额必须相等）
            if p.currentBet != currentBet {
                // 无效的check应该被忽略，而不是强制fold
                // 返回原始状态，并标记为无效，让上层处理这个无效操作
                return BetActionResult(
                    playerUpdate: p,
                    potAddition: 0,
                    newCurrentBet: currentBet,
                    newMinRaise: minRaise,
                    newLastRaiserID: nil,
                    isNewAggressor: false,
                    reopenAction: false,
                    isValid: false
                )
            }
            // 有效的check，不需要改变任何状态

        case .call:
            let amountNeeded = currentBet - p.currentBet
            let actualAmount = min(amountNeeded, p.chips)
            p.chips -= actualAmount
            p.currentBet += actualAmount
            p.totalBetThisHand += actualAmount
            potAdd = actualAmount
            if p.chips == 0 { p.status = .allIn }

        case .raise(let raiseToAmount):
            let minimumRaiseTo = currentBet + minRaise
            let actualRaiseTo = max(raiseToAmount, minimumRaiseTo)
            let amountNeeded = actualRaiseTo - p.currentBet
            let actualAmount = min(amountNeeded, p.chips)

            p.chips -= actualAmount
            p.currentBet += actualAmount
            p.totalBetThisHand += actualAmount
            potAdd = actualAmount

            if p.currentBet > currentBet {
                let raiseSize = p.currentBet - currentBet
                // 确保 minRaise 永远不为负数
                newMinRaise = max(0, max(minRaise, raiseSize))
                newCurrentBet = p.currentBet
                newLastRaiser = p.id
                isNewAggressor = true
                reopenAction = true
            }
            if p.chips == 0 { p.status = .allIn }

        case .allIn:
            let amount = p.chips
            p.chips = 0
            p.currentBet += amount
            p.totalBetThisHand += amount
            potAdd = amount
            if p.currentBet > currentBet {
                // All-in 后 minRaise 应该是 0
                // 因为 all-in 玩家已经下注所有筹码，其他玩家不能再次加注
                // 只能选择 fold 或 call
                newMinRaise = 0
                newCurrentBet = p.currentBet
                newLastRaiser = p.id
                isNewAggressor = true
                reopenAction = true
            }
            p.status = .allIn
        }

        return BetActionResult(
            playerUpdate: p,
            potAddition: potAdd,
            newCurrentBet: newCurrentBet,
            newMinRaise: newMinRaise,
            newLastRaiserID: newLastRaiser,
            isNewAggressor: isNewAggressor,
            reopenAction: reopenAction,
            isValid: true
        )
    }

    /// 判断当前下注轮次是否完成
    /// 注意：allIn 玩家也被视为已完成行动
    static func isRoundComplete(
        players: [Player],
        hasActed: [UUID: Bool],
        currentBet: Int
    ) -> Bool {
        // 活跃玩家包括 active 和 allIn（allIn 玩家不能再行动）
        let activePlayers = players.filter { $0.status == .active || $0.status == .allIn }
        if activePlayers.isEmpty { return true }

        // 终态检查：如果所有活跃玩家都是 all-in，轮次必然结束
        // 这是死锁场景的核心修复：当所有人都 all-in 时，不应该等待任何人行动
        let allPlayersAllIn = activePlayers.allSatisfy { $0.status == .allIn }
        if allPlayersAllIn {
            return true
        }

        // 检查是否有需要行动的活跃玩家
        // 注意：folded 和 eliminated 玩家不参与下注轮次
        let playersNeedingAction = activePlayers.filter { player in
            // allIn 玩家不需要再行动
            guard player.status == .active else { return false }
            // 已经行动过的玩家不需要再行动
            // 注意：即使玩家当前下注额等于当前最高下注额（如大盲注），
            // 只要他们还没有行动，就仍然需要给他们行动机会（BB option）
            return hasActed[player.id] != true
        }

        // 如果没有需要行动的玩家，轮次结束
        if playersNeedingAction.isEmpty {
            return true
        }

        // 有玩家需要行动，轮次未结束
        return false
    }

    /// 重置下注状态（新街开始时）
    /// 注意：allIn 玩家的 hasActed 设为 true，因为他们不能再行动
    static func resetBettingState(
        players: inout [Player],
        bigBlindAmount: Int
    ) -> (currentBet: Int, minRaise: Int, hasActed: [UUID: Bool]) {
        for i in 0..<players.count {
            players[i].currentBet = 0
        }
        var hasActed: [UUID: Bool] = [:]
        // active 玩家需要行动，allIn 玩家已经完成行动
        for player in players where player.status == .active || player.status == .allIn {
            hasActed[player.id] = (player.status == .allIn)
        }
        return (currentBet: 0, minRaise: bigBlindAmount, hasActed: hasActed)
    }

    /// 投盲注
    static func postBlind(
        playerIndex: Int,
        amount: Int,
        players: inout [Player],
        pot: inout Pot,
        hasActed: inout [UUID: Bool]
    ) {
        let actualBet = min(players[playerIndex].chips, amount)
        players[playerIndex].chips -= actualBet
        players[playerIndex].currentBet += actualBet
        players[playerIndex].totalBetThisHand += actualBet
        pot.add(actualBet)
        if players[playerIndex].chips == 0 {
            players[playerIndex].status = .allIn
            hasActed[players[playerIndex].id] = true
        }
    }
}
