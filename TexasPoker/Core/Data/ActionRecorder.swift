import Foundation
import CoreData

class ActionRecorder {
    static let shared = ActionRecorder()
    
    /// Overridable context for testing. Falls back to shared persistence controller.
    var contextProvider: (() -> NSManagedObjectContext)?
    
    private var context: NSManagedObjectContext {
        contextProvider?() ?? PersistenceController.shared.container.viewContext
    }
    
    private var currentHandHistory: NSManagedObject?
    
    private init() {}
    
    /// Start recording a new hand
    func startHand(handNumber: Int, gameMode: GameMode, players: [Player]) {
        let hand = NSEntityDescription.insertNewObject(forEntityName: "HandHistoryEntity", into: context)
        hand.setValue(UUID(), forKey: "id")
        hand.setValue(Int32(handNumber), forKey: "handNumber")
        hand.setValue(Date(), forKey: "date")
        hand.setValue(gameMode.rawValue, forKey: "gameMode")
        hand.setValue(Int32(0), forKey: "finalPot")
        
        currentHandHistory = hand
    }
    
    /// Record a player action
    func recordAction(
        playerName: String,
        action: PlayerAction,
        amount: Int,
        street: Street,
        isVoluntary: Bool,
        position: String
    ) {
        guard let hand = currentHandHistory else { return }
        
        let actionEntity = NSEntityDescription.insertNewObject(forEntityName: "ActionEntity", into: context)
        actionEntity.setValue(UUID(), forKey: "id")
        actionEntity.setValue(hand, forKey: "handHistory")
        actionEntity.setValue(playerName, forKey: "playerName")
        actionEntity.setValue(action.description, forKey: "action")
        actionEntity.setValue(Int32(amount), forKey: "amount")
        actionEntity.setValue(street.rawValue, forKey: "street")
        actionEntity.setValue(Date(), forKey: "timestamp")
        actionEntity.setValue(isVoluntary, forKey: "isVoluntary")
        actionEntity.setValue(position, forKey: "position")
    }
    
    /// End the current hand and save all data
    func endHand(
        finalPot: Int,
        communityCards: [Card],
        heroCards: [Card],
        winners: [String]
    ) {
        guard let hand = currentHandHistory else { return }
        
        hand.setValue(Int32(finalPot), forKey: "finalPot")
        hand.setValue(encodeCards(communityCards), forKey: "communityCards")
        hand.setValue(encodeCards(heroCards), forKey: "heroCards")
        hand.setValue(winners.joined(separator: ","), forKey: "winnerNames")
        
        saveContext()
        currentHandHistory = nil
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
