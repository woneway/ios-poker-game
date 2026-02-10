import Foundation

enum GameState: Equatable {
    case idle           // Waiting to start a new hand
    case dealing        // Deal animation playing
    case betting        // Players are betting (human or AI turn)
    case showdown       // Hand ended, showing results
    
    var description: String {
        switch self {
        case .idle: return "Idle"
        case .dealing: return "Dealing"
        case .betting: return "Betting"
        case .showdown: return "Showdown"
        }
    }
}
