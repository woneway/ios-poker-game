import Foundation
import os.log

struct GameConstants {
    
    // MARK: - Animation Delays (seconds)
    
    struct Delays {
        static let dealAnimation: TimeInterval = 0.5
        static let streetTransition: TimeInterval = 0.6
        static let playerAction: TimeInterval = 1.5
        static let showdown: TimeInterval = 2.0
        static let sessionSummary: TimeInterval = 0.5
        static let tiltWarning: TimeInterval = 3.0
        static let spectateSpeed: TimeInterval = 1.5
    }
    
    // MARK: - AI Decision Thresholds

    struct AI {
        static let confidenceThreshold: Double = 0.5
        static let aggressionLow: Double = 0.5
        static let aggressionHigh: Double = 0.6
        static let aggressionAdjusted: Double = 0.55
        static let openRaiseBB: Double = 3.0
        static let defaultCallProbability: Double = 0.5
        static let defaultRange: Double = 0.5

        // Decision Engine Constants
        static let defaultOpponentCallProb: Double = 0.5
        static let defaultOpponentRange: Double = 0.5
        static let sprHighThreshold: Double = 10.0
        static let sprMediumThreshold: Double = 5.0
        static let sprTurnHighThreshold: Double = 8.0
        static let sprTurnMediumThreshold: Double = 4.0
        static let impliedOddsFlopHigh: Double = 0.15
        static let impliedOddsFlopMedium: Double = 0.08
        static let impliedOddsTurnHigh: Double = 0.10
        static let impliedOddsTurnMedium: Double = 0.05
        static let raiseTendencyFactor: Double = 0.1
        static let callTendencyFactor: Double = 0.05
        static let aggressionMidpoint: Double = 0.5
        static let maxModelCount: Int = 100  // 增加最大模型数量限制
        static let cleanupInterval: TimeInterval = 60  // 减少清理间隔到 1 分钟
    }
    
    // MARK: - Cache Limits
    
    struct Cache {
        static let maxEquityCacheSize = 1000
        static let maxOpponentModels = 50
        static let statisticsCacheAge: TimeInterval = 60
    }
    
    // MARK: - Game Settings

    struct Game {
        static let defaultStartingChips = 1000
        static let minPlayers = 2
        static let maxPlayers = 8
    }

    // MARK: - Monte Carlo

    struct MonteCarlo {
        static let defaultIterations = 1000
        static let maxIterations = 5000
        static let drawingHandBonus = 500
        static let preFlopBonus = 500
    }

    // MARK: - Background Simulation

    struct Simulation {
        static let backgroundHandsPerBatch = 15
        static let backgroundBatches = 2
        static let maxSimulationIterations = 200
    }
}

// MARK: - Logging

enum GameLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.poker.texas"
    
    static let engine = Logger(subsystem: subsystem, category: "Engine")
    static let ai = Logger(subsystem: subsystem, category: "AI")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let data = Logger(subsystem: subsystem, category: "Data")
    
    #if DEBUG
    static func debug(_ message: String, category: Logger = engine) {
        category.debug("\(message)")
    }
    #else
    static func debug(_ message: String, category: Logger = engine) {
        // No-op in production
    }
    #endif
}
