import Foundation

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case cashGame = "Cash Game"
    case tournament = "Tournament"
    
    var id: String { self.rawValue }
}
