import Foundation

final class Configuration {
    static let shared = Configuration()

    private init() {}

    struct Keys {
        static let baseURL = "BASE_URL"
        static let apiKey = "API_KEY"
        static let enableAnalytics = "ENABLE_ANALYTICS"
        static let enableDebugMode = "DEBUG_MODE"
    }

    var baseURL: String {
        ProcessInfo.processInfo.environment[Keys.baseURL] ?? "https://api.example.com"
    }

    var apiKey: String {
        ProcessInfo.processInfo.environment[Keys.apiKey] ?? ""
    }

    var enableAnalytics: Bool {
        ProcessInfo.processInfo.environment[Keys.enableAnalytics] == "true"
    }

    var enableDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return ProcessInfo.processInfo.environment[Keys.enableDebugMode] == "true"
        #endif
    }
}

enum AppConfig {
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var maxPlayers: Int { 9 }
    static var minPlayers: Int { 2 }
    static var defaultStartingChips: Int { 1000 }
    static var tournamentBlindLevelTime: Int { 600 }

    static var supportedGameModes: [GameMode] {
        [.cashGame, .tournament]
    }
}
