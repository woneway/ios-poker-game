import Foundation
import CoreData

// MARK: - Draw & Board Analysis Helpers

/// Describes the type of draws a player has
struct DrawInfo {
    let hasFlushDraw: Bool       // 4 cards of same suit (need 1 more)
    let hasOpenEndedStraight: Bool  // 4 consecutive (need 1 on either end)
    let hasGutshot: Bool         // Need 1 specific card to complete straight
    let hasComboDraws: Bool      // Flush draw + straight draw
    let flushOuts: Int           // Number of cards that complete flush
    let straightOuts: Int        // Number of cards that complete straight
    
    var totalOuts: Int {
        // Subtract overlap when both flush + straight draws exist
        if hasFlushDraw && (hasOpenEndedStraight || hasGutshot) {
            return flushOuts + straightOuts - 2  // ~2 cards overlap
        }
        return flushOuts + straightOuts
    }
    
    var hasAnyDraw: Bool {
        return hasFlushDraw || hasOpenEndedStraight || hasGutshot
    }
}

/// Board texture analysis
struct BoardTexture {
    let wetness: Double     // 0 = rainbow dry, 1 = monotone connected
    let isPaired: Bool      // Board has a pair
    let isMonotone: Bool    // 3+ cards same suit on board
    let isTwoTone: Bool     // Exactly 2 suits on board
    let hasHighCards: Bool  // Board has A, K, or Q
    let connectivity: Double // 0 = scattered, 1 = very connected
}

class DecisionEngine {
    
    // MARK: - Difficulty Manager
    
    static let difficultyManager = DifficultyManager()
    
    // MARK: - Opponent Modeling
    
    // 对手建模器（每局游戏一个实例）
    static var opponentModels: [String: OpponentModel] = [:]
    
    /// 加载对手模型
    private static func loadOpponentModel(playerName: String, gameMode: GameMode) -> OpponentModel {
        let key = "\(playerName)_\(gameMode.rawValue)"
        if let existing = opponentModels[key] {
            return existing
        }
        
        let model = OpponentModel(playerName: playerName, gameMode: gameMode)
        model.loadStats(from: PersistenceController.shared.container.viewContext)
        opponentModels[key] = model
        return model
    }
    
    /// 清空对手模型（新游戏开始时调用）
    static func resetOpponentModels() {
        opponentModels.removeAll()
    }
    
    // MARK: - Main Decision Entry Point
    
    static func makeDecision(player: Player, engine: PokerEngine) -> PlayerAction {
        let profile = player.aiProfile ?? .fox
        let holeCards = player.holeCards
        let community = engine.communityCards
        let street = engine.currentStreet
        
        let callAmount = engine.currentBet - player.currentBet
        let potSize = engine.pot.total
        let stackSize = player.chips
        let activePlayers = engine.players.filter { $0.status == .active || $0.status == .allIn }.count
        let seatOffset = engine.seatOffsetFromDealer(playerIndex: engine.activePlayerIndex)
        
        // Stack-to-pot ratio
        let spr = potSize > 0 ? Double(stackSize) / Double(potSize) : 20.0
        
        // Is this player the preflop aggressor?
        let isPFR = engine.preflopAggressorID == player.id
        
        // MARK: - Opponent Modeling & Strategy Adjustment
        
        // 1. Check if opponent modeling is enabled (based on difficulty)
        let useOpponentModeling = difficultyManager.shouldUseOpponentModeling()
        
        // 2. Load opponent model (针对当前行动的对手)
        var strategyAdjust = StrategyAdjustment.balanced
        
        if useOpponentModeling {
            // Find the last bettor (the opponent we're facing)
            if let lastBettor = findLastBettor(engine: engine), lastBettor.id != player.id {
                let opponentModel = loadOpponentModel(
                    playerName: lastBettor.name,
                    gameMode: engine.gameMode
                )
                
                // Only apply adjustments if confidence is sufficient
                if opponentModel.confidence > 0.5 {
                    strategyAdjust = OpponentModeler.getStrategyAdjustment(style: opponentModel.style)
                    
                    #if DEBUG
                    print("🎯 \(player.name) 识别对手 \(lastBettor.name) 为 \(opponentModel.style.description)")
                    print("   策略调整：偷盲\(String(format:"%.0f%%", strategyAdjust.stealFreqBonus*100)) 诈唬\(String(format:"%.0f%%", strategyAdjust.bluffFreqAdjust*100))")
                    #endif
                }
            }
        }
        
        // 3. ICM adjustment (tournament mode only)
        var icmAdjust: ICMStrategyAdjustment? = nil
        if engine.gameMode == .tournament {
            let situation = ICMCalculator.analyze(
                myChips: player.chips,
                allChips: engine.players.map { $0.chips },
                payoutStructure: engine.tournamentConfig?.payoutStructure ?? []
            )
            icmAdjust = ICMCalculator.getStrategyAdjustment(situation: situation)
            
            #if DEBUG
            if situation.isBubble {
                print("💰 泡沫期！\(icmAdjust?.description ?? "")")
                print("   筹码比率：\(String(format:"%.2f", situation.stackRatio))")
            }
            #endif
        }
        
        // 4. Apply strategy adjustment to profile
        var adjustedProfile = applyStrategyAdjustment(profile: profile, adjustment: strategyAdjust)
        
        // Apply ICM adjustment to profile
        if let icmAdj = icmAdjust {
            adjustedProfile.tightness -= icmAdj.vpipAdjust
            adjustedProfile.aggression += icmAdj.aggressionAdjust
        }
        
        // MARK: - 1. PreFlop Decision
        if street == .preFlop {
            return preflopDecision(
                player: player, profile: adjustedProfile,
                holeCards: holeCards, engine: engine,
                callAmount: callAmount, potSize: potSize,
                seatOffset: seatOffset, activePlayers: activePlayers,
                spr: spr, strategyAdjust: strategyAdjust,
                icmAdjust: icmAdjust
            )
        }
        
        // MARK: - 2. PostFlop Decision (Flop/Turn/River)
        return postflopDecision(
            player: player, profile: adjustedProfile,
            holeCards: holeCards, community: community,
            engine: engine, street: street,
            callAmount: callAmount, potSize: potSize,
            seatOffset: seatOffset, activePlayers: activePlayers,
            spr: spr, isPFR: isPFR, strategyAdjust: strategyAdjust,
            icmAdjust: icmAdjust
        )
    }
    
    // MARK: - Helper Methods for Opponent Modeling
    
    /// Find the last player who bet/raised
    private static func findLastBettor(engine: PokerEngine) -> Player? {
        // Find the player with the highest currentBet who is still active
        var lastBettor: Player? = nil
        var highestBet = 0
        
        for player in engine.players {
            if player.currentBet > highestBet && player.status == .active {
                highestBet = player.currentBet
                lastBettor = player
            }
        }
        
        return lastBettor
    }
    
    /// Determine the last action taken by a player based on their bet
    private static func determineLastAction(engine: PokerEngine, player: Player) -> PostflopAction {
        // Check current bet to infer action
        if player.currentBet == 0 {
            return .check
        } else if player.currentBet > engine.bigBlindAmount {
            // If they have a bet out, they either bet or raised
            return .raise
        } else {
            return .call
        }
    }
    
    /// Apply strategy adjustment to AI profile
    private static func applyStrategyAdjustment(
        profile: AIProfile,
        adjustment: StrategyAdjustment
    ) -> AIProfile {
        var adjusted = profile
        
        // Adjust bluff frequency
        adjusted.bluffFreq = max(0.01, min(0.80, profile.bluffFreq + adjustment.bluffFreqAdjust))
        
        // Adjust call-down tendency
        adjusted.callDownTendency = max(0.05, min(0.95, profile.callDownTendency + adjustment.callDownAdjust))
        
        // Note: stealFreqBonus and valueSizeAdjust are applied in specific decision functions
        
        return adjusted
    }
    
    /// Collect betting history for current hand
    /// - Parameters:
    ///   - engine: The poker engine
    ///   - street: Current street
    /// - Returns: Array of BetAction representing betting history
    private static func collectBetHistory(engine: PokerEngine, street: Street) -> [BetAction] {
        var history: [BetAction] = []
        
        // This is a simplified version - in production you'd track this in PokerEngine
        // For now, just record the current street's action if there's a bet
        if engine.currentBet > engine.bigBlindAmount {
            history.append(BetAction(
                street: street,
                type: .bet,
                amount: engine.currentBet
            ))
        }
        
        // TODO: In a full implementation, PokerEngine should track all betting actions
        // across all streets for proper triple barrel detection
        
        return history
    }
    
    // MARK: - PreFlop Decision
    
    private static func preflopDecision(
        player: Player, profile: AIProfile,
        holeCards: [Card], engine: PokerEngine,
        callAmount: Int, potSize: Int,
        seatOffset: Int, activePlayers: Int,
        spr: Double, strategyAdjust: StrategyAdjustment,
        icmAdjust: ICMStrategyAdjustment?
    ) -> PlayerAction {
        
        let chenScore = chenFormula(holeCards)
        let handStrength = chenToNormalized(chenScore)
        let threshold = profile.preflopThreshold(seatOffset: seatOffset, totalPlayers: engine.players.count)
        
        let isPremium = chenScore >= 10     // AA, KK, QQ, AKs, AKo
        let isStrong = chenScore >= 7       // JJ, TT, AQs, AJs, KQs
        let isPlayable = handStrength > threshold
        
        let facingRaise = callAmount > engine.bigBlindAmount
        let facing3Bet = callAmount > engine.bigBlindAmount * 3
        
        // GTO AI uses a separate decision path
        if profile.name == "艾米" {
            return gtoPreflopDecision(
                holeCards: holeCards, engine: engine,
                callAmount: callAmount, seatOffset: seatOffset,
                activePlayers: activePlayers, chenScore: chenScore
            )
        }
        
        print("🧠 \(player.name)[\(profile.name)] preflop: chen=\(String(format:"%.1f",chenScore)) str=\(String(format:"%.2f",handStrength)) thr=\(String(format:"%.2f",threshold)) call=\(callAmount) pos=\(seatOffset)")
        
        // Facing a 3-bet+
        if facing3Bet {
            if isPremium {
                // 4-bet or all-in with premiums
                if spr < 4 || player.chips < callAmount * 3 {
                    return .allIn
                }
                return .raise(engine.currentBet * 3)
            }
            // foldTo3Bet: probability to fold facing a 3-bet (with non-premium hands)
            if Double.random(in: 0...1) < profile.foldTo3Bet {
                return .fold
            }
            return isStrong ? .call : .fold
        }
        
        // Facing a raise (2-bet)
        if facingRaise {
            if isPremium {
                // 3-bet with premiums
                let reraiseAmount = engine.currentBet * 3
                if Double.random(in: 0...1) < profile.effectiveAggression {
                    return .raise(reraiseAmount)
                }
                // Slow-play (trap) sometimes with AA/KK
                if chenScore >= 12 && Double.random(in: 0...1) < 0.2 {
                    return .call
                }
                return .raise(reraiseAmount)
            }
            if isStrong {
                // 3-bet with strong hands based on aggression
                if Double.random(in: 0...1) < profile.effectiveAggression * 0.55 {
                    return .raise(engine.currentBet * 3)
                }
                return .call
            }
            if isPlayable {
                // Call with playable hands (set-mining with pairs, suited connectors)
                return .call
            }
            // Bluff 3-bet (steal attempt)
            if Double.random(in: 0...1) < profile.effectiveBluffFreq * 0.25 {
                return .raise(engine.currentBet * 3)
            }
            return .fold
        }
        
        // No raise yet - BB option (can check)
        if callAmount == 0 {
            if isStrong && Double.random(in: 0...1) < profile.effectiveAggression {
                return .raise(engine.bigBlindAmount * 3)
            }
            return .check
        }
        
        // Standard open (just facing blinds)
        if isPlayable {
            // Apply steal frequency adjustment (opponent + ICM)
            let stealBonus = strategyAdjust.stealFreqBonus + (icmAdjust?.stealBonus ?? 0.0)
            let adjustedAggression = profile.effectiveAggression + (seatOffset <= 1 ? stealBonus : 0.0)
            
            if Double.random(in: 0...1) < adjustedAggression {
                // Open raise: 2.5-3BB + 0.5BB per limper
                let openSize = engine.bigBlindAmount * 3 + engine.bigBlindAmount * max(0, activePlayers - 4) / 2
                return .raise(openSize)
            }
            // Limp (calling station / passive behavior)
            return .call
        }
        
        // Below threshold - fold or bluff
        if Double.random(in: 0...1) < profile.effectiveBluffFreq * 0.15 {
            return .raise(engine.bigBlindAmount * 3)
        }
        return .fold
    }
    
    // MARK: - GTO PreFlop Decision
    
    /// Academic AI uses position-based opening ranges and balanced 3-bet construction
    private static func gtoPreflopDecision(
        holeCards: [Card], engine: PokerEngine,
        callAmount: Int, seatOffset: Int,
        activePlayers: Int, chenScore: Double
    ) -> PlayerAction {
        
        // GTO opening ranges by position (minimum Chen score to open)
        // Based on standard 8-max GTO solver outputs
        let openThreshold: Double
        switch seatOffset {
        case 3: openThreshold = 7.0   // UTG: ~14% of hands (88+, ATs+, KQs, AJo+)
        case 4: openThreshold = 6.5   // UTG+1: ~17%
        case 5: openThreshold = 6.0   // MP: ~20%
        case 6: openThreshold = 5.0   // HJ: ~25%
        case 7: openThreshold = 4.0   // CO: ~30%
        case 0: openThreshold = 3.0   // BTN: ~42%
        case 1: openThreshold = 4.5   // SB: ~30% (3-bet or fold preferred)
        case 2: openThreshold = 2.0   // BB: defend ~45% vs BTN open
        default: openThreshold = 5.0
        }
        
        let facing3Bet = callAmount > engine.bigBlindAmount * 3
        let facingRaise = callAmount > engine.bigBlindAmount
        
        // Facing 3-bet: only continue with top ~15% of opening range
        if facing3Bet {
            if chenScore >= 10 {
                // 4-bet value range: AA, KK, QQ, AKs
                return .raise(engine.currentBet * 2 + engine.currentBet / 2)
            }
            if chenScore >= 7 {
                // Call range: JJ, TT, AQs, AKo
                return Double.random(in: 0...1) < 0.55 ? .call : .fold
            }
            // Add bluff 4-bets with ~appropriate ratio (1 bluff per 2 value)
            if chenScore >= 5 && Double.random(in: 0...1) < 0.12 {
                return .raise(engine.currentBet * 2 + engine.currentBet / 2)
            }
            return .fold
        }
        
        // Facing 2-bet: 3-bet or call based on GTO ranges
        if facingRaise {
            if chenScore >= 10 {
                // 3-bet for value
                return .raise(engine.currentBet * 3)
            }
            if chenScore >= 7 {
                // Mixed strategy: 3-bet 35%, call 65%
                return Double.random(in: 0...1) < 0.35 ? .raise(engine.currentBet * 3) : .call
            }
            if chenScore >= openThreshold - 1 {
                // Call with playable hands that have good implied odds
                return Double.random(in: 0...1) < 0.6 ? .call : .fold
            }
            // Bluff 3-bet with appropriate blocker hands (~8% of fold range)
            if Double.random(in: 0...1) < 0.08 {
                return .raise(engine.currentBet * 3)
            }
            return .fold
        }
        
        // BB option
        if callAmount == 0 {
            if chenScore >= 8 && Double.random(in: 0...1) < 0.5 {
                return .raise(engine.bigBlindAmount * 3)
            }
            return .check
        }
        
        // Opening: raise or fold (GTO prefers raise over limp)
        if chenScore >= openThreshold {
            let openSize = engine.bigBlindAmount * 3
            return .raise(openSize)
        }
        
        // SB: 3-bet or fold (no limping in GTO)
        if seatOffset == 1 {
            return .fold
        }
        
        return .fold
    }
    
    // MARK: - PostFlop Decision
    
    private static func postflopDecision(
        player: Player, profile: AIProfile,
        holeCards: [Card], community: [Card],
        engine: PokerEngine, street: Street,
        callAmount: Int, potSize: Int,
        seatOffset: Int, activePlayers: Int,
        spr: Double, isPFR: Bool, strategyAdjust: StrategyAdjustment,
        icmAdjust: ICMStrategyAdjustment?
    ) -> PlayerAction {
        
        // Calculate equity via Monte Carlo
        let iterations = street == .river ? 200 : 500
        let equity = MonteCarloSimulator.calculateEquity(
            holeCards: holeCards,
            communityCards: community,
            playerCount: max(activePlayers, 2),
            iterations: iterations
        )
        
        // Pot odds
        let potOdds = callAmount > 0 ? Double(callAmount) / Double(potSize + callAmount) : 0.0
        
        // Hand strength evaluation
        let handEval = HandEvaluator.evaluate(holeCards: holeCards, communityCards: community)
        let category = handEval.0
        
        // Draw analysis
        let draws = analyzeDraws(holeCards: holeCards, communityCards: community)
        
        // Board texture analysis
        let board = analyzeBoardTexture(community)
        
        // MARK: - Opponent Range Tracking (Task 4)
        
        var opponentRange: HandRange? = nil
        
        // Only use range thinking at hard/expert difficulty
        if difficultyManager.shouldUseRangeThinking() {
            if let lastBettor = findLastBettor(engine: engine), lastBettor.id != player.id {
                // Get opponent's position
                let opponentIndex = engine.players.firstIndex(where: { $0.id == lastBettor.id }) ?? 0
                let opponentSeatOffset = engine.seatOffsetFromDealer(playerIndex: opponentIndex)
                let opponentPosition = Position.from(seatOffset: opponentSeatOffset)
                
                // Estimate preflop range
                opponentRange = RangeAnalyzer.estimateRange(
                    position: opponentPosition,
                    action: .raise,  // Assume they raised preflop
                    facingRaise: false
                )
                
                // Narrow based on postflop action
                if var range = opponentRange {
                    let lastAction = determineLastAction(engine: engine, player: lastBettor)
                    RangeAnalyzer.narrowRange(range: &range, action: lastAction, board: board)
                    opponentRange = range
                    
                    #if DEBUG
                    print("📊 对手翻后范围：\(range.description)")
                    #endif
                }
            }
        }
        
        let hasStrongHand = category >= 3   // Trips or better
        let hasDecentHand = category >= 1   // At least a pair
        
        print("🧠 \(player.name)[\(profile.name)] \(street.rawValue): eq=\(String(format:"%.2f",equity)) potOdds=\(String(format:"%.2f",potOdds)) hand=\(category) draws=\(draws.totalOuts)outs wet=\(String(format:"%.1f",board.wetness)) pfr=\(isPFR)")
        
        // GTO AI uses separate postflop path
        if profile.name == "艾米" {
            return gtoPostflopDecision(
                player: player, holeCards: holeCards,
                community: community, engine: engine,
                street: street, callAmount: callAmount,
                potSize: potSize, equity: equity,
                potOdds: potOdds, category: category,
                draws: draws, board: board,
                isPFR: isPFR, spr: spr
            )
        }
        
        // MARK: - Facing no bet (can check or bet)
        if callAmount == 0 {
            return noBetDecision(
                profile: profile, equity: equity,
                category: category, hasStrongHand: hasStrongHand,
                hasDecentHand: hasDecentHand, draws: draws,
                board: board, potSize: potSize, engine: engine,
                seatOffset: seatOffset, spr: spr, isPFR: isPFR,
                street: street, strategyAdjust: strategyAdjust
            )
        }
        
        // MARK: - Facing a bet
        return facingBetDecision(
            player: player, profile: profile,
            equity: equity, potOdds: potOdds,
            category: category, hasStrongHand: hasStrongHand,
            hasDecentHand: hasDecentHand, draws: draws,
            board: board, callAmount: callAmount,
            potSize: potSize, engine: engine, spr: spr,
            street: street, strategyAdjust: strategyAdjust
        )
    }
    
    // MARK: - No Bet Decision (Check or Bet)
    
    private static func noBetDecision(
        profile: AIProfile, equity: Double,
        category: Int, hasStrongHand: Bool,
        hasDecentHand: Bool, draws: DrawInfo,
        board: BoardTexture, potSize: Int,
        engine: PokerEngine, seatOffset: Int,
        spr: Double, isPFR: Bool, street: Street,
        strategyAdjust: StrategyAdjustment
    ) -> PlayerAction {
        
        let bb = engine.bigBlindAmount
        
        // Value bet with strong hands
        if hasStrongHand {
            let betProb = profile.effectiveAggression * 0.9
            if Double.random(in: 0...1) < betProb {
                // Apply value size adjustment
                let baseSizeFactor = board.wetness > 0.6 ? 0.75 : 0.50
                let adjustedSizeFactor = baseSizeFactor * (1.0 + strategyAdjust.valueSizeAdjust)
                let betSize = max(bb, Int(Double(potSize) * adjustedSizeFactor))
                return .raise(betSize)
            }
            // Slow-play (trap) occasionally with monsters
            if category >= 5 && Double.random(in: 0...1) < 0.25 {
                return .check
            }
            return .check
        }
        
        // C-bet as preflop aggressor
        if isPFR {
            let cbetProb: Double
            if street == .flop {
                cbetProb = profile.cbetFreq
            } else {
                cbetProb = profile.cbetTurnFreq
            }
            
            // C-bet more on dry boards, less on wet boards
            let adjustedCbet = cbetProb + (board.wetness < 0.4 ? 0.10 : -0.10)
            
            if hasDecentHand || equity > 0.50 || draws.hasAnyDraw {
                if Double.random(in: 0...1) < adjustedCbet {
                    let betSize = max(bb, Int(Double(potSize) * (board.wetness > 0.5 ? 0.60 : 0.33)))
                    return .raise(betSize)
                }
            }
        }
        
        // Semi-bluff with draws
        if draws.hasAnyDraw && street != .river {
            let semiBluffProb = profile.effectiveAggression * 0.5
            if draws.hasComboDraws {
                // Combo draws are strong enough to bet aggressively
                if Double.random(in: 0...1) < semiBluffProb + 0.25 {
                    let betSize = max(bb, potSize * 2 / 3)
                    return .raise(betSize)
                }
            }
            if draws.hasFlushDraw || draws.hasOpenEndedStraight {
                if Double.random(in: 0...1) < semiBluffProb {
                    let betSize = max(bb, potSize / 2)
                    return .raise(betSize)
                }
            }
        }
        
        // Pure bluff (position bonus on BTN)
        let posBonus = seatOffset == 0 ? 0.12 : (seatOffset == 7 ? 0.06 : 0.0)
        if Double.random(in: 0...1) < profile.effectiveBluffFreq * 0.35 + posBonus {
            let betSize = max(bb, potSize / 3)
            return .raise(betSize)
        }
        
        return .check
    }
    
    // MARK: - Facing Bet Decision
    
    private static func facingBetDecision(
        player: Player, profile: AIProfile,
        equity: Double, potOdds: Double,
        category: Int, hasStrongHand: Bool,
        hasDecentHand: Bool, draws: DrawInfo,
        board: BoardTexture, callAmount: Int,
        potSize: Int, engine: PokerEngine,
        spr: Double, street: Street,
        strategyAdjust: StrategyAdjustment
    ) -> PlayerAction {
        
        // MARK: - Bluff Detection (Expert difficulty only)
        
        var bluffIndicator: BluffIndicator? = nil
        
        if difficultyManager.shouldUseBluffDetection() {
            if let lastBettor = findLastBettor(engine: engine), lastBettor.id != player.id {
                let opponentModel = loadOpponentModel(
                    playerName: lastBettor.name,
                    gameMode: engine.gameMode
                )
                
                if opponentModel.confidence > 0.5 {
                    let betHistory = collectBetHistory(engine: engine, street: street)
                    bluffIndicator = BluffDetector.calculateBluffProbability(
                        opponent: opponentModel,
                        board: board,
                        betHistory: betHistory,
                        potSize: potSize
                    )
                    
                    #if DEBUG
                    if let indicator = bluffIndicator {
                        print("🎲 诈唬检测：概率 \(String(format:"%.1f%%", indicator.bluffProbability * 100))")
                        print("   信号：\(indicator.signals.map { $0.rawValue }.joined(separator: ", "))")
                        print("   建议：\(indicator.recommendation)")
                    }
                    #endif
                }
            }
        }
        
        // Apply bluff detection to calling decision
        if let indicator = bluffIndicator, indicator.confidence > 0.6 {
            if indicator.bluffProbability > 0.6 {
                // High bluff probability: widen calling range
                if hasDecentHand || equity > potOdds * 0.7 {
                    return .call
                }
            } else if indicator.bluffProbability < 0.3 {
                // Low bluff probability: tighten calling range
                if !hasStrongHand {
                    return .fold
                }
            }
        }
        
        // Monster hand: raise/re-raise
        if category >= 5 {
            if spr < 3 || player.chips <= callAmount * 2 {
                return .allIn
            }
            let raiseAmount = engine.currentBet + max(engine.minRaise, potSize * 2 / 3)
            return .raise(raiseAmount)
        }
        
        // Strong hand: usually raise
        if hasStrongHand {
            if Double.random(in: 0...1) < profile.effectiveAggression * 0.7 {
                let raiseAmount = engine.currentBet + max(engine.minRaise, potSize / 2)
                return .raise(raiseAmount)
            }
            return .call
        }
        
        // Calling station special: calls with any pair or draw
        if profile.callDownTendency > 0.6 {
            if hasDecentHand || draws.hasAnyDraw {
                if Double.random(in: 0...1) < profile.effectiveCallDown {
                    return .call
                }
            }
            // Even without a pair, calling stations call light
            let betRelative = Double(callAmount) / max(1.0, Double(potSize))
            if betRelative < 0.5 && Double.random(in: 0...1) < profile.effectiveCallDown * 0.6 {
                return .call
            }
        }
        
        // Positive EV call (equity > pot odds)
        if equity > potOdds {
            if equity > 0.65 && Double.random(in: 0...1) < profile.effectiveAggression * 0.5 {
                let raiseAmount = engine.currentBet + engine.minRaise
                return .raise(raiseAmount)
            }
            return .call
        }
        
        // Drawing hands: consider implied odds
        if draws.hasAnyDraw && street != .river {
            let impliedOdds = spr > 5  // Good implied odds when deep
            let drawEquity = Double(draws.totalOuts) * (street == .flop ? 0.04 : 0.02)
            
            if draws.hasComboDraws {
                // Combo draws often have enough equity to semi-bluff raise
                if Double.random(in: 0...1) < profile.effectiveAggression * 0.6 {
                    let raiseAmount = engine.currentBet + engine.minRaise
                    return .raise(raiseAmount)
                }
                return .call
            }
            
            if drawEquity + (impliedOdds ? 0.08 : 0.0) > potOdds {
                if Double.random(in: 0...1) > profile.effectiveTightness * 0.4 {
                    return .call
                }
            }
        }
        
        // Decent hand but bad odds
        if hasDecentHand {
            // Player-specific: call-down tendency
            if Double.random(in: 0...1) < profile.effectiveCallDown {
                return .call
            }
        }
        
        // Bluff raise
        if Double.random(in: 0...1) < profile.effectiveBluffFreq * 0.25 {
            let raiseAmount = engine.currentBet + engine.minRaise * 2
            return .raise(raiseAmount)
        }
        
        // Small bet - loose players might call
        let betRelativeToPot = Double(callAmount) / max(1.0, Double(potSize))
        if betRelativeToPot < 0.25 && Double.random(in: 0...1) > profile.effectiveTightness * 0.6 {
            return .call
        }
        
        return .fold
    }
    
    // MARK: - GTO PostFlop Decision
    
    /// Academic AI: uses balanced value/bluff ratios based on bet sizing
    private static func gtoPostflopDecision(
        player: Player, holeCards: [Card],
        community: [Card], engine: PokerEngine,
        street: Street, callAmount: Int,
        potSize: Int, equity: Double,
        potOdds: Double, category: Int,
        draws: DrawInfo, board: BoardTexture,
        isPFR: Bool, spr: Double
    ) -> PlayerAction {
        
        let bb = engine.bigBlindAmount
        
        // No bet to face (check or bet)
        if callAmount == 0 {
            // GTO bet sizing depends on hand polarization
            // Value range: strong made hands + best draws
            // Bluff range: weakest hands with some equity (blockers)
            
            let isValueHand = category >= 2 || (category >= 1 && equity > 0.60)
            let isSemiBluff = draws.hasAnyDraw && equity > 0.35
            let isPureBluff = !isValueHand && !isSemiBluff && equity < 0.30
            
            // GTO c-bet frequency depends on board texture
            if isPFR {
                let cbetFreq: Double
                if board.wetness < 0.3 {
                    cbetFreq = 0.70  // Bet often on dry boards with range advantage
                } else if board.wetness < 0.6 {
                    cbetFreq = 0.50  // Mixed on medium boards
                } else {
                    cbetFreq = 0.30  // Check more on wet boards
                }
                
                if isValueHand || isSemiBluff {
                    if Double.random(in: 0...1) < cbetFreq {
                        // Bet size: small on dry (1/3 pot), medium on wet (2/3 pot)
                        let size = board.wetness < 0.4 ? potSize / 3 : potSize * 2 / 3
                        return .raise(max(bb, size))
                    }
                }
                
                // GTO bluff frequency: maintain ~value:bluff ratio based on bet size
                // 1/3 pot → opponent needs 20% equity → can bluff ~29% of betting range
                // 2/3 pot → opponent needs 29% equity → can bluff ~40% of betting range
                if isPureBluff {
                    let bluffProb: Double = board.wetness < 0.4 ? 0.15 : 0.10
                    if Double.random(in: 0...1) < bluffProb {
                        let size = board.wetness < 0.4 ? potSize / 3 : potSize * 2 / 3
                        return .raise(max(bb, size))
                    }
                }
            }
            
            // Not the PFR: check-raise with traps, otherwise check
            if category >= 4 && Double.random(in: 0...1) < 0.3 {
                // Set trap (check, plan to raise)
                return .check
            }
            
            return .check
        }
        
        // Facing a bet: use Minimum Defense Frequency (MDF)
        // MDF = 1 - bet_size / (pot + bet_size)
        let mdf = 1.0 - Double(callAmount) / Double(potSize + callAmount)
        
        // Must defend at least MDF% of range to prevent opponent from profiting with any bluff
        // Defending = calling + raising
        
        // Raise range: ~10-15% of defending range (strong value + bluffs)
        if category >= 4 || (category >= 3 && equity > 0.75) {
            // Value raise
            if spr < 3 || player.chips <= callAmount * 2 {
                return .allIn
            }
            let raiseAmount = engine.currentBet + max(engine.minRaise, Int(Double(potSize) * 0.75))
            return .raise(raiseAmount)
        }
        
        // Bluff raise (balanced: ~1 bluff raise per 2 value raises)
        if draws.hasComboDraws && Double.random(in: 0...1) < 0.25 {
            let raiseAmount = engine.currentBet + engine.minRaise
            return .raise(raiseAmount)
        }
        
        // Call range: hands with equity above pot odds
        if equity > potOdds {
            return .call
        }
        
        // Draw calls with implied odds
        if draws.hasAnyDraw && street != .river {
            let drawEquity = Double(draws.totalOuts) * (street == .flop ? 0.04 : 0.02)
            let impliedBonus = spr > 5 ? 0.06 : 0.0
            if drawEquity + impliedBonus > potOdds {
                return .call
            }
        }
        
        // MDF defense: call with marginal hands to prevent exploitation
        if equity > potOdds * 0.8 && Double.random(in: 0...1) < mdf * 0.5 {
            return .call
        }
        
        return .fold
    }
    
    // MARK: - Chen Formula (Standard Preflop Hand Strength)
    
    /// Bill Chen's formula for starting hand strength
    /// Returns a score from -1.5 to 20
    /// Reference: "The Mathematics of Poker" by Bill Chen
    static func chenFormula(_ cards: [Card]) -> Double {
        guard cards.count == 2 else { return 0.0 }
        
        let r1 = cards[0].rank.rawValue  // 0=2, 1=3, ..., 12=Ace
        let r2 = cards[1].rank.rawValue
        let high = max(r1, r2)
        let low = min(r1, r2)
        let isPair = r1 == r2
        let isSuited = cards[0].suit == cards[1].suit
        let gap = high - low
        
        var score: Double
        
        // Step 1: Score the highest card
        switch high {
        case 12: score = 10.0  // Ace
        case 11: score = 8.0   // King
        case 10: score = 7.0   // Queen
        case 9:  score = 6.0   // Jack
        default: score = Double(high + 2) / 2.0  // 2→2, 3→2.5, 4→3, ..., 10→6
        }
        
        // Step 2: Pairs - multiply by 2, minimum 5
        if isPair {
            score = max(5.0, score * 2.0)
            return score  // Pairs don't get gap/suited adjustments
        }
        
        // Step 3: Suited bonus
        if isSuited {
            score += 2.0
        }
        
        // Step 4: Gap penalty
        switch gap {
        case 1: break              // Connected: no penalty
        case 2: score -= 1.0       // 1-gap
        case 3: score -= 2.0       // 2-gap
        case 4: score -= 4.0       // 3-gap
        default: score -= 5.0      // 4+ gap
        }
        
        // Step 5: Straight bonus for low connected cards
        // If both cards are ≤ Q and gap ≤ 2, add +1
        if gap <= 2 && high <= 10 {
            score += 1.0
        }
        
        return max(-1.5, score)
    }
    
    /// Normalize Chen score to 0-1 range for threshold comparison
    /// Chen range: roughly -1.5 to 20 (AA=20)
    static func chenToNormalized(_ chen: Double) -> Double {
        return max(0.0, min(1.0, (chen + 1.5) / 21.5))
    }
    
    // MARK: - Draw Analysis
    
    /// Analyze flush and straight draws
    static func analyzeDraws(holeCards: [Card], communityCards: [Card]) -> DrawInfo {
        let allCards = holeCards + communityCards
        
        // --- Flush Draw ---
        var suitCounts: [Suit: Int] = [:]
        for card in allCards {
            suitCounts[card.suit, default: 0] += 1
        }
        let maxSuitCount = suitCounts.values.max() ?? 0
        let hasFlushDraw = maxSuitCount == 4 && communityCards.count < 5
        let flushOuts = hasFlushDraw ? (13 - maxSuitCount) : 0  // 9 outs for flush draw
        
        // --- Straight Draw ---
        let ranks = Set(allCards.map { $0.rank.rawValue })
        // Add 13 for Ace-low (Ace can be 0 in A-2-3-4-5)
        var rankSet = ranks
        if ranks.contains(12) { rankSet.insert(-1) }
        
        _ = rankSet.sorted()  // Kept for potential future use
        var hasOESD = false     // Open-ended straight draw
        var hasGutshot = false   // Gutshot (1 card needed in the middle)
        var straightOuts = 0
        
        // Check for 4-card sequences (OESD) and gapped sequences (gutshot)
        if communityCards.count >= 3 && communityCards.count < 5 {
            // Sliding window of 5 consecutive ranks
            for baseRank in -1...9 {
                let window = Set(baseRank...(baseRank + 4))
                let overlap = window.intersection(rankSet)
                if overlap.count == 4 {
                    // 4 out of 5 consecutive ranks present
                    let missing = window.subtracting(rankSet)
                    if let missingRank = missing.first {
                        if missingRank == baseRank || missingRank == baseRank + 4 {
                            // Missing card is on the end → OESD (8 outs)
                            if !hasOESD {
                                hasOESD = true
                                straightOuts = 8
                            }
                        } else {
                            // Missing card is in the middle → Gutshot (4 outs)
                            if !hasOESD && !hasGutshot {
                                hasGutshot = true
                                straightOuts = 4
                            }
                        }
                    }
                }
            }
        }
        
        let hasCombo = hasFlushDraw && (hasOESD || hasGutshot)
        
        return DrawInfo(
            hasFlushDraw: hasFlushDraw,
            hasOpenEndedStraight: hasOESD,
            hasGutshot: hasGutshot,
            hasComboDraws: hasCombo,
            flushOuts: flushOuts,
            straightOuts: straightOuts
        )
    }
    
    // MARK: - Board Texture Analysis
    
    /// Analyze how wet/dry and connected a board is
    static func analyzeBoardTexture(_ community: [Card]) -> BoardTexture {
        guard !community.isEmpty else {
            return BoardTexture(wetness: 0, isPaired: false, isMonotone: false,
                              isTwoTone: false, hasHighCards: false, connectivity: 0)
        }
        
        // Suit analysis
        var suitCounts: [Suit: Int] = [:]
        for card in community {
            suitCounts[card.suit, default: 0] += 1
        }
        let maxSuit = suitCounts.values.max() ?? 0
        let isMonotone = maxSuit >= 3
        let isTwoTone = suitCounts.count == 2
        
        // Pair analysis
        let ranks = community.map { $0.rank.rawValue }
        let uniqueRanks = Set(ranks)
        let isPaired = uniqueRanks.count < community.count
        
        // High card analysis
        let hasHighCards = ranks.contains(where: { $0 >= 10 })  // Q, K, A
        
        // Connectivity: how many cards are within 4 of each other
        let sorted = ranks.sorted()
        var connScore = 0.0
        for i in 0..<sorted.count {
            for j in (i+1)..<sorted.count {
                let diff = sorted[j] - sorted[i]
                if diff <= 4 { connScore += 1.0 }
            }
        }
        let maxConn = Double(sorted.count * (sorted.count - 1)) / 2.0
        let connectivity = maxConn > 0 ? connScore / maxConn : 0
        
        // Wetness calculation (0-1)
        var wetness = 0.0
        if isMonotone { wetness += 0.40 }
        else if isTwoTone { wetness += 0.15 }
        
        wetness += connectivity * 0.35
        if isPaired { wetness -= 0.10 }  // Paired boards are drier
        
        wetness = max(0.0, min(1.0, wetness))
        
        return BoardTexture(
            wetness: wetness,
            isPaired: isPaired,
            isMonotone: isMonotone,
            isTwoTone: isTwoTone,
            hasHighCards: hasHighCards,
            connectivity: connectivity
        )
    }
}
