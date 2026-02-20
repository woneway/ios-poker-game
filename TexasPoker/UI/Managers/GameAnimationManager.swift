import Foundation
import Combine

@Observable
final class GameAnimationManager {
    static let shared = GameAnimationManager()
    
    var chipAnimationCallback: ((Int, Int) -> Void)?
    var winnerChipAnimationCallback: ((Int, Int) -> Void)?
    
    private init() {}
    
    func triggerChipAnimation(seatIndex: Int, amount: Int) {
        chipAnimationCallback?(seatIndex, amount)
    }
    
    func triggerWinnerChipAnimation(seatIndex: Int, amount: Int) {
        winnerChipAnimationCallback?(seatIndex, amount)
    }
}
