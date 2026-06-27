import Foundation
import CoreData

// Import calculators for DRY refactoring
// These functions were duplicated in DecisionEngine and are now centralized
// EVCalculator uses static methods, PotOddsCalculator uses singleton

private let logger = AppLogger.shared

// 这些类型已移至 DecisionModels.swift
// import DecisionModels

// 确定性随机数生成器（用于测试）
#if DEBUG
private struct DeterministicRandom {
    private static var seed: UInt64 = 0
    private static var isSeeded = false
    
    static func seed(_ newSeed: UInt64) {
        seed = newSeed
        isSeeded = true
    }
    
    static func reset() {
        isSeeded = false
    }
    
    static func random(in range: ClosedRange<Double>) -> Double {
        if isSeeded {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let diff = range.upperBound - range.lowerBound
            return range.lowerBound + Double(seed % 1000000) / 1000000.0 * diff
        } else {
            return Double.random(in: range)
        }
    }
    
    static func random(in range: ClosedRange<Int>) -> Int {
        if isSeeded {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let diff = range.upperBound - range.lowerBound + 1
            return range.lowerBound + Int(seed % UInt64(diff))
        } else {
            return Int.random(in: range)
        }
    }
    
    static func randomElement<T>(from array: [T]) -> T? {
        if isSeeded, !array.isEmpty {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return array[Int(seed % UInt64(array.count))]
        } else {
            return array.randomElement()
        }
    }
}
#endif

// MARK: - Decision Engine Protocol

/// 决策引擎协议，支持依赖注入
protocol DecisionEngineProtocol {
    func makeDecision(player: Player, engine: PokerEngine) -> PlayerAction
    func publishDecision(player: Player, action: PlayerAction, equity: Double, potOdds: Double)
}

/// 默认实现，使用静态方法
final class DefaultDecisionEngine: DecisionEngineProtocol {
    static let shared = DefaultDecisionEngine()

    func makeDecision(player: Player, engine: PokerEngine) -> PlayerAction {
        DecisionEngine.makeDecision(player: player, engine: engine)
    }

    func publishDecision(player: Player, action: PlayerAction, equity: Double, potOdds: Double) {
        DecisionEngine.publishDecision(player: player, action: action, equity: equity, potOdds: potOdds)
    }
}

class DecisionEngine {

    // MARK: - Dependency Injection

    /// 可选的决策引擎实例，用于依赖注入
    /// 如果为 nil，则使用静态方法（向后兼容）
    static var injectedEngine: DecisionEngineProtocol?

    /// 检查是否使用了注入的引擎
    static var isUsingInjectedEngine: Bool {
        injectedEngine != nil
    }

    // MARK: - Constants

    /// 默认对手 call probability for EV calculation
    private static let defaultOpponentCallProb: Double = GameConstants.AI.defaultOpponentCallProb

    /// 测试辅助：随机数生成器（可设置种子以实现确定性测试）
#if DEBUG
    private static var randomGenerator: RandomGenerator = .system
#endif
    
    /// 测试辅助：随机数来源
#if DEBUG
    enum RandomGenerator {
        case system  // 使用系统随机数
        case seeded(Int)  // 使用固定种子
        
        func random(in range: ClosedRange<Double>) -> Double {
            switch self {
            case .system:
                return Double.random(in: range)
            case .seeded(let seed):
                DeterministicRandom.seed(UInt64(seed))
                return DeterministicRandom.random(in: range)
            }
        }
        
        func randomElement<T>(from array: [T]) -> T? {
            switch self {
            case .system:
                return array.randomElement()
            case .seeded(let seed):
                DeterministicRandom.seed(UInt64(seed))
                return DeterministicRandom.randomElement(from: array)
            }
        }
        
        func random(in range: ClosedRange<Int>) -> Int {
            switch self {
            case .system:
                return Int.random(in: range)
            case .seeded(let seed):
                DeterministicRandom.seed(UInt64(seed))
                return DeterministicRandom.random(in: range)
            }
        }
    }
    
    /// 测试辅助：设置随机数生成器
    static func debugSetRandomGenerator(_ generator: RandomGenerator) {
        randomGenerator = generator
    }
    
    /// 测试辅助：重置为系统随机数
    static func debugResetRandomGenerator() {
        randomGenerator = .system
        DeterministicRandom.reset()
    }
#endif

    /// Default opponent range for EV calculation
    private static let defaultOpponentRange: Double = GameConstants.AI.defaultOpponentRange

    /// SPR thresholds for implied odds
    private static let sprHighThreshold: Double = GameConstants.AI.sprHighThreshold
    private static let sprMediumThreshold: Double = GameConstants.AI.sprMediumThreshold
    private static let sprTurnHighThreshold: Double = GameConstants.AI.sprTurnHighThreshold
    private static let sprTurnMediumThreshold: Double = GameConstants.AI.sprTurnMediumThreshold

    /// Implied odds bonuses
    private static let impliedOddsFlopHigh: Double = GameConstants.AI.impliedOddsFlopHigh
    private static let impliedOddsFlopMedium: Double = GameConstants.AI.impliedOddsFlopMedium
    private static let impliedOddsTurnHigh: Double = GameConstants.AI.impliedOddsTurnHigh
    private static let impliedOddsTurnMedium: Double = GameConstants.AI.impliedOddsTurnMedium

    /// Tendency adjustment factors
    private static let raiseTendencyFactor: Double = GameConstants.AI.raiseTendencyFactor
    private static let callTendencyFactor: Double = GameConstants.AI.callTendencyFactor
    private static let aggressionMidpoint: Double = GameConstants.AI.aggressionMidpoint

    // MARK: - Difficulty Manager

    static let difficultyManager = DifficultyManager()

    // MARK: - Opponent Modeling

    // 使用引擎实例作为 key 的一部分，避免全局状态污染
    // key 格式: "ObjectIdentifier_gameMode_playerName"
    // 注意：fileprivate 以便测试可以访问
    fileprivate static var opponentModels: [String: OpponentModel] = [:]

    // 追踪活跃的引擎标识符，用于自动清理
    private static var activeEngineIds: Set<ObjectIdentifier> = []

    // 线程安全：使用串行队列保护静态状态
    private static let stateQueue = DispatchQueue(label: "com.poker.decisionengine.state")

    // 最大对手模型数量限制，防止内存无限增长
    private static let maxModelCount = GameConstants.AI.maxModelCount

    // 上次清理的时间戳
    private static var lastCleanupTime: Date = Date()
    /// 清理时间间隔（秒）
    private static let cleanupInterval: TimeInterval = GameConstants.AI.cleanupInterval

    // 定时器用于定期清理（防止引擎未正确注销时的内存泄漏）
    private static var cleanupTimer: Timer?

    /// 测试辅助：获取对手模型数量
#if DEBUG
    static var opponentModelCount: Int {
        stateQueue.sync {
            return opponentModels.count
        }
    }
#endif

    /// 启动定期清理定时器（通常在应用启动时调用）
    static func startPeriodicCleanup() {
        DispatchQueue.main.async {
            cleanupTimer?.invalidate()
            // 每30秒执行一次清理（比cleanupInterval更频繁，作为安全网）
            cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                performPeriodicCleanup()
            }
        }
    }

    /// 停止定期清理定时器（通常在应用退出时调用）
    static func stopPeriodicCleanup() {
        DispatchQueue.main.async {
            cleanupTimer?.invalidate()
            cleanupTimer = nil
        }
    }

    /// 执行定期清理（定时器回调）
    private static func performPeriodicCleanup() {
        stateQueue.async {
            cleanupInactiveModelsLocked()
        }
    }

    /// 注册一个活跃的引擎（在新游戏开始时调用）
    static func registerEngine(_ engine: PokerEngine) {
        stateQueue.sync {
            // 先清理失效的引擎ID（确保只保留有效的）
            performStaleEngineCleanupLocked()
            activeEngineIds.insert(ObjectIdentifier(engine))
            performCleanupIfNeededLocked()

            #if DEBUG
            logger.debug("注册引擎，当前模型数: \(opponentModels.count)", category: .game)
            #endif
        }
    }

    /// 注销一个引擎（在新游戏结束时调用）
    static func unregisterEngine(_ engine: PokerEngine) {
        stateQueue.sync {
            let engineId = ObjectIdentifier(engine)
            activeEngineIds.remove(engineId)

            // 清理该引擎的所有对手模型
            let previousCount = opponentModels.count
            opponentModels = opponentModels.filter { !$0.key.hasPrefix("\(engineId)_") }
            let removedCount = previousCount - opponentModels.count

            #if DEBUG
            logger.debug("注销引擎，清理模型数: \(removedCount)，剩余模型数: \(opponentModels.count)", category: .game)
            #endif
        }
    }

    /// 清理已失效的引擎ID（对象已被销毁但ID仍在集合中）
    private static func performStaleEngineCleanupLocked() {
        // 由于无法直接检查 ObjectIdentifier 是否有效，
        // 我们在每次注册时清理过期的模型数据
        // 保留最近注册的引擎对应的模型
        let activeIdPrefixes = activeEngineIds.map { "\($0)_" }

        opponentModels = opponentModels.filter { key, _ in
            activeIdPrefixes.contains { key.hasPrefix($0) }
        }
    }
    
    /// 如果需要则执行清理（需在 stateQueue 内调用）
    private static func performCleanupIfNeededLocked() {
        let now = Date()
        
        // 检查是否需要清理：时间间隔到了 或者 模型数量超过限制
        if now.timeIntervalSince(lastCleanupTime) > cleanupInterval || opponentModels.count > maxModelCount {
            cleanupInactiveModelsLocked()
            lastCleanupTime = now
        }
    }
    
    /// 清理不再活跃的引擎对应的模型（需在 stateQueue 内调用）
    private static func cleanupInactiveModelsLocked() {
        let activeIds = activeEngineIds.map { "\($0)_" }

        // 保留活跃引擎的模型，清理不活跃的
        opponentModels = opponentModels.filter { key, _ in
            activeIds.contains { key.hasPrefix($0) }
        }

        // 如果仍然超过限制，按 LRU 策略清理最旧的模型
        if opponentModels.count > maxModelCount {
            // 按键排序（简单地移除最早的）并保留 maxModelCount 个
            let keysToRemove = Array(opponentModels.keys.sorted().dropLast(maxModelCount))
            for key in keysToRemove {
                opponentModels.removeValue(forKey: key)
            }
        }

#if DEBUG
        #if DEBUG
        logger.debug("对手模型清理完成，剩余模型数: \(opponentModels.count)", category: .game)
        #endif
#endif
    }

    /// 强制清理所有不活跃模型（供外部调用的安全方法）
    private static func forceCleanupAllInactive() {
        stateQueue.async {
            cleanupInactiveModelsLocked()
        }
    }
    
    /// 加载对手模型（线程安全）
    private static func loadOpponentModel(playerName: String, gameMode: GameMode, engineIdentifier: ObjectIdentifier) -> OpponentModel {
        // 定期清理（在队列内执行）
        performCleanupIfNeededLocked()
        
        let key = "\(engineIdentifier)_\(playerName)_\(gameMode.rawValue)"
        
        // 检查是否已存在（在队列内）
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
    /// - Note: Now delegates to EVCalculator to avoid duplication
    static func calculateCallEV(
        equity: Double,
        callAmount: Int,
        potSize: Int,
        opponentRange: Double = defaultOpponentRange
    ) -> Double {
        EVCalculator.calculateCallEV(
            equity: equity,
            callAmount: callAmount,
            potSize: potSize,
            opponentRange: opponentRange
        )
    }

    /// Calculate the expected value of raising
    /// - Note: Now delegates to EVCalculator to avoid duplication
    static func calculateRaiseEV(
        equity: Double,
        raiseAmount: Int,
        currentBet: Int,
        potSize: Int,
        opponentCallProb: Double = defaultOpponentCallProb
    ) -> Double {
        EVCalculator.calculateRaiseEV(
            equity: equity,
            raiseAmount: raiseAmount,
            currentBet: currentBet,
            potSize: potSize,
            opponentCallProb: opponentCallProb
        )
    }

    /// Calculate pot odds
    /// - Note: Now delegates to PotOddsCalculator to avoid duplication
    static func calculatePotOdds(callAmount: Int, potSize: Int) -> Double {
        PotOddsCalculator.shared.calculateDirectOdds(callAmount: callAmount, potSize: potSize)
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
        profile: AIProfile,
        stackSize: Int,  // 玩家当前筹码量，用于计算 all-in 金额
        learnedAction: PlayerAction? = nil  // 从AI学习系统获得的决策
    ) -> PlayerAction {
        let potOdds = calculatePotOdds(callAmount: callAmount, potSize: potSize)
        let impliedOdds = calculateImpliedOdds(spr: spr, street: street)
        
        var bestEV = -Double.infinity
        var bestAction: PlayerAction = .fold
        
        // Quick check: if equity > potOdds + impliedOdds, we have +EV situation
        let totalOdds = potOdds + impliedOdds
        let isPositiveEV = equity > totalOdds
        
        // Apply small bias towards learned action if available
        let learnedBias: Double
        if learnedAction != nil {
            learnedBias = 0.15  // 15% bias towards learned action
        } else {
            learnedBias = 0.0
        }
        
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
                // 修复: all-in 应该使用玩家的全部筹码来计算 EV
                // 当玩家 all-in 时，他们押上全部筹码，而不是只跟注 callAmount
                let allInAmount = stackSize + callAmount  // 全部筹码 = 剩余筹码 + 跟注金额
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
            
            // Bonus for +EV situations
            var finalEV = adjustedEV
            if isPositiveEV {
                switch action {
                case .call, .raise, .allIn:
                    finalEV += 0.1  // Small bonus for +EV actions
                default:
                    break
                }
            }
            
            // Bonus for learned action from AI learning system
            if let learned = learnedAction {
                var isLearnedAction = false
                switch (action, learned) {
                case (.fold, .fold): isLearnedAction = true
                case (.check, .check): isLearnedAction = true
                case (.call, .call): isLearnedAction = true
                case (.raise, .raise): isLearnedAction = true
                case (.allIn, .allIn): isLearnedAction = true
                default: isLearnedAction = false
                }
                if isLearnedAction {
                    finalEV += learnedBias
                }
            }
            
            if finalEV > bestEV {
                bestEV = finalEV
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
        // 如果使用了注入的引擎，委托给它处理
        if let injected = injectedEngine {
            return injected.makeDecision(player: player, engine: engine)
        }

        // 默认实现：使用静态方法
        return makeDecisionInternal(player: player, engine: engine)
    }

    /// 内部实现，保留原有逻辑
    private static func makeDecisionInternal(player: Player, engine: PokerEngine) -> PlayerAction {
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
                    logger.debug("\(player.name) 识别对手 \(lastBettor.name) 为 \(opponentModel.style.description)", category: .game)
                    logger.debug("策略调整：偷盲\(String(format:"%.0f%%", strategyAdjust.stealFreqBonus*100)) 诈唬\(String(format:"%.0f%%", strategyAdjust.bluffFreqAdjust*100))", category: .game)
#endif
                }
            }
        }
        
        // 3. 使用AI系统增强决策
        // 获取对手下注模式
        var patternAdjust = 0.0
        if let lastBettor = findLastBettor(engine: engine), lastBettor.id != player.id {
            let opponentId = lastBettor.id.uuidString
            let pattern = BettingPatternRecognizer.shared.recognizePattern(for: opponentId)
            
            // 根据对手模式调整策略
            switch pattern {
            case .aggressive:
                // 对手凶，跟注更紧，偷盲更激进
                patternAdjust = -0.1
            case .passive:
                // 对手弱，可以多偷盲
                patternAdjust = 0.15
            case .tight:
                // 对手紧，可能有强牌
                patternAdjust = -0.05
            case .loose:
                // 对手松，可以多价值下注
                patternAdjust = 0.1
            case .balanced:
                patternAdjust = 0.0
            }
            
#if DEBUG
            #if DEBUG
            logger.debug("\(player.name) 识别对手下注模式: \(pattern.description)，调整: \(String(format: "%.0f%%", patternAdjust * 100))", category: .game)
            #endif
#endif
        }
        
        // 4. ICM adjustment (tournament mode only)
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
                #if DEBUG
                logger.debug("泡沫期！\(icmAdjust?.description ?? "")", category: .game)
                logger.debug("筹码比率：\(String(format:"%.2f", situation.stackRatio))", category: .game)
                #endif
            }
#endif
        }
        
        // 4. Apply strategy adjustment to profile
        var adjustedProfile = applyStrategyAdjustment(profile: profile, adjustment: strategyAdjust)
        
        // Apply pattern adjustment (from BettingPatternRecognizer)
        adjustedProfile.aggression += patternAdjust
        
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
    
    // MARK: - AI Decision Publishing

    static func publishDecision(
        player: Player,
        action: PlayerAction,
        equity: Double,
        potOdds: Double
    ) {
        // 如果使用了注入的引擎，委托给它处理
        if let injected = injectedEngine {
            injected.publishDecision(player: player, action: action, equity: equity, potOdds: potOdds)
            return
        }

        // 默认实现：使用静态方法
        publishDecisionInternal(
            player: player,
            action: action,
            equity: equity,
            potOdds: potOdds
        )
    }

    /// 内部实现，保留原有逻辑
    private static func publishDecisionInternal(
        player: Player,
        action: PlayerAction,
        equity: Double,
        potOdds: Double
    ) {
        let reasoning = generateDecisionReasoning(
            player: player,
            action: action,
            equity: equity,
            potOdds: potOdds
        )

        GameEventPublisher.shared.publishAIDecision(
            playerID: player.id,
            playerName: player.name,
            action: action.description,
            reasoning: reasoning,
            equity: equity,
            potOdds: potOdds,
            confidence: player.aiProfile?.aggression ?? 0.5
        )
    }
    
    private static func generateDecisionReasoning(
        player: Player,
        action: PlayerAction,
        equity: Double,
        potOdds: Double
    ) -> String {
        switch action {
        case .fold:
            return "手牌强度不足，选择弃牌"
        case .check:
            return "过牌保留机会"
        case .call:
            if equity > potOdds {
                return "底池赔率合适，跟注"
            }
            return "跟注看转牌"
        case .raise:
            if equity > 0.6 {
                return "强牌价值下注"
            }
            return "半诈偷盲"
        case .allIn:
            return "全下all-in"
        }
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
        if profile.useGTOStrategy {
            // Get GTO strength factor (0.0-1.0)
            let gtoStrength = profile.gtoStrength

            // Use GTO Tournament ICM strategy in tournament mode
            if engine.gameMode == .tournament, let tournamentConfig = engine.tournamentConfig {
                let situation = ICMCalculator.analyze(
                    myChips: player.chips,
                    allChips: engine.players.map { $0.chips },
                    payoutStructure: tournamentConfig.payoutStructure
                )

                // If in bubble or final table, use ICM strategy
                if situation.isBubble || situation.playersRemaining <= 6 {
                    let equity = MonteCarloSimulator.calculateEquity(
                        holeCards: holeCards,
                        communityCards: [],
                        playerCount: activePlayers,
                        iterations: 200
                    )

                    return gtoTournamentICMStrategy(
                        holeCards: holeCards,
                        equity: equity,
                        situation: situation,
                        potSize: potSize,
                        betToFace: callAmount,
                        bb: engine.bigBlindAmount
                    )
                }
            }

            // Apply mixed strategy based on GTO strength
            let gtoAction = gtoPreflopDecision(
                holeCards: holeCards, engine: engine,
                callAmount: callAmount, seatOffset: seatOffset,
                activePlayers: activePlayers, chenScore: chenScore
            )

            // Lower gtoStrength = more conservative play
            if gtoStrength < 0.8 {
                // With lower GTO strength, sometimes choose safer option
                let safeAction: PlayerAction = facingRaise ? .call : .check
                return gtoMixedStrategy(
                    optimalAction: gtoAction,
                    safeAction: safeAction,
                    gtoStrength: gtoStrength,
                    equity: handStrength
                )
            }

            return gtoAction
        }
        
        #if DEBUG
        logger.debug("\(player.name)[\(profile.name)] preflop: chen=\(String(format:"%.1f",chenScore)) str=\(String(format:"%.2f",handStrength)) thr=\(String(format:"%.2f",threshold)) call=\(callAmount) pos=\(seatOffset)", category: .game)
        #endif
        
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
    /// Now integrated with GTOStrategy for enhanced gameplay
    private static func gtoPreflopDecision(
        holeCards: [Card], engine: PokerEngine,
        callAmount: Int, seatOffset: Int,
        activePlayers: Int, chenScore: Double
    ) -> PlayerAction {
        
        // Get position from seat offset
        let position = Position.from(seatOffset: seatOffset)
        
        // Use GTO opening ranges from GTOStrategy
        let gtoRange = RangeAnalyzer.gtoOpeningRange(position: position, tableSize: activePlayers)
        let openThreshold = gtoRange.rangeWidth * 20  // Convert width to Chen threshold approximation
        
        let facing3Bet = callAmount > engine.bigBlindAmount * 3
        let facingRaise = callAmount > engine.bigBlindAmount
        
        // Use hand strength hash for deterministic but varied decisions
        let handHash = abs(holeCards.reduce(0) { $0 &+ $1.hashValue })
        
        // Use GTO 4-bet pot strategy when facing 3-bet
        if facing3Bet {
            // Use GTO equity calculation for 4-bet decisions
            let equity = MonteCarloSimulator.calculateEquity(
                holeCards: holeCards,
                communityCards: [],
                playerCount: 2,
                iterations: 200
            )
            
            return gto4BetPotStrategy(
                holeCards: holeCards,
                communityCards: [],
                equity: equity,
                potSize: engine.pot.total,
                stackSize: engine.players.first?.chips ?? 1000,
                bb: engine.bigBlindAmount
            )
        }
        
        // Facing 2-bet: 3-bet or call based on GTO ranges
        if facingRaise {
            if chenScore >= 10 {
                // 3-bet for value
                return .raise(engine.currentBet * 3)
            }
            
            // Use GTO 3-bet range
            let isIP = seatOffset > 4  // Being in position
            let gto3BetRange = RangeAnalyzer.gto3BetRange(position: position, isIP: isIP)
            
            // Check if hand is in 3-bet range
            let in3BetRange = chenScore >= gto3BetRange.rangeWidth * 15
            if in3BetRange || chenScore >= 7 {
                return handHash % 100 < 35 ? .raise(engine.currentBet * 3) : .call
            }
            
            // Check GTO call 3-bet range
            let gtoCallRange = RangeAnalyzer.gtoCall3BetRange(position: position, isIP: isIP)
            let inCallRange = chenScore >= gtoCallRange.rangeWidth * 15
            if inCallRange {
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
        
        // 使用HandReadingSystem获取对手牌力解读
        var handReadingAdjust = 0.0
        if let lastBettor = findLastBettor(engine: engine), lastBettor.id != player.id {
            let opponentId = lastBettor.id.uuidString
            if let reading = HandReadingSystem.shared.getReading(for: opponentId, at: street) {
                // 根据对手牌力解读调整
                switch reading.handCategory {
                case .premium:
                    // 对手可能有强牌，更谨慎
                    handReadingAdjust = -0.15
                case .strong:
                    handReadingAdjust = -0.1
                case .medium:
                    handReadingAdjust = 0.0
                case .speculative:
                    handReadingAdjust = 0.1
                case .weak:
                    handReadingAdjust = 0.15
                }
                
#if DEBUG
                if reading.confidence > 0.5 {
                    #if DEBUG
                    logger.debug("\(player.name) 读取对手牌力: \(reading.handCategory.description), 信心度: \(String(format: "%.0f%%", reading.confidence * 100))", category: .game)
                    logger.debug("调整: \(String(format: "%.0f%%", handReadingAdjust * 100))", category: .game)
                    #endif
                }
#endif
            }
        }
        
        // 应用手牌解读调整到equity
        let adjustedEquity = max(0, min(1, equity + handReadingAdjust))
        
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
                    #if DEBUG
                    logger.debug("对手翻后范围：\(narrowedRange.description)", category: .game)
                    #endif
#endif
                }
            }
        }
        
        let hasStrongHand = category >= 3   // Trips or better
        let hasDecentHand = category >= 1   // At least a pair

        #if DEBUG
        logger.debug("\(player.name)[\(profile.name)] \(street.rawValue): eq=\(String(format:"%.2f",equity)) potOdds=\(String(format:"%.2f",potOdds)) hand=\(category) draws=\(draws.totalOuts)outs wet=\(String(format:"%.1f",board.wetness)) pfr=\(isPFR)", category: .game)
        #endif

        // GTO AI uses separate postflop path
        if profile.useGTOStrategy {
            // Get GTO strength factor
            let gtoStrength = profile.gtoStrength
            let isMultiway = activePlayers > 2

            // Apply SPR-based decision for deeper analysis
            let hasNutAdvantage = category >= 4  // Two pair or better
            let sprBasedAction = sprBasedDecision(
                spr: spr,
                equity: equity,
                potSize: potSize,
                stackSize: player.chips,
                hasNutAdvantage: hasNutAdvantage,
                isMultiway: isMultiway
            )

            // Multiway pot adjustment
            let adjustedEquity = multiwayAdjustment(
                playerCount: activePlayers,
                baseEquity: equity,
                potOdds: potOdds
            )

            let gtoAction = gtoPostflopDecision(
                player: player, holeCards: holeCards,
                community: community, engine: engine,
                street: street, callAmount: callAmount,
                potSize: potSize, equity: adjustedEquity,
                potOdds: potOdds, category: category,
                draws: draws, board: board,
                isPFR: isPFR, spr: spr
            )

            // Apply mixed strategy based on GTO strength
            if gtoStrength < 0.8 {
                let safeAction: PlayerAction = callAmount > 0 ? .call : .check
                return gtoMixedStrategy(
                    optimalAction: gtoAction,
                    safeAction: safeAction,
                    gtoStrength: gtoStrength,
                    equity: equity
                )
            }

            return gtoAction
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
                        #if DEBUG
                        logger.debug("诈唬检测：概率 \(String(format:"%.1f%%", indicator.bluffProbability * 100))", category: .game)
                        logger.debug("信号：\(indicator.signals.map { $0.rawValue }.joined(separator: ", "))", category: .game)
                        logger.debug("建议：\(indicator.recommendation)", category: .game)
                        #endif
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
        
        // Check for raise-war: limit continuous raising to prevent infinite loops
        // Use explicit type to avoid CoreData conflict
        let betHistory: [BetAction] = engine.bettingHistory[street] ?? []
        var raiseCount = 0
        for action in betHistory {
            if action.type == .raise {
                raiseCount += 1
            }
        }
        let isInRaiseWar = raiseCount >= 2  // If 2+ raises happened, stop continuing
        
        // Monster hand: raise/re-raise
        if category >= 5 {
            if spr < 3 || player.chips <= callAmount * 2 {
                return .allIn
            }
            // In raise-war, prefer all-in with monster rather than small raise
            if isInRaiseWar && player.chips > callAmount * 3 {
                return .allIn
            }
            let raiseAmount = engine.currentBet + max(engine.minRaise, potSize * 2 / 3)
            return .raise(raiseAmount)
        }
        
        // Strong hand: usually raise based on aggression
        if hasStrongHand {
            // In raise-war, prefer call to avoid infinite loop
            if isInRaiseWar {
                return .call
            }
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
        
        // Re-check raise-war status (need separate variable in this scope)
        var raiseCount2 = 0
        for action in betHistory {
            if action.type == .raise {
                raiseCount2 += 1
            }
        }
        let isInRaiseWarEV = raiseCount2 >= 2
        
        // Positive EV call (equity > total odds)
        if equity > totalOdds {
            // With high equity and aggression, consider raising
            // But don't continue raising in a raise-war
            if equity > 0.65 && profile.effectiveAggression > 0.6 && !isInRaiseWarEV {
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
                // Combo draws: raise with high aggression (but not in raise-war)
                if profile.effectiveAggression > 0.5 && !isInRaiseWarEV {
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
    /// Now integrated with GTOStrategy for stronger gameplay
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
        
        // Determine pot type for GTO strategy selection
        let is3BetPot = detect3BetPot(engine: engine)
        
        // Use GTO strategies based on street and situation
        switch street {
        case .river:
            // Use dedicated river GTO strategy
            return gtoRiverStrategy(
                holeCards: holeCards,
                communityCards: community,
                equity: equity,
                potSize: potSize,
                betToFace: callAmount,
                opponentRange: nil,
                bb: bb
            )
            
        case .flop, .turn:
            // Use pot-type specific GTO strategies
            if is3BetPot {
                return gto3BetPotStrategy(
                    holeCards: holeCards,
                    communityCards: community,
                    equity: equity,
                    potSize: potSize,
                    betToFace: callAmount,
                    street: street,
                    boardTexture: board,
                    bb: bb
                )
            } else {
                return gtoSingleRaisedPotStrategy(
                    holeCards: holeCards,
                    communityCards: community,
                    equity: equity,
                    potSize: potSize,
                    betToFace: callAmount,
                    isPFR: isPFR,
                    boardTexture: board,
                    street: street,
                    bb: bb
                )
            }
            
        default:
            break
        }
        
        // Fallback: original GTO logic for any remaining cases
        let handHash = abs(holeCards.reduce(0) { $0 &+ $1.hashValue })
        
        // No bet to face (check or bet)
        if callAmount == 0 {
            let isValueHand = category >= 2 || (category >= 1 && equity > 0.60)
            let isSemiBluff = draws.hasAnyDraw && equity > 0.35
            let isPureBluff = !isValueHand && !isSemiBluff && equity < 0.30
            
            if isPFR {
                let cbetFreq: Double
                if board.wetness < 0.3 {
                    cbetFreq = 0.70
                } else if board.wetness < 0.6 {
                    cbetFreq = 0.50
                } else {
                    cbetFreq = 0.30
                }
                
                if isValueHand || isSemiBluff {
                    if handHash % 100 < Int(cbetFreq * 100) {
                        let optimalSize = gtoOptimalBetSize(
                            handStrength: equity,
                            boardTexture: board,
                            isIP: true,
                            potSize: potSize,
                            bb: bb
                        )
                        let size = optimalSize.calculate(potSize: potSize, bb: bb)
                        return .raise(max(bb, size))
                    }
                }
                
                if isPureBluff {
                    let bluffProb: Double = board.wetness < 0.4 ? 0.15 : 0.10
                    if handHash % 100 < Int(bluffProb * 100) {
                        let optimalSize = gtoOptimalBetSize(
                            handStrength: equity,
                            boardTexture: board,
                            isIP: true,
                            potSize: potSize,
                            bb: bb
                        )
                        let size = optimalSize.calculate(potSize: potSize, bb: bb)
                        return .raise(max(bb, size))
                    }
                }
            }
            
            if category >= 4 && handHash % 100 < 30 {
                return .check
            }
            
            return .check
        }
        
        // Facing a bet: use MDF from GTOStrategy
        let mdf = calculateMDF(betSize: callAmount, potSize: potSize)
        
        // Raise range: strong value + bluffs
        if category >= 4 || (category >= 3 && equity > 0.75) {
            if spr < 3 || player.chips <= callAmount * 2 {
                return .allIn
            }
            let raiseAmount = engine.currentBet + max(engine.minRaise, potSize * 2 / 3)
            return .raise(raiseAmount)
        }
        
        // Bluff raise with combo draws
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
        
        // MDF defense
        if equity > potOdds * 0.8 && handHash % 100 < Int(mdf * 50) {
            return .call
        }
        
        return .fold
    }
    
    /// Detect if we're in a 3-bet pot
    private static func detect3BetPot(engine: PokerEngine) -> Bool {
        let preflopActions = engine.bettingHistory[.preFlop] ?? []
        var raiseCount = 0
        for action in preflopActions {
            if action.type == .raise {
                raiseCount += 1
            }
        }
        return raiseCount >= 2
    }
}
