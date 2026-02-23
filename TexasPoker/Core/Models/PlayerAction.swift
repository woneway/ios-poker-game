import Foundation

enum PlayerAction: Equatable {
    case fold
    case check
    case call
    case raise(Int) // Raise TO amount (total bet)
    case allIn
    
    var description: String {
        switch self {
        case .fold: return "Fold"
        case .check: return "Check"
        case .call: return "Call"
        case .raise(let amount): return "Raise to \(amount)"
        case .allIn: return "All In"
        }
    }
}
