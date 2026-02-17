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
                // All-in 后的 minRaise 计算：
                // 当有玩家 all-in 后，其他玩家仍然可以加注到更高金额
                // minRaise 应该保持不变，允许其他玩家选择是否加注
                let raiseSize = p.currentBet - currentBet
                newMinRaise = max(minRaise, raiseSize)  // 修正：使用 raiseSize 更新 minRaise
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

        #if DEBUG
        var debugInfo = "🔍 isRoundComplete: activePlayers=\(activePlayers.count), currentBet=\(currentBet)"
        #endif

        for player in activePlayers {
            #if DEBUG
            debugInfo += " | \(player.name): hasActed=\(hasActed[player.id] == true), currentBet=\(player.currentBet), status=\(player.status)"
            #endif
            if hasActed[player.id] != true {
                #if DEBUG
                print(debugInfo)
                #endif
                return false
            }
            // allIn 玩家的 currentBet 可能小于 currentBet（比如短码 all-in）
            // 但他们已经用完所有筹码，不能再继续下注，所以应该被视为完成
            // 只有 active 玩家需要检查 currentBet 是否相等
            if player.status == .active && player.currentBet != currentBet {
                #if DEBUG
                print(debugInfo)
                #endif
                return false
            }
        }
        #if DEBUG
        print(debugInfo + " => true (round complete!)")
        #endif
        return true
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
