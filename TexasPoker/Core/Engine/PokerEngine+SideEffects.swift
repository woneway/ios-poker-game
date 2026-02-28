import Foundation

/// 记录AI玩家每手牌的输赢结果
func recordAIHandResults(players: [Player], startingChips: [String: Int]) {
    for player in players where !player.isHuman {
        let playerId = player.id.uuidString
        let startChips = startingChips[playerId] ?? player.chips
        let profit = player.chips - startChips
        if profit > 0 {
            AIBankrollManager.shared.recordWin(playerId, amount: profit)
        } else if profit < 0 {
            AIBankrollManager.shared.recordLoss(playerId, amount: -profit)
        }
    }
}

// MARK: - Sound, Action Log, Statistics, Notifications
extension PokerEngine {
    
    enum EngineNotifications {
        static let playerStatsUpdated = NSNotification.Name("PlayerStatsUpdated")
    }
    
    func playSoundForAction(_ action: PlayerAction) {
        switch action {
        case .fold:  SoundManager.shared.playSound(.fold)
        case .check: SoundManager.shared.playSound(.check)
        case .call:  SoundManager.shared.playSound(.call)
        case .raise: SoundManager.shared.playSound(.raise)
        case .allIn: SoundManager.shared.playSound(.allIn)
        }
    }
    
    func recordActionLog(action: PlayerAction, player: Player) {
        let logAmount: Int? = {
            switch action {
            case .call:          return player.currentBet
            case .raise(let to): return to
            case .allIn:         return player.currentBet
            default:             return nil
            }
        }()
        let avatar = player.aiProfile?.avatar.displayValue ?? (player.isHuman ? "🤠" : "🤖")
        
        // 记录AI玩家的下注模式
        if !player.isHuman {
            let playerId = player.id.uuidString
            recordBettingPattern(
                playerId: playerId,
                handNumber: handNumber,
                street: currentStreet,
                action: action,
                potSize: pot.total
            )
            
            // 获取该玩家最近的动作历史用于读牌
            let recentActions = actionLog
                .filter { $0.playerName == player.displayName }
                .suffix(5)
                .map { $0.action }
            
            // 记录手牌信息用于读牌
            recordHandForReading(
                playerId: playerId,
                communityCards: communityCards,
                street: currentStreet,
                recentActions: Array(recentActions)
            )
        }
        
        // 生成签名动作和评语（仅 AI 玩家）
        var signatureAction: String? = nil
        var commentary: String? = nil
        
        if let profile = player.aiProfile {
            // 判断动作类型
            let isRaising = { () -> Bool in
                switch action {
                case .raise, .allIn: return true
                default: return false
                }
            }()
            let isCalling = { () -> Bool in
                switch action {
                case .call: return true
                default: return false
                }
            }()
            let isChecking = { () -> Bool in
                switch action {
                case .check: return true
                default: return false
                }
            }()
            
            // 获取签名动作
            let sigAction = profile.signatureAction(
                for: String(describing: action),
                isRaising: isRaising,
                isCalling: isCalling,
                isChecking: isChecking
            )
            if sigAction != .none {
                signatureAction = sigAction.rawValue
            }
            
            // 获取评语
            commentary = profile.commentary(for: String(describing: action))
        }
        
        let entry = ActionLogEntry(
            playerName: player.displayName,
            avatar: avatar,
            action: action,
            amount: logAmount,
            street: currentStreet,
            signatureAction: signatureAction,
            commentary: commentary
        )
        actionLog.append(entry)
        if actionLog.count > maxLogEntries {
            actionLog.removeFirst(actionLog.count - maxLogEntries)
        }
        
        // Trigger player animation
        triggerPlayerAnimation(player: player, action: action)
    }
    
    private func triggerPlayerAnimation(player: Player, action: PlayerAction) {
        let playerId = player.id.uuidString
        
        switch action {
        case .fold:
            PlayerAnimationManager.shared.startAnimation(for: playerId, type: .folding)
        case .check:
            PlayerAnimationManager.shared.startAnimation(for: playerId, type: .acting)
        case .call:
            PlayerAnimationManager.shared.startAnimation(for: playerId, type: .acting)
        case .raise:
            PlayerAnimationManager.shared.startAnimation(for: playerId, type: .acting)
        case .allIn:
            PlayerAnimationManager.shared.startAnimation(for: playerId, type: .allIn)
        }
        
        // Publish action event for UI
        GameEventPublisher.shared.publishPlayerAction(
            playerID: player.id,
            action: String(describing: action)
        )
    }
    
    func recordActionStats(action: PlayerAction, originalPlayer: Player, updatedPlayer: Player, potAddition: Int) {
        // 验证模式下跳过 Core Data 记录
        if disableSideEffects { return }

        let isVoluntary = determineIfVoluntary(action: action, player: originalPlayer)
        let position = getPosition(playerIndex: activePlayerIndex)
        ActionRecorder.shared.recordAction(
            playerName: updatedPlayer.name,
            playerUniqueId: updatedPlayer.playerUniqueId,
            action: action,
            amount: potAddition,
            street: currentStreet,
            isVoluntary: isVoluntary,
            position: position,
            isHuman: originalPlayer.isHuman
        )
    }

    func recordHandEnd() {
        // 验证模式下跳过 Core Data 记录
        if disableSideEffects { return }

        let heroCards = players.first { $0.isHuman }?.holeCards ?? []
        let winnerNames = winners.compactMap { id in
            players.first { $0.id == id }?.name
        }
        ActionRecorder.shared.endHand(
            finalPot: lastPotSize,
            communityCards: communityCards,
            heroCards: heroCards,
            winners: winnerNames
        )
        
        // Record hand data to DataAnalysisEngine for AI learning
        recordHandToAnalysisEngine()
        
        // Record hand patterns to AILearningSystem for AI learning
        recordHandToLearningSystem()
        
        // Record memories to AIMemorySystem
        recordMemoriesToLearningSystem()
        
        // Record emotional events for AI opponents
        recordEmotionalEvents()
        
        // Recompute persisted statistics for all table players.
        // This keeps "download/new install" stats empty, and updates dynamically as the user plays.
        StatisticsCalculator.shared.recomputeAndPersistStats(
            playerNames: players.map { $0.name },
            gameMode: gameMode,
            profileId: ProfileManager.shared.currentProfileIdForData
        )

        GameEventPublisher.shared.publishPlayerStatsUpdated()
    }
    
    private func recordHandToAnalysisEngine() {
        let playerIds = players.map { $0.id.uuidString }
        var holeCardsMap: [String: [Card]] = [:]
        for player in players {
            holeCardsMap[player.id.uuidString] = player.holeCards
        }
        
        var actions: [DataAnalysisEngine.ActionRecord] = []
        for (street, streetActions) in bettingHistory {
            for action in streetActions {
                let actionName: String
                switch action.type {
                case .check: actionName = "check"
                case .bet: actionName = "bet"
                case .call: actionName = "call"
                case .raise: actionName = "raise"
                case .fold: actionName = "fold"
                @unknown default: actionName = "unknown"
                }
                actions.append(DataAnalysisEngine.ActionRecord(
                    playerId: "",
                    street: street.rawValue,
                    action: actionName,
                    amount: action.amount,
                    timestamp: Date()
                ))
            }
        }
        
        var profitMap: [String: Int] = [:]
        for player in players {
            let netProfit = player.chips - player.startingChips
            profitMap[player.id.uuidString] = netProfit
        }
        
        let handRecord = DataAnalysisEngine.HandRecord(
            id: UUID(),
            timestamp: Date(),
            players: playerIds,
            holeCards: holeCardsMap,
            communityCards: communityCards,
            actions: actions,
            potSize: lastPotSize,
            winner: winners.first?.uuidString,
            profit: profitMap
        )
        
        DataAnalysisEngine.shared.recordHand(handRecord)
        
        // Also update player strategies based on this hand
        for player in players where !player.isHuman {
            var actionStrings: [String] = []
            for (_, streetActions) in bettingHistory {
                for action in streetActions {
                    switch action.type {
                    case .check: actionStrings.append("check")
                    case .bet: actionStrings.append("bet")
                    case .call: actionStrings.append("call")
                    case .raise: actionStrings.append("raise")
                    case .fold: actionStrings.append("fold")
                    @unknown default: break
                    }
                }
            }
            
            let hand = PlayerStrategyManager.HandRecord(
                id: UUID(),
                timestamp: Date(),
                position: players.firstIndex(where: { $0.id == player.id }) ?? 0,
                holeCards: player.holeCards,
                communityCards: communityCards,
                actions: actionStrings,
                profit: profitMap[player.id.uuidString] ?? 0,
                won: winners.contains(player.id)
            )
            PlayerStrategyManager.shared.recordHand(for: player.id.uuidString, hand: hand)
        }
    }
    
    private func recordHandToLearningSystem() {
        for player in players {
            guard player.status == .active || player.status == .allIn else { continue }
            guard !player.holeCards.isEmpty else { continue }
            
            let position = seatOffsetFromDealer(playerIndex: players.firstIndex(where: { $0.id == player.id }) ?? 0)
            
            let preflopAction: PlayerAction
            if let firstAction = bettingHistory[.preFlop]?.first {
                switch firstAction.type {
                case .raise: preflopAction = .raise(firstAction.amount)
                case .call: preflopAction = .call
                case .check: preflopAction = .check
                case .fold: preflopAction = .fold
                default: preflopAction = .check
                }
            } else {
                preflopAction = .check
            }
            
            let isWinner = winners.contains(player.id)
            let result: HandResult = isWinner ? .win : .loss
            
            for (street, streetActions) in bettingHistory {
                for action in streetActions {
                    let playerAction: PlayerAction
                    switch action.type {
                    case .raise: playerAction = .raise(action.amount)
                    case .call: playerAction = .call
                    case .check: playerAction = .check
                    case .fold: playerAction = .fold
                    default: continue
                    }
                    
                    let pattern = HandPattern(
                        holeCards: player.holeCards,
                        position: position,
                        preflopAction: preflopAction,
                        communityCards: communityCards,
                        street: street,
                        action: playerAction,
                        result: result
                    )
                    AILearningSystem.shared.recordHand(pattern)
                }
            }
        }
    }
    
    private func recordMemoriesToLearningSystem() {
        for player in players {
            guard player.isHuman == false else { continue }
            
            let playerName = player.displayName
            let isWinner = winners.contains(player.id)
            
            if isWinner {
                AIMemorySystem.shared.remember(
                    playerId: playerName,
                    type: .success,
                    title: "盈利手牌",
                    description: "在 \(communityCards.count) 张公共牌时获胜",
                    insight: "继续保持这种打法",
                    tags: ["win", currentStreet.rawValue]
                )
            } else if player.status == .folded {
                let handCategory = HandEvaluator.evaluate(holeCards: player.holeCards, communityCards: communityCards).0
                if handCategory >= 3 {
                    AIMemorySystem.shared.remember(
                        playerId: playerName,
                        type: .mistake,
                        title: "错失价值",
                        description: "有强牌但fold了",
                        insight: "考虑慢打强牌",
                        tags: ["missedValue", currentStreet.rawValue]
                    )
                }
            }
        }
        
        if let hero = players.first(where: { $0.isHuman }), winners.contains(hero.id) {
            for player in players where !player.isHuman && player.status == .folded {
                AIMemorySystem.shared.rememberOpponentPlay(
                    playerId: "Hero",
                    opponentId: player.displayName,
                    action: "fold",
                    result: "弃牌",
                    insight: "对手选择不跟注"
                )
            }
        }
    }
    
    private func recordEmotionalEvents() {
        for player in players {
            guard !player.isHuman else { continue }
            
            let playerId = player.displayName
            let isWinner = winners.contains(player.id)
            let profit = player.chips - player.startingChips
            
            // Record emotional events based on hand result
            if isWinner {
                OpponentEmotionalSimulator.shared.recordEvent(
                    playerId: playerId,
                    trigger: .bigWin,
                    result: .win,
                    potSize: lastPotSize
                )
            } else if profit < -player.startingChips / 4 {
                OpponentEmotionalSimulator.shared.recordEvent(
                    playerId: playerId,
                    trigger: .badBeat,
                    result: .loss,
                    potSize: lastPotSize
                )
            } else if player.status == .folded {
                OpponentEmotionalSimulator.shared.recordEvent(
                    playerId: playerId,
                    trigger: .bluffSucceeded,
                    result: .win,
                    potSize: lastPotSize
                )
            }
        }
    }
    
    func notifyWinnerAnimations(result: ShowdownResult) {
        for winnerID in result.winnerIDs {
            if let winnerIndex = players.firstIndex(where: { $0.id == winnerID }) {
                GameEventPublisher.shared.publishPlayerWon(playerID: winnerID)
                let winnerAmount = result.totalPot / result.winnerIDs.count
                GameEventPublisher.shared.publishWinnerChipAnimation(seatIndex: winnerIndex, amount: winnerAmount)
                
                // Trigger winner animation
                let playerId = winnerID.uuidString
                if winnerAmount > pot.total / 2 {
                    PlayerAnimationManager.shared.startAnimation(for: playerId, type: .bigWin)
                } else {
                    PlayerAnimationManager.shared.startAnimation(for: playerId, type: .winning)
                }
                PlayerAnimationManager.shared.setEmotion(for: playerId, emotion: .happy)
            }
        }
        
        // Trigger losing animations for losers
        for player in players where !winners.contains(player.id) && player.status != .eliminated {
            let playerId = player.id.uuidString
            PlayerAnimationManager.shared.startAnimation(for: playerId, type: .losing)
            PlayerAnimationManager.shared.setEmotion(for: playerId, emotion: .sad)
        }
    }
    
    // MARK: - Position & Statistics Helpers
    
    func determineIfVoluntary(action: PlayerAction, player: Player) -> Bool {
        if currentStreet == .preFlop,
           players[bigBlindIndex].id == player.id,
           case .call = action,
           currentBet == bigBlindAmount {
            return false
        }
        return action != .fold && action != .check
    }
    
    func getPosition(playerIndex: Int) -> String {
        let offset = seatOffsetFromDealer(playerIndex: playerIndex)
        let activeCount = players.filter { $0.status == .active || $0.status == .allIn }.count
        
        if activeCount == 2 { return offset == 0 ? "BTN/SB" : "BB" }
        
        switch offset {
        case 0: return "BTN"
        case 1: return "SB"
        case 2: return "BB"
        case 3: return "UTG"
        case 4: return "MP"
        case 5: return activeCount <= 6 ? "CO" : "MP"
        case 6: return "CO"
        case 7: return "HJ"
        default: return "EP"
        }
    }
}
