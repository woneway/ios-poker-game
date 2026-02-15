import Foundation
import CoreData

// MARK: - EV Calculation Models

/// Represents the expected value of a potential action
struct ExpectedValue {
    let action: PlayerAction
    let ev: Double
    let reason: String
    
    static func compare(_ a: ExpectedValue, _ b: ExpectedValue) -> ExpectedValue {
        return a.ev >= b.ev ? a : b
    }
}

/// Action options with their calculated EVs
struct ActionEV {
    let action: PlayerAction
    let equity: Double      // Win probability
    let potOdds: Double     // Break-even equity needed
    let impliedOdds: Double // Implied odds bonus
    let ev: Double          // Expected value
    
    /// Determine if this action is +EV
    var isPositiveEV: Bool {
        return equity > potOdds
    }
}

// MARK: - Draw & Board Analysis Helpers

/// Describes the type of draws a player has
struct DrawInfo {
    let hasFlushDraw: Bool       // 4 cards of same suit (need 1 more)
    let hasOpenEndedStraight: Bool  // 4 consecutive (need 1 on either end)
    let hasGutshot: Bool         // Need 1 specific card to complete straight
    let hasComboDraws: Bool      // Flush draw + straight draw
    let flushOuts: Int           // Number of cards that complete flush
    let straightOuts: Int        // Number of cards that complete straight
    let overlap: Int             // Cards that complete both draws
    
    init(hasFlushDraw: Bool, hasOpenEndedStraight: Bool, hasGutshot: Bool, 
         hasComboDraws: Bool, flushOuts: Int, straightOuts: Int, overlap: Int = 0) {
        self.hasFlushDraw = hasFlushDraw
        self.hasOpenEndedStraight = hasOpenEndedStraight
        self.hasGutshot = hasGutshot
        self.hasComboDraws = hasComboDraws
        self.flushOuts = flushOuts
        self.straightOuts = straightOuts
        self.overlap = overlap
    }
    
    var totalOuts: Int {
        // Subtract actual overlap when both flush + straight draws exist
        if hasComboDraws {
            return flushOuts + straightOuts - overlap
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

    // MARK: - Constants

    /// Default opponent call probability for EV calculation
    private static let defaultOpponentCallProb: Double = 0.5

    /// Default opponent range for EV calculation
    private static let defaultOpponentRange: Double = 0.5

    /// SPR thresholds for implied odds
    private static let sprHighThreshold: Double = 10.0
    private static let sprMediumThreshold: Double = 5.0
    private static let sprTurnHighThreshold: Double = 8.0
    private static let sprTurnMediumThreshold: Double = 4.0

    /// Implied odds bonuses
    private static let impliedOddsFlopHigh: Double = 0.15
    private static let impliedOddsFlopMedium: Double = 0.08
    private static let impliedOddsTurnHigh: Double = 0.10
    private static let impliedOddsTurnMedium: Double = 0.05

    /// Tendency adjustment factors
    private static let raiseTendencyFactor: Double = 0.1
    private static let callTendencyFactor: Double = 0.05
    private static let aggressionMidpoint: Double = 0.5

    // MARK: - Difficulty Manager

    static let difficultyManager = DifficultyManager()

    // MARK: - Opponent Modeling

    // 使用引擎实例作为 key 的一部分，避免全局状态污染
    // key 格式: "ObjectIdentifier_gameMode"
    // 注意：fileprivate 以便测试可以访问
    fileprivate static var opponentModels: [String: OpponentModel] = [:]

    /// 测试辅助：获取对手模型数量
    #if DEBUG
    static var opponentModelCount: Int {
        return opponentModels.count
    }
    #endif

    /// 加载对手模型
    private static func loadOpponentModel(playerName: String, gameMode: GameMode, engineIdentifier: ObjectIdentifier) -> OpponentModel {
        let key = "\(engineIdentifier)_\(playerName)_\(gameMode.rawValue)"
        if let existing = opponentModels[key] {
            return existing
        }

        let model = OpponentModel(playerName: playerName, gameMode: gameMode)
        model.loadStats(from: PersistenceController.shared.container.viewContext)
        opponentModels[key] = model
        return model
    }

    /// 清空对手模型（新游戏开始时调用）
    /// 同时清理所有引擎对应的模型，避免内存泄漏
    static func resetOpponentModels() {
        opponentModels.removeAll()
    }

    /// 清理特定引擎的模型
    static func resetOpponentModels(for engine: PokerEngine) {
        let engineId = ObjectIdentifier(engine)
        opponentModels = opponentModels.filter { !$0.key.hasPrefix("\(engineId)_") }
    }

    // MARK: - EV Calculation Core

    /// Calculate the expected value of calling
    /// - Parameters:
    ///   - equity: Win probability
    ///   - callAmount: Cost to call
    ///   - potSize: Current pot size (does NOT include our call amount)
    /// - Returns: Expected value as multiplier of call amount
    static func calculateCallEV(
        equity: Double,
        callAmount: Int,
        potSize: Int,
        opponentRange: Double = defaultOpponentRange
    ) -> Double {
        guard callAmount > 0 else { return 0 }

        // EV = p(win) * pot - p(lose) * call_amount
        // When we win: we get the entire pot (opponent's bet is already in pot)
        // When we lose: we lose our call amount
        let winValue = equity * Double(potSize)
        let loseValue = (1.0 - equity) * Double(callAmount)

        return winValue - loseValue
    }

    /// Calculate the expected value of raising
    static func calculateRaiseEV(
        equity: Double,
        raiseAmount: Int,
        currentBet: Int,
        potSize: Int,
        opponentCallProb: Double = defaultOpponentCallProb
    ) -> Double {
        guard raiseAmount > 0 else { return 0 }

        // When raise, opponent may fold, call, or re-raise
        // Simplified: consider fold equity + when called, our equity

        // If opponent folds (1 - opponentCallProb), we win the pot
        let foldEquity = (1.0 - opponentCallProb) * Double(potSize)

        // If opponent calls, our EV = equity * (pot + raise) - (1-equity) * raise
        let callEV = opponentCallProb * (
            equity * Double(potSize + raiseAmount * 2) - (1.0 - equity) * Double(raiseAmount)
        )

        return foldEquity + callEV
    }

    /// Calculate pot odds
    static func calculatePotOdds(callAmount: Int, potSize: Int) -> Double {
        guard callAmount > 0 else { return 0 }
        return Double(callAmount) / Double(potSize + callAmount)
    }

    /// Calculate implied odds based on SPR
    static func calculateImpliedOdds(spr: Double, street: Street) -> Double {
        // Higher SPR = more room to extract value = higher implied odds
        var baseImplied: Double = 0
        switch street {
        case .flop:
            baseImplied = spr > sprHighThreshold ? impliedOddsFlopHigh : (spr > sprMediumThreshold ? impliedOddsFlopMedium : 0)
        case .turn:
            baseImplied = spr > sprTurnHighThreshold ? impliedOddsTurnHigh : (spr > sprTurnMediumThreshold ? impliedOddsTurnMedium : 0)
        case .river:
            baseImplied = 0 // No implied odds on river
        default:
            baseImplied = 0
        }
        return baseImplied
    }

    /// Determine best action based on EV calculation
    static func selectBestAction(
        availableActions: [PlayerAction],
        equity: Double,
        callAmount: Int,
        potSize: Int,
        spr: Double,
        street: Street,
        profile: AIProfile
    ) -> PlayerAction {
        let potOdds = calculatePotOdds(callAmount: callAmount, potSize: potSize)
        let impliedOdds = calculateImpliedOdds(spr: spr, street: street)
        let totalOdds = potOdds + impliedOdds

        var bestEV = Double.infinity
        var bestAction: PlayerAction = .fold

        for action in availableActions {
            let ev: Double
            switch action {
            case .call:
                ev = calculateCallEV(
                    equity: equity,
                    callAmount: callAmount,
                    potSize: potSize
                )
            case .raise(let amount):
                // Estimate opponent call probability based on profile
                let opponentCallProb = 1.0 - profile.foldTo3Bet
                ev = calculateRaiseEV(
                    equity: equity,
                    raiseAmount: amount,
                    currentBet: callAmount,
                    potSize: potSize,
                    opponentCallProb: opponentCallProb
                )
            case .check:
                ev = 0 // Check has 0 cost, EV = 0
            case .fold:
                ev = 0 // Folding has 0 EV (we give up, but lose nothing extra)
            case .allIn:
                let allInAmount = callAmount // All-in effectively caps at call amount
                ev = calculateCallEV(
                    equity: equity,
                    callAmount: allInAmount,
                    potSize: potSize
                )
            }

            // Factor in player's tendency: aggressive players prefer raise, passive prefer call
            let tendencyAdjustment: Double
            switch action {
            case .raise:
                tendencyAdjustment = (profile.aggression - aggressionMidpoint) * raiseTendencyFactor
            case .call:
                tendencyAdjustment = (aggressionMidpoint - profile.aggression) * callTendencyFactor
            default:
                tendencyAdjustment = 0
            }

            let adjustedEV = ev + tendencyAdjustment

            if adjustedEV > bestEV {
                bestEV = adjustedEV
                bestAction = action
            }
        }

        return bestAction
    }
    
    /// Check if action is +EV based on pot odds
    static func isPositiveEV(equity: Double, callAmount: Int, potSize: Int, spr: Double, street: Street) -> Bool {
        let potOdds = calculatePotOdds(callAmount: callAmount, potSize: potSize)
        let impliedOdds = calculateImpliedOdds(spr: spr, street: street)
        return equity > (potOdds - impliedOdds)
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
                    gameMode: engine.gameMode,
                    engineIdentifier: ObjectIdentifier(engine)
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
        
        // ===== 基于EV的决策 =====
        
        // Facing a 3-bet+
        if facing3Bet {
            // Premium hands: 4-bet or all-in
            if isPremium {
                if spr < 4 || player.chips < callAmount * 3 {
                    return .allIn
                }
                return .raise(engine.currentBet * 3)
            }
            
            // Use foldTo3Bet tendency deterministically
            // If hand strength is below threshold relative to fold tendency, fold
            let shouldFold = (1.0 - handStrength) < profile.foldTo3Bet
            if shouldFold && !isStrong {
                return .fold
            }
            
            // Strong hands call, weak hands fold
            return isStrong ? .call : .fold
        }
        
        // Facing a raise (2-bet)
        if facingRaise {
            if isPremium {
                // 3-bet with premiums - use aggression to determine raise vs call
                let reraiseAmount = engine.currentBet * 3
                
                // Higher aggression = more likely to raise
                if profile.effectiveAggression > 0.6 {
                    return .raise(reraiseAmount)
                } else if profile.effectiveAggression > 0.3 {
                    // Medium aggression: raise with AA/KK, call with others
                    if chenScore >= 12 {
                        return .raise(reraiseAmount)
                    }
                }
                return .call
            }
            
            if isStrong {
                // Strong hands: 3-bet based on aggression
                if profile.effectiveAggression > 0.5 {
                    return .raise(engine.currentBet * 3)
                }
                return .call
            }
            
            if isPlayable {
                // Call with playable hands (set-mining with pairs, suited connectors)
                return .call
            }
            
            // Bluff 3-bet only if hand has some potential and aggression is high enough
            if handStrength > 0.15 && profile.effectiveBluffFreq > 0.2 {
                return .raise(engine.currentBet * 3)
            }
            
            return .fold
        }
        
        // No raise yet - BB option (can check)
        if callAmount == 0 {
            if isStrong && profile.effectiveAggression > 0.5 {
                return .raise(engine.bigBlindAmount * 3)
            }
            return .check
        }
        
        // Standard open (just facing blinds)
        if isPlayable {
            // Apply steal frequency adjustment (opponent + ICM)
            let stealBonus = strategyAdjust.stealFreqBonus + (icmAdjust?.stealBonus ?? 0.0)
            
            // Use aggression + position bonus to decide raise vs limp
            let adjustedAggression = profile.effectiveAggression + (seatOffset <= 1 ? stealBonus : 0.0)
            
            // Higher aggression = open raise, lower = limp
            if adjustedAggression > 0.55 {
                // Open raise: 3BB + 0.5BB per limper
                let openSize = engine.bigBlindAmount * 3 + engine.bigBlindAmount * max(0, activePlayers - 4) / 2
                return .raise(openSize)
            }
            
            // Limp (calling station / passive behavior)
            return .call
        }
        
        // Below threshold - could be a steal attempt from late position
        // Only attempt steal from good position with high enough aggression
        let isLatePosition = seatOffset == 0 || seatOffset == 7  // BTN or CO
        if isLatePosition && profile.effectiveBluffFreq > 0.15 {
            let stealSize = engine.bigBlindAmount * 3
            return .raise(stealSize)
        }
        
        return .fold
    }
    
    // MARK: - GTO PreFlop Decision
    
    /// Academic AI uses position-based opening ranges and balanced 3-bet construction
    /// Modified to use deterministic decisions based on hand strength thresholds
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
        
        // Use hand strength hash for deterministic but varied decisions
        let handHash = abs(holeCards.reduce(0) { $0 &+ $1.hashValue })
        
        // Facing 3-bet: only continue with top ~15% of opening range
        if facing3Bet {
            if chenScore >= 10 {
                // 4-bet value range: AA, KK, QQ, AKs
                return .raise(engine.currentBet * 2 + engine.currentBet / 2)
            }
            if chenScore >= 7 {
                // Call range: JJ, TT, AQs, AKo
                // Use hash for deterministic mixed strategy
                return handHash % 100 < 55 ? .call : .fold
            }
            // Add bluff 4-bets with ~appropriate ratio (1 bluff per 2 value)
            // Use hash for deterministic decision
            if chenScore >= 5 && handHash % 100 < 12 {
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
                // Mixed strategy: use hash for deterministic distribution
                return handHash % 100 < 35 ? .raise(engine.currentBet * 3) : .call
            }
            if chenScore >= openThreshold - 1 {
                // Call with playable hands that have good implied odds
                return handHash % 100 < 60 ? .call : .fold
            }
            // Bluff 3-bet with appropriate blocker hands (~8% of fold range)
            if handHash % 100 < 8 {
                return .raise(engine.currentBet * 3)
            }
            return .fold
        }
        
        // BB option
        if callAmount == 0 {
            if chenScore >= 8 && handHash % 100 < 50 {
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
                if let range = opponentRange {
                    let lastAction = determineLastAction(engine: engine, player: lastBettor)
                    let narrowedRange = RangeAnalyzer.narrowRange(range: range, action: lastAction, board: board)
                    opponentRange = narrowedRange
                    
                    #if DEBUG
                    print("📊 对手翻后范围：\(narrowedRange.description)")
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
        
        // Value bet with strong hands based on aggression
        if hasStrongHand {
            // Higher aggression = more likely to bet for value
            if profile.effectiveAggression > 0.5 {
                // Apply value size adjustment
                let baseSizeFactor = board.wetness > 0.6 ? 0.75 : 0.50
                let adjustedSizeFactor = baseSizeFactor * (1.0 + strategyAdjust.valueSizeAdjust)
                let betSize = max(bb, Int(Double(potSize) * adjustedSizeFactor))
                return .raise(betSize)
            }
            // Slow-play with monsters (very strong hands)
            if category >= 5 {
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
            
            // Use cbet probability directly as threshold
            if hasDecentHand || equity > 0.50 || draws.hasAnyDraw {
                if adjustedCbet > 0.5 {
                    let betSize = max(bb, Int(Double(potSize) * (board.wetness > 0.5 ? 0.60 : 0.33)))
                    return .raise(betSize)
                }
            }
        }
        
        // Semi-bluff with draws
        if draws.hasAnyDraw && street != .river {
            if draws.hasComboDraws {
                // Combo draws are strong enough to bet aggressively
                if profile.effectiveAggression > 0.5 {
                    let betSize = max(bb, potSize * 2 / 3)
                    return .raise(betSize)
                }
            }
            if draws.hasFlushDraw || draws.hasOpenEndedStraight {
                if profile.effectiveAggression > 0.4 {
                    let betSize = max(bb, potSize / 2)
                    return .raise(betSize)
                }
            }
        }
        
        // Pure bluff - only from late position with high aggression
        let isLatePosition = seatOffset == 0 || seatOffset == 7
        if isLatePosition && profile.effectiveBluffFreq > 0.2 && equity < 0.35 {
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
                    gameMode: engine.gameMode,
                    engineIdentifier: ObjectIdentifier(engine)
                )
                
                if opponentModel.confidence > 0.5 {
                    // Use engine's betting history
                    let betHistory = engine.bettingHistory[street] ?? []
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
        
        // Strong hand: usually raise based on aggression
        if hasStrongHand {
            if profile.effectiveAggression > 0.5 {
                let raiseAmount = engine.currentBet + max(engine.minRaise, potSize / 2)
                return .raise(raiseAmount)
            }
            return .call
        }
        
        // Calling station special: calls with any pair or draw based on tendency
        if profile.callDownTendency > 0.6 {
            if hasDecentHand || draws.hasAnyDraw {
                return .call
            }
            // Even without a pair, calling stations call light
            let betRelative = Double(callAmount) / max(1.0, Double(potSize))
            if betRelative < 0.5 {
                return .call
            }
        }
        
        // ===== EV-based decision =====
        
        // Calculate total odds including implied odds
        let impliedOdds = calculateImpliedOdds(spr: spr, street: street)
        let totalOdds = potOdds + impliedOdds
        
        // Positive EV call (equity > total odds)
        if equity > totalOdds {
            // With high equity and aggression, consider raising
            if equity > 0.65 && profile.effectiveAggression > 0.6 {
                let raiseAmount = engine.currentBet + engine.minRaise
                return .raise(raiseAmount)
            }
            return .call
        }
        
        // Drawing hands: consider implied odds
        if draws.hasAnyDraw && street != .river {
            let impliedBonus = spr > 5 ? 0.08 : 0.0
            let drawEquity = Double(draws.totalOuts) * (street == .flop ? 0.04 : 0.02)
            
            if draws.hasComboDraws {
                // Combo draws: raise with high aggression
                if profile.effectiveAggression > 0.5 {
                    let raiseAmount = engine.currentBet + engine.minRaise
                    return .raise(raiseAmount)
                }
                return .call
            }
            
            // Regular draws: call if equity + implied > pot odds
            if drawEquity + impliedBonus > potOdds {
                return .call
            }
        }
        
        // Decent hand but bad odds - use callDown tendency
        if hasDecentHand {
            if profile.effectiveCallDown > 0.5 {
                return .call
            }
        }
        
        // Small bet - loose players might call
        let betRelativeToPot = Double(callAmount) / max(1.0, Double(potSize))
        if betRelativeToPot < 0.25 && profile.effectiveTightness < 0.5 {
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
        
        // Use hand hash for deterministic mixed strategy decisions
        let handHash = abs(holeCards.reduce(0) { $0 &+ $1.hashValue })
        
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
                    // Use hash for deterministic decision
                    if handHash % 100 < Int(cbetFreq * 100) {
                        // Bet size: small on dry (1/3 pot), medium on wet (2/3 pot)
                        let size = board.wetness < 0.4 ? potSize / 3 : potSize * 2 / 3
                        return .raise(max(bb, size))
                    }
                }
                
                // GTO bluff frequency: maintain ~value:bluff ratio based on bet size
                if isPureBluff {
                    let bluffProb: Double = board.wetness < 0.4 ? 0.15 : 0.10
                    if handHash % 100 < Int(bluffProb * 100) {
                        let size = board.wetness < 0.4 ? potSize / 3 : potSize * 2 / 3
                        return .raise(max(bb, size))
                    }
                }
            }
            
            // Not the PFR: check-raise with traps, otherwise check
            if category >= 4 && handHash % 100 < 30 {
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
        if draws.hasComboDraws && handHash % 100 < 25 {
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
        // Use hash for deterministic mixed strategy
        if equity > potOdds * 0.8 && handHash % 100 < Int(mdf * 50) {
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
        
        // Calculate actual flush outs considering hole cards
        // Find the suit with 4 cards
        var flushSuit: Suit? = nil
        for (suit, count) in suitCounts where count == 4 {
            flushSuit = suit
            break
        }
        
        var flushOuts = 0
        if hasFlushDraw, let suit = flushSuit {
            // Count remaining cards of this suit in deck
            // 13 total - already have maxSuitCount
            flushOuts = 13 - maxSuitCount
        }
        
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
        
        // Calculate overlap between flush and straight draws
        // When both draws exist, some cards may complete both
        var overlap = 0
        if hasCombo, let suit = flushSuit {
            // Count cards of the flush suit that also complete straight
            for rank in rankSet.sorted() {
                if rank == -1 { continue } // Skip Ace-low placeholder
                // Check if this rank would complete straight
                let neededRank = missingStraightRank(communityCards: communityCards, holeCards: holeCards)
                // Simplified: if we have OESD or gutshot, some flush cards complete straight too
                if hasOESD || hasGutshot {
                    // Estimate 1-2 cards overlap on average
                    overlap = 1
                }
            }
        }
        
        return DrawInfo(
            hasFlushDraw: hasFlushDraw,
            hasOpenEndedStraight: hasOESD,
            hasGutshot: hasGutshot,
            hasComboDraws: hasCombo,
            flushOuts: flushOuts,
            straightOuts: straightOuts,
            overlap: overlap
        )
    }
    
    /// Helper to determine missing straight rank (simplified)
    private static func missingStraightRank(communityCards: [Card], holeCards: [Card]) -> Int? {
        // Simplified: just return nil since exact calculation is complex
        return nil
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
