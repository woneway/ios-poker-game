import Foundation

struct TournamentConfig: Codable {
    let name: String
    let startingChips: Int
    let blindSchedule: [BlindLevel]
    let handsPerLevel: Int
    let payoutStructure: [Double]  // [0.5, 0.3, 0.2] = 50%, 30%, 20%
    
    // MARK: - Presets
    
    static let turbo = TournamentConfig(
        name: "Turbo",
        startingChips: 1000,
        blindSchedule: [
            BlindLevel(level: 1, smallBlind: 10, bigBlind: 20, ante: 0),
            BlindLevel(level: 2, smallBlind: 15, bigBlind: 30, ante: 0),
            BlindLevel(level: 3, smallBlind: 25, bigBlind: 50, ante: 5),
            BlindLevel(level: 4, smallBlind: 50, bigBlind: 100, ante: 10),
            BlindLevel(level: 5, smallBlind: 75, bigBlind: 150, ante: 15),
            BlindLevel(level: 6, smallBlind: 100, bigBlind: 200, ante: 25),
            BlindLevel(level: 7, smallBlind: 150, bigBlind: 300, ante: 50),
            BlindLevel(level: 8, smallBlind: 200, bigBlind: 400, ante: 75),
            BlindLevel(level: 9, smallBlind: 300, bigBlind: 600, ante: 100),
            BlindLevel(level: 10, smallBlind: 500, bigBlind: 1000, ante: 150)
        ],
        handsPerLevel: 5,
        payoutStructure: [0.5, 0.3, 0.2]
    )
    
    static let standard = TournamentConfig(
        name: "Standard",
        startingChips: 1000,
        blindSchedule: [
            BlindLevel(level: 1, smallBlind: 10, bigBlind: 20, ante: 0),
            BlindLevel(level: 2, smallBlind: 15, bigBlind: 30, ante: 0),
            BlindLevel(level: 3, smallBlind: 20, bigBlind: 40, ante: 0),
            BlindLevel(level: 4, smallBlind: 25, bigBlind: 50, ante: 5),
            BlindLevel(level: 5, smallBlind: 50, bigBlind: 100, ante: 10),
            BlindLevel(level: 6, smallBlind: 75, bigBlind: 150, ante: 15),
            BlindLevel(level: 7, smallBlind: 100, bigBlind: 200, ante: 25),
            BlindLevel(level: 8, smallBlind: 150, bigBlind: 300, ante: 50),
            BlindLevel(level: 9, smallBlind: 200, bigBlind: 400, ante: 75),
            BlindLevel(level: 10, smallBlind: 300, bigBlind: 600, ante: 100)
        ],
        handsPerLevel: 10,
        payoutStructure: [0.5, 0.3, 0.2]
    )
    
    static let deepStack = TournamentConfig(
        name: "Deep Stack",
        startingChips: 2000,
        blindSchedule: [
            BlindLevel(level: 1, smallBlind: 10, bigBlind: 20, ante: 0),
            BlindLevel(level: 2, smallBlind: 15, bigBlind: 30, ante: 0),
            BlindLevel(level: 3, smallBlind: 20, bigBlind: 40, ante: 0),
            BlindLevel(level: 4, smallBlind: 25, bigBlind: 50, ante: 0),
            BlindLevel(level: 5, smallBlind: 30, bigBlind: 60, ante: 5),
            BlindLevel(level: 6, smallBlind: 50, bigBlind: 100, ante: 10),
            BlindLevel(level: 7, smallBlind: 75, bigBlind: 150, ante: 15),
            BlindLevel(level: 8, smallBlind: 100, bigBlind: 200, ante: 25),
            BlindLevel(level: 9, smallBlind: 150, bigBlind: 300, ante: 50),
            BlindLevel(level: 10, smallBlind: 200, bigBlind: 400, ante: 75)
        ],
        handsPerLevel: 15,
        payoutStructure: [0.5, 0.3, 0.2]
    )
}
