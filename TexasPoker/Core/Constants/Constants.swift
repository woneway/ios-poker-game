import Foundation

enum Constants {
    enum Game {
        static let defaultSmallBlind = 10
        static let defaultBigBlind = 20
        static let defaultMinBuyIn = 400
        static let defaultMaxBuyIn = 2000
        static let maxPlayers = 9
        static let minPlayers = 2
    }

    enum Tournament {
        static let defaultStartingChips = 1000
        static let defaultBlindLevelTime = 600
        static let defaultRevealTime = 10
    }

    enum Animation {
        static let cardDealDuration: Double = 0.5
        static let chipAnimationDuration: Double = 0.3
        static let playerActionDelay: Double = 1.0
    }

    enum Cache {
        static let statsCacheExpiry: TimeInterval = 60
        static let maxCachedStats = 100
    }

    enum UI {
        static let cornerRadius: CGFloat = 12
        static let buttonHeight: CGFloat = 50
        static let cardAspectRatio: CGFloat = 1.4
    }

    // MARK: - Statistics Thresholds

    enum Statistics {
        /// 判断玩家风格所需的最小手牌数
        static let minHandsForStyleAnalysis = 20

        /// 统计置信度达到满分的最小手牌数
        static let minHandsForFullConfidence = 100

        /// 统计置信度的最小样本数阈值
        static let minSampleSizeForConfidence = 100
    }
}
