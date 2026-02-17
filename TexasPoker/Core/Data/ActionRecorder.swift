import Foundation
import CoreData

class ActionRecorder {
    static let shared = ActionRecorder()

    /// Overridable context for testing. Falls back to shared persistence controller.
    var contextProvider: (() -> NSManagedObjectContext)?

    /// Overridable profile id for testing.
    var profileIdProvider: (() -> String)?

    /// Overridable isHuman check for testing.
    var isHumanProvider: ((String) -> Bool)?

    /// 线程安全：使用队列保护状态
    private let queue = DispatchQueue(label: "com.poker.actionrecorder")

    private var context: NSManagedObjectContext {
        contextProvider?() ?? PersistenceController.shared.container.viewContext
    }

    /// 线程安全：使用队列保护 currentHandHistory
    private var _currentHandHistory: NSManagedObject?
    private var currentHandHistory: NSManagedObject? {
        get { queue.sync { _currentHandHistory } }
        set { queue.sync { _currentHandHistory = newValue } }
    }

    private init() {}

    /// Start recording a new hand (线程安全)
    func startHand(handNumber: Int, gameMode: GameMode, players: [Player]) {
        queue.sync {
            let hand = NSEntityDescription.insertNewObject(forEntityName: "HandHistoryEntity", into: context)
            hand.setValue(UUID(), forKey: "id")
            hand.setValue(Int32(handNumber), forKey: "handNumber")
            hand.setValue(Date(), forKey: "date")
            hand.setValue(gameMode.rawValue, forKey: "gameMode")
            hand.setValue(profileIdProvider?() ?? ProfileManager.shared.currentProfileIdForData, forKey: "profileId")
            hand.setValue(Int32(0), forKey: "finalPot")

            _currentHandHistory = hand
        }
    }

    /// Record a player action (线程安全)
    /// - Parameters:
    ///   - playerName: The name of the player
    ///   - action: The action taken
    ///   - amount: The amount bet/called/raised
    ///   - street: The betting street
    ///   - isVoluntary: Whether the action was voluntary (not blind)
    ///   - position: Position name (BTN, SB, BB, etc.)
    ///   - isHuman: Whether this player is a human (for stats isolation)
    func recordAction(
        playerName: String,
        playerUniqueId: String?,  // 新增参数
        action: PlayerAction,
        amount: Int,
        street: Street,
        isVoluntary: Bool,
        position: String,
        isHuman: Bool
    ) {
        queue.sync {
            guard let hand = _currentHandHistory else { return }

            let actionEntity = NSEntityDescription.insertNewObject(forEntityName: "ActionEntity", into: context)
            let profileId = (profileIdProvider?() ?? ProfileManager.shared.currentProfileIdForData)
            actionEntity.setValue(UUID(), forKey: "id")
            actionEntity.setValue(hand, forKey: "handHistory")
            actionEntity.setValue(playerName, forKey: "playerName")
            actionEntity.setValue(playerUniqueId, forKey: "playerUniqueId")  // 新增
            actionEntity.setValue(action.description, forKey: "action")
            actionEntity.setValue(Int32(amount), forKey: "amount")
            actionEntity.setValue(street.rawValue, forKey: "street")
            actionEntity.setValue(Date(), forKey: "timestamp")
            actionEntity.setValue(isVoluntary, forKey: "isVoluntary")
            actionEntity.setValue(position, forKey: "position")
            actionEntity.setValue(profileId, forKey: "profileId")
            actionEntity.setValue(isHuman, forKey: "isHuman")
        }
    }

    /// End the current hand and save all data (线程安全)
    func endHand(
        finalPot: Int,
        communityCards: [Card],
        heroCards: [Card],
        winners: [String]
    ) {
        queue.sync {
            guard let hand = _currentHandHistory else { return }

            hand.setValue(Int32(finalPot), forKey: "finalPot")
            hand.setValue(encodeCards(communityCards), forKey: "communityCards")
            hand.setValue(encodeCards(heroCards), forKey: "heroCards")
            hand.setValue(winners.joined(separator: ","), forKey: "winnerNames")

            saveContext()
            _currentHandHistory = nil
        }
    }

    private func saveContext() {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Failed to save hand history: \(error)")
            #endif
        }
    }

    private func encodeCards(_ cards: [Card]) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(cards),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}
