import Foundation

enum GameEvent {
    case start          // Start a new hand
    case dealComplete   // Deal animation finished
    case handOver       // Hand has concluded (showdown or everyone folded)
    case nextHand       // Player wants to start the next hand
}
