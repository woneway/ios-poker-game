import Foundation

struct BlindLevel: Codable, Equatable, Identifiable {
    let id: Int  // same as level
    let level: Int
    let smallBlind: Int
    let bigBlind: Int
    let ante: Int
    
    init(level: Int, smallBlind: Int, bigBlind: Int, ante: Int = 0) {
        self.id = level
        self.level = level
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.ante = ante
    }
    
    var description: String {
        if ante > 0 {
            return "Level \(level): \(smallBlind)/\(bigBlind) (Ante \(ante))"
        } else {
            return "Level \(level): \(smallBlind)/\(bigBlind)"
        }
    }
}
