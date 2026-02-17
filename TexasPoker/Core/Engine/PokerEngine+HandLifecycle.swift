import Foundation

// MARK: - Hand Lifecycle (startHand, endHand, runOutBoard)
extension PokerEngine {
    
    func startHand() {
        handNumber += 1
        
        // Update tilt levels before starting
        TiltManager.updateTiltLevels(players: &players, lastHandLosers: lastHandLosers, lastPotSize: lastPotSize)
        
        // Reset deck and community (reset 内置 shuffle)
        deck.reset()
        communityCards.removeAll()
        pot.reset()
        currentStreet = .preFlop
        currentBet = 0
        minRaise = bigBlindAmount
        winners = []
        winMessage = ""
        isHandOver = false
        hasActed = [:]
        lastRaiserID = nil
        preflopAggressorID = nil
        bettingHistory = [:]  // 重置下注历史
        
        // Reset player states
        for i in 0..<players.count {
            players[i].holeCards.removeAll()
            players[i].currentBet = 0
            players[i].totalBetThisHand = 0
            // CashGame: sittingOut 玩家保持状态，本手不参与
            if players[i].status == .sittingOut && gameMode == .cashGame {
                continue
            }
            players[i].status = players[i].chips > 0 ? .active : .eliminated
        }
        
        // Move dealer button
        let newDealerIdx = nextActivePlayerIndex(after: dealerIndex)
        if newDealerIdx >= 0 {
            dealerIndex = newDealerIdx
        } else {
            // 没有活跃玩家，无法继续
            isHandOver = true
            winMessage = "Not enough players!"
            return
        }
        
        // Determine blind positions
        let activePlayers = players.filter { $0.status == .active || $0.status == .allIn }
        if activePlayers.count <= 1 {
            isHandOver = true
            winMessage = "Not enough players!"
            return
        }
        
        let newSmallBlindIdx = nextActivePlayerIndex(after: dealerIndex)
        if newSmallBlindIdx >= 0 {
            smallBlindIndex = newSmallBlindIdx
        } else {
            isHandOver = true
            winMessage = "Not enough players!"
            return
        }
        
        let newBigBlindIdx = nextActivePlayerIndex(after: smallBlindIndex)
        if newBigBlindIdx >= 0 {
            bigBlindIndex = newBigBlindIdx
        } else {
            isHandOver = true
            winMessage = "Not enough players!"
            return
        }
        
        // In heads-up (2 players), dealer posts SB
        if activePlayers.count == 2 {
            smallBlindIndex = dealerIndex
            let newHeadUpBigBlindIdx = nextActivePlayerIndex(after: dealerIndex)
            if newHeadUpBigBlindIdx >= 0 {
                bigBlindIndex = newHeadUpBigBlindIdx
            } else {
                isHandOver = true
                winMessage = "Not enough players!"
                return
            }
        }
        
        // Post antes (if any)
        if anteAmount > 0 {
            for i in 0..<players.count where players[i].status == .active {
                postAnte(playerIndex: i, amount: anteAmount)
            }
        }
        
        // Post blinds
        postBlind(playerIndex: smallBlindIndex, amount: smallBlindAmount)
        postBlind(playerIndex: bigBlindIndex, amount: bigBlindAmount)
        
        // Deal hole cards
        DealingManager.dealHoleCards(deck: &deck, players: &players, dealerIndex: dealerIndex)
        
        currentBet = bigBlindAmount
        minRaise = bigBlindAmount
        let newActiveIdx = nextActivePlayerIndex(after: bigBlindIndex)
        if newActiveIdx >= 0 {
            activePlayerIndex = newActiveIdx
        } else {
            // 没有活跃玩家，无法继续
            isHandOver = true
            winMessage = "Not enough players!"
            return
        }
        
        for player in players where player.status == .active {
            hasActed[player.id] = false
        }
        
        actionLog.removeAll()
        
        #if DEBUG
        print("=== Hand #\(handNumber): Dealer=\(players[dealerIndex].name), SB=\(players[smallBlindIndex].name), BB=\(players[bigBlindIndex].name) ===")
        #endif
        
        checkBotTurn()
        
        ActionRecorder.shared.startHand(
            handNumber: handNumber,
            gameMode: gameMode,
            players: players
        )
    }
    
    func endHand() {
        guard !isHandOver else { return }
        
        let eligible = players.filter { $0.status == .active || $0.status == .allIn }
        
        let result: ShowdownResult
        if eligible.count == 1 {
            result = ShowdownManager.distributeSingleWinner(
                winner: eligible[0],
                potTotal: pot.total,
                players: &players
            )
        } else if eligible.count > 1 {
            returnUncalledBets()
            pot.calculatePots(players: players)
            result = ShowdownManager.distributeWithSidePots(
                eligible: eligible,
                pot: pot,
                communityCards: communityCards,
                players: &players
            )
        } else {
            isHandOver = true
            return
        }
        
        winners = result.winnerIDs
        winMessage = result.winMessage
        lastHandLosers = result.loserIDs
        lastPotSize = result.totalPot
        isHandOver = true
        
        // Trigger winner animations
        notifyWinnerAnimations(result: result)
        
        // Record hand end for statistics
        recordHandEnd()
        
        // Check for blind level up in tournaments
        if gameMode == .tournament, let config = tournamentConfig {
            if let levelUp = TournamentManager.checkBlindLevelUp(
                config: config,
                currentLevel: currentBlindLevel,
                handsAtLevel: handsAtCurrentLevel
            ) {
                smallBlindAmount = levelUp.smallBlind
                bigBlindAmount = levelUp.bigBlind
                anteAmount = levelUp.ante
                currentBlindLevel = levelUp.newLevel
                handsAtCurrentLevel = levelUp.handsAtLevel
            } else {
                handsAtCurrentLevel += 1
            }
        }
        
        // Track newly eliminated players
        GameResultsManager.trackEliminations(
            players: players,
            handNumber: handNumber,
            eliminationOrder: &eliminationOrder
        )
        
        // 根据游戏模式处理 AI 入场/离场
        if gameMode == .cashGame, let config = cashGameConfig {
            // 1. sittingOut → eliminated（为新 AI 腾出座位）
            for i in 0..<players.count where players[i].status == .sittingOut {
                players[i].status = .eliminated
            }

            // 2. AI 离场检查
            let departures = CashGameManager.checkAIDepartures(
                players: &players,
                config: config
            )
            for dep in departures {
                actionLog.append(ActionLogEntry(systemMessage: "\(dep.name) 离开了牌桌"))
            }

            // 3. AI 入场检查
            let difficulty = AIProfile.Difficulty.normal
            let newEntries = CashGameManager.checkAIEntries(
                players: &players,
                config: config,
                difficulty: difficulty
            )
            for entry in newEntries {
                actionLog.append(ActionLogEntry(systemMessage: "新玩家 \(entry.name) 入座"))
            }
        } else if gameMode == .tournament {
            // 锦标赛：使用 TournamentManager
            let diffLevel = DecisionEngine.difficultyManager.currentDifficulty
            let difficulty: AIProfile.Difficulty = {
                switch diffLevel {
                case .easy: return .easy
                case .medium: return .normal
                case .hard: return .hard
                case .expert: return .expert
                }
            }()
            let newEntries = TournamentManager.checkAndAddAIEntries(
                players: &players,
                handNumber: handNumber,
                gameMode: gameMode,
                difficulty: difficulty,
                config: tournamentConfig,
                currentBlindLevel: currentBlindLevel
            )
            for newPlayer in newEntries {
                NotificationCenter.default.post(
                    name: NSNotification.Name("TournamentNewEntry"),
                    object: nil,
                    userInfo: ["playerName": newPlayer.name, "chips": newPlayer.chips]
                )
            }
        }

        #if DEBUG
        print("=== Hand #\(handNumber) Over: \(winMessage) ===\n")
        #endif
    }
    
    /// 所有人 All-in 时，快速依次发完剩余公共牌然后结算
    func runOutBoard() {
        let streetsToGo = DealingManager.streetsRemaining(from: currentStreet)

        guard streetsToGo > 0 else {
            endHand()
            return
        }

        // 保存当前手牌标识，用于检测游戏状态变化
        let handId = handNumber

        for i in 0..<streetsToGo {
            let delay = Double(i + 1) * 0.8
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }

                // 检查手牌是否仍是同一手（防止竞态条件）
                // 检查游戏是否已结束
                guard self.handNumber == handId && !self.isHandOver else {
                    #if DEBUG
                    print("⚠️ runOutBoard: 跳过发牌，手牌已变化或游戏已结束")
                    #endif
                    return
                }

                // 再次确认当前 street 仍是预期值（防止重复发牌）
                let expectedStreet: Street
                switch i {
                case 0: expectedStreet = .flop
                case 1: expectedStreet = .turn
                case 2: expectedStreet = .river
                default: return
                }

                guard self.currentStreet == expectedStreet else {
                    #if DEBUG
                    print("⚠️ runOutBoard: 当前 street 不匹配，跳过发牌")
                    #endif
                    return
                }

                DealingManager.dealStreetCards(deck: &self.deck, communityCards: &self.communityCards, currentStreet: &self.currentStreet)

                if i == streetsToGo - 1 {
                    // 最后一条街发完后结算
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self else { return }
                        guard self.handNumber == handId && !self.isHandOver else { return }
                        self.endHand()
                    }
                }
            }
        }
    }
    
    /// 退还未被跟注的筹码
    func returnUncalledBets() {
        // 1. 找到投注最多的玩家（必须是 active 或 allIn）
        let activePlayers = players.filter { $0.status == .active || $0.status == .allIn }
        guard let maxBettor = activePlayers.max(by: { $0.totalBetThisHand < $1.totalBetThisHand }) else { return }
        
        let maxBet = maxBettor.totalBetThisHand
        
        // 2. 检查是否有其他人投了这么多（包括已弃牌的）
        // 我们需要找第二高的投注额
        var secondMaxBet = 0
        var countWithMaxBet = 0
        
        for player in players {
            if player.totalBetThisHand == maxBet {
                countWithMaxBet += 1
            } else if player.totalBetThisHand < maxBet {
                if player.totalBetThisHand > secondMaxBet {
                    secondMaxBet = player.totalBetThisHand
                }
            }
        }
        
        // 如果只有一个人投了 maxBet，说明有多余部分未被跟注
        if countWithMaxBet == 1 {
            let refundAmount = maxBet - secondMaxBet
            if refundAmount > 0 {
                // 执行退款
                if let index = players.firstIndex(where: { $0.id == maxBettor.id }) {
                    players[index].chips += refundAmount
                    players[index].totalBetThisHand -= refundAmount // 修正 totalBet 以便正确计算边池
                    players[index].currentBet -= refundAmount       // 修正 currentBet
                    pot.refund(refundAmount)
                    
                    #if DEBUG
                    print("💰 Refund uncalled bet $\(refundAmount) to \(players[index].name)")
                    #endif
                }
            }
        }
    }
}
