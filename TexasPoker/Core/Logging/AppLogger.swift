import Foundation
import os.log

final class AppLogger {
    static let shared = AppLogger()

    private let subsystem = "smartegg.TexasPoker"

    private lazy var generalLog = OSLog(subsystem: subsystem, category: "General")
    private lazy var networkLog = OSLog(subsystem: subsystem, category: "Network")
    private lazy var analyticsLog = OSLog(subsystem: subsystem, category: "Analytics")
    private lazy var gameLog = OSLog(subsystem: subsystem, category: "Game")

    private init() {}

    func debug(_ message: String, category: LogCategory = .general) {
        os_log(.debug, log: log(for: category), "%{public}@", message)
    }

    func info(_ message: String, category: LogCategory = .general) {
        os_log(.info, log: log(for: category), "%{public}@", message)
    }

    func warning(_ message: String, category: LogCategory = .general) {
        os_log(.default, log: log(for: category), "⚠️ %{public}@", message)
    }

    func error(_ message: String, category: LogCategory = .general) {
        os_log(.error, log: log(for: category), "❌ %{public}@", message)
    }

    func error(_ error: Error, category: LogCategory = .general) {
        os_log(.error, log: log(for: category), "❌ %{public}@", error.localizedDescription)
    }

    private func log(for category: LogCategory) -> OSLog {
        switch category {
        case .general:
            return generalLog
        case .network:
            return networkLog
        case .analytics:
            return analyticsLog
        case .game:
            return gameLog
        }
    }

    enum LogCategory {
        case general
        case network
        case analytics
        case game
    }
}

final class Analytics {
    static let shared = Analytics()

    private let logger = AppLogger.shared

    private init() {}

    func trackEvent(_ name: String, parameters: [String: Any]? = nil) {
        logger.info("Event: \(name)", category: .analytics)
    }

    func trackScreenView(_ screenName: String) {
        logger.info("Screen: \(screenName)", category: .analytics)
    }

    func trackGameAction(_ action: String, player: String) {
        logger.info("Game Action: \(action) by \(player)", category: .game)
    }

    func trackError(_ error: Error, context: String? = nil) {
        let message = context != nil ? "\(context!): \(error.localizedDescription)" : error.localizedDescription
        logger.error(message, category: .analytics)
    }
}
