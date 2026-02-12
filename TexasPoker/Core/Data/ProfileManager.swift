import Foundation
import Combine

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    let createdAt: Date
}

/// Manages multi-profile (multi-account) state for the app.
///
/// The goal is to isolate statistics/history per profile.
final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    static let defaultProfileId = "default"

    private let profilesKey = "poker_profiles_v1"
    private let currentProfileKey = "poker_current_profile_id_v1"

    @Published private(set) var profiles: [UserProfile] = []

    @Published var currentProfileId: String {
        didSet {
            if currentProfileId.isEmpty { currentProfileId = Self.defaultProfileId }
            UserDefaults.standard.set(currentProfileId, forKey: currentProfileKey)
            GameHistoryManager.shared.setActiveProfile(id: currentProfileId)
        }
    }

    /// Override for tests.
    var currentProfileIdOverride: String?

    var currentProfile: UserProfile {
        profiles.first(where: { $0.id == currentProfileId }) ?? UserProfile(id: Self.defaultProfileId, name: "Default", createdAt: Date())
    }

    /// A stable id string to write into persistence (CoreData/UserDefaults keys).
    var currentProfileIdForData: String {
        currentProfileIdOverride ?? currentProfileId
    }

    private init() {
        // Load profiles list
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([UserProfile].self, from: data) {
            profiles = decoded
        } else {
            profiles = []
        }

        // Ensure default profile exists
        if !profiles.contains(where: { $0.id == Self.defaultProfileId }) {
            profiles.insert(UserProfile(id: Self.defaultProfileId, name: "Default", createdAt: Date()), at: 0)
            persistProfiles()
        }

        // Load current profile
        let saved = UserDefaults.standard.string(forKey: currentProfileKey) ?? Self.defaultProfileId
        self.currentProfileId = profiles.contains(where: { $0.id == saved }) ? saved : Self.defaultProfileId

        // Ensure GameHistory is aligned on launch
        GameHistoryManager.shared.setActiveProfile(id: currentProfileId)
    }

    func createProfile(name: String) -> UserProfile {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Profile \(profiles.count)" : trimmed
        let profile = UserProfile(id: UUID().uuidString, name: finalName, createdAt: Date())
        profiles.append(profile)
        persistProfiles()
        currentProfileId = profile.id
        return profile
    }

    func renameProfile(id: String, name: String) {
        guard id != Self.defaultProfileId else { return } // keep default stable
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[idx].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        persistProfiles()
    }

    func deleteProfile(id: String) {
        guard id != Self.defaultProfileId else { return } // cannot delete default
        profiles.removeAll { $0.id == id }
        persistProfiles()
        if currentProfileId == id {
            currentProfileId = Self.defaultProfileId
        }
    }

    private func persistProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: profilesKey)
    }
}

