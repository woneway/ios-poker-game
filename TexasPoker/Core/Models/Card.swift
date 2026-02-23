import Foundation

enum Suit: String, CaseIterable, Comparable, Codable {
    case clubs = "♣️"
    case diamonds = "♦️"
    case hearts = "♥️"
    case spades = "♠️"
    
    // Cactus Kev Suit Values (binary: 8, 4, 2, 1)
    var value: Int32 {
        switch self {
        case .clubs: return 0x8000
        case .diamonds: return 0x4000
        case .hearts: return 0x2000
        case .spades: return 0x1000
        }
    }
    
    static func < (lhs: Suit, rhs: Suit) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

enum Rank: Int, CaseIterable, Comparable, Codable {
    case two = 0, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace
    
    var display: String {
        switch self {
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "T"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        }
    }
    
    // Cactus Kev Primes
    var prime: Int32 {
        switch self {
        case .two: return 2
        case .three: return 3
        case .four: return 5
        case .five: return 7
        case .six: return 11
        case .seven: return 13
        case .eight: return 17
        case .nine: return 19
        case .ten: return 23
        case .jack: return 29
        case .queen: return 31
        case .king: return 37
        case .ace: return 41
        }
    }
    
    static func < (lhs: Rank, rhs: Rank) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

struct Card: Identifiable, Equatable, Hashable, CustomStringConvertible, Codable {
    // id is derived from rank+suit for correct identity in SwiftUI lists
    var id: String { "\(rank.rawValue)-\(suit.rawValue)" }
    let rank: Rank
    let suit: Suit
    
    // Cactus Kev's integer representation
    let value: Int32
    
    init(rank: Rank, suit: Suit) {
        self.rank = rank
        self.suit = suit
        
        let r = Int32(rank.rawValue)
        let p = rank.prime
        let s = suit.value
        let b = Int32(1) << (16 + r)
        self.value = b | s | (r << 8) | p
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case rank, suit
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rank = try container.decode(Rank.self, forKey: .rank)
        let suit = try container.decode(Suit.self, forKey: .suit)
        self.init(rank: rank, suit: suit)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rank, forKey: .rank)
        try container.encode(suit, forKey: .suit)
    }
    
    var description: String {
        return "\(rank.display)\(suit.rawValue)"
    }
    
    // Equatable: same rank + suit = same card
    static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.rank == rhs.rank && lhs.suit == rhs.suit
    }
    
    // Hashable: based on rank + suit
    func hash(into hasher: inout Hasher) {
        hasher.combine(rank)
        hasher.combine(suit)
    }
    
    static func < (lhs: Card, rhs: Card) -> Bool {
        return lhs.rank < rhs.rank
    }
}
