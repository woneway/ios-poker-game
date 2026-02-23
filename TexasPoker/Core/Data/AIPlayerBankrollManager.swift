import Foundation

/// Manages persistent bankroll data for AI players across game sessions.
/// Each AI player's bankroll is stored per profile, allowing independent tracking.
final class AIPlayerBankrollManager {
    
    static let shared = AIPlayerBankrollManager()
    
    private let userDefaults = UserDefaults.standard
    
    /// Default initial bankroll for all players (human and AI)
    static let defaultInitialBankroll = 1_000_000
    
    /// UserDefaults key prefix for bankroll storage
    private let bankrollKeyPrefix = "ai_player_bankroll_"
    
    /// UserDefaults key prefix for entry index tracking
    private let entryIndexKeyPrefix = "ai_player_entry_index_"
    
    private init() {}
    
    // MARK: - Bankroll Operations
    
    /// Get the bankroll for a specific AI player in a profile
    /// - Parameters:
    ///   - profileId: The profile ID
    ///   - aiProfileId: The AI profile ID (e.g., "rock", "fox")
    /// - Returns: The current bankroll, or default if not set
    func getBankroll(profileId: String, aiProfileId: String) -> Int {
        let key = bankrollKey(for: profileId, aiProfileId: aiProfileId)
        let value = userDefaults.integer(forKey: key)
        return value > 0 ? value : Self.defaultInitialBankroll
    }
    
    /// Set the bankroll for a specific AI player
    /// - Parameters:
    ///   - profileId: The profile ID
    ///   - aiProfileId: The AI profile ID
    ///   - amount: The new bankroll amount
    func setBankroll(profileId: String, aiProfileId: String, amount: Int) {
        let key = bankrollKey(for: profileId, aiProfileId: aiProfileId)
        userDefaults.set(amount, forKey: key)
    }
    
    /// Update the bankroll by adding a delta (positive or negative)
    /// - Parameters:
    ///   - profileId: The profile ID
    ///   - aiProfileId: The AI profile ID
    ///   - delta: The amount to add (can be negative)
    /// - Returns: The new bankroll amount
    @discardableResult
    func updateBankroll(profileId: String, aiProfileId: String, delta: Int) -> Int {
        let current = getBankroll(profileId: profileId, aiProfileId: aiProfileId)
        let newAmount = max(0, current + delta)
        setBankroll(profileId: profileId, aiProfileId: aiProfileId, amount: newAmount)
        return newAmount
    }
    
    /// Deduct buy-in from player's bankroll
    /// - Parameters:
    ///   - profileId: The profile ID
    ///   - aiProfileId: The AI profile ID
    ///   - buyInAmount: The buy-in amount to deduct
    /// - Returns: The new bankroll after deduction, or nil if insufficient funds
    func deductBuyIn(profileId: String, aiProfileId: String, buyInAmount: Int) -> Int? {
        let current = getBankroll(profileId: profileId, aiProfileId: aiProfileId)
        guard current >= buyInAmount else { return nil }
        let newAmount = current - buyInAmount
        setBankroll(profileId: profileId, aiProfileId: aiProfileId, amount: newAmount)
        return newAmount
    }
    
    // MARK: - Entry Index Operations
    
    /// Get the next entry index for an AI player
    /// - Parameters:
    ///   - profileId: The profile ID
    ///   - aiProfileId: The AI profile ID
    /// - Returns: The next entry index (starting from 1)
    func getNextEntryIndex(profileId: String, aiProfileId: String) -> Int {
        let key = entryIndexKey(for: profileId, aiProfileId: aiProfileId)
        let currentIndex = userDefaults.integer(forKey: key)
        let nextIndex = currentIndex + 1
        userDefaults.set(nextIndex, forKey: key)
        return nextIndex
    }
    
    /// Get the current entry index without incrementing
    /// - Parameters:
    ///   - profileId: The profile ID
    ///   - aiProfileId: The AI profile ID
    /// - Returns: The current entry index (0 if never entered)
    func getCurrentEntryIndex(profileId: String, aiProfileId: String) -> Int {
        let key = entryIndexKey(for: profileId, aiProfileId: aiProfileId)
        return userDefaults.integer(forKey: key)
    }

    /// Reset all entry indexes (for testing purposes)
    func resetAllEntryIndexes() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix(entryIndexKeyPrefix) {
            userDefaults.removeObject(forKey: key)
        }
    }

    // MARK: - Profile Initialization
    
    /// Initialize bankrolls for all AI players in a profile
    /// Called when a new profile is created
    /// - Parameter profileId: The profile ID to initialize
    func initializeBankrollsForProfile(profileId: String) {
        for profile in AIProfile.allPresets {
            setBankroll(profileId: profileId, aiProfileId: profile.id, amount: Self.defaultInitialBankroll)
            // Reset entry index for new profile
            let entryKey = entryIndexKey(for: profileId, aiProfileId: profile.id)
            userDefaults.set(0, forKey: entryKey)
        }
    }
    
    /// Delete all bankroll data for a profile
    /// Called when a profile is deleted
    /// - Parameter profileId: The profile ID to delete
    func deleteBankrollsForProfile(profileId: String) {
        for profile in AIProfile.allPresets {
            let bankrollKey = self.bankrollKey(for: profileId, aiProfileId: profile.id)
            let entryKey = self.entryIndexKey(for: profileId, aiProfileId: profile.id)
            userDefaults.removeObject(forKey: bankrollKey)
            userDefaults.removeObject(forKey: entryKey)
        }
    }
    
    // MARK: - Validation
    
    /// Check if a player has sufficient bankroll for a game
    /// - Parameters:
    ///   - profileId: The profile ID
    ///   - aiProfileId: The AI profile ID (nil for human player)
    ///   - minBuyIn: The minimum buy-in required
    /// - Returns: True if player can afford the minimum buy-in
    func canAffordBuyIn(profileId: String, aiProfileId: String?, minBuyIn: Int) -> Bool {
        if let aiProfileId = aiProfileId {
            let bankroll = getBankroll(profileId: profileId, aiProfileId: aiProfileId)
            return bankroll >= minBuyIn
        }
        // For human players, we could check their balance separately if needed
        // For now, assume human can always join (or integrate with existing balance system)
        return true
    }
    
    // MARK: - Private Helpers
    
    private func bankrollKey(for profileId: String, aiProfileId: String) -> String {
        return "\(bankrollKeyPrefix)\(profileId)_\(aiProfileId)"
    }
    
    private func entryIndexKey(for profileId: String, aiProfileId: String) -> String {
        return "\(entryIndexKeyPrefix)\(profileId)_\(aiProfileId)"
    }
}

// MARK: - AIProfile Extension

extension AIProfile {
    /// All preset AI profiles for initialization
    static let allPresets: [AIProfile] = [
        .rock,
        .maniac,
        .callingStation,
        .fox,
        .shark,
        .academic,
        .tiltDavid
    ]
}
