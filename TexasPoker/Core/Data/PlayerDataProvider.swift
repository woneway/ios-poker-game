import Foundation

struct PlayerDataProvider {
    static var allAINames: [String] {
        AIProfile.Difficulty.expert.availableProfiles.map { $0.name }
    }

    static func aiEmoji(for name: String) -> String {
        AIProfile.Difficulty.expert.availableProfiles.first { $0.name == name }?.avatar.displayValue ?? "🤖"
    }

    static func aiProfile(for name: String) -> AIProfile? {
        AIProfile.Difficulty.expert.availableProfiles.first { $0.name == name }
    }

    static var allAIProfiles: [AIProfile] {
        AIProfile.Difficulty.expert.availableProfiles
    }
}
