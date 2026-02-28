import Foundation
import SwiftUI

// MARK: - Tournament Stage

enum TournamentStage {
    case early
    case middle
    case late
    case finalTable

    static func from(handNumber: Int, totalPlayers: Int) -> TournamentStage {
        let playersRemaining = totalPlayers
        if playersRemaining <= 9 {
            return .finalTable
        } else if playersRemaining <= 27 {
            return .late
        } else if playersRemaining <= 54 {
            return .middle
        } else {
            return .early
        }
    }
}

// MARK: - Game Setup

struct GameSetup {
    let difficulty: AIProfile.Difficulty
    let playerCount: Int
    let startingChips: Int
    let gameMode: GameMode
}

// MARK: - Avatar Type

enum AvatarType: Equatable {
    case emoji(String)
    case image(String)

    var displayValue: String {
        switch self {
        case .emoji(let value): return value
        case .image(let name): return name
        }
    }
}

// MARK: - Difficulty

extension AIProfile {
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy
        case normal
        case hard
        case expert

        var id: String { rawValue }

        var description: String {
            switch self {
            case .easy: return "简单"
            case .normal: return "普通"
            case .hard: return "困难"
            case .expert: return "专家"
            }
        }

        var availableProfiles: [AIProfile] {
            let all = AIProfile.allProfiles
            switch self {
            case .easy:
                return all.filter { $0.difficultyRating <= 1 }
            case .normal:
                return all.filter { $0.difficultyRating <= 2 }
            case .hard:
                return all.filter { $0.difficultyRating <= 3 }
            case .expert:
                return all
            }
        }

        func randomOpponents(count: Int) -> [AIProfile] {
            Array(availableProfiles.shuffled().prefix(count))
        }
    }
}

// MARK: - AI Profile

struct AIProfile: Equatable {

    // MARK: - Tilt Adjustment Coefficients

    private static let tiltEffectOnTightness: Double = 0.4
    private static let tiltEffectOnAggression: Double = 0.3
    private static let tiltEffectOnBluffFreq: Double = 0.25
    private static let tiltEffectOnCallDown: Double = 0.2
    private static let minEffectiveTightness: Double = 0.05
    private static let maxEffectiveAggression: Double = 1.0
    private static let maxEffectiveBluffFreq: Double = 0.8
    private static let maxEffectiveCallDown: Double = 1.0

    // MARK: - Position Bonus Constants

    private static let positionBonuses: [Int: Double] = [
        0: 0.20, 1: -0.05, 2: 0.05, 3: -0.18,
        4: -0.14, 5: -0.08, 6: 0.06, 7: 0.14
    ]

    struct Constants {
        static let preflopThresholdBase: Double = 0.7
        static let minPreflopThreshold: Double = 0.05
        static let maxPreflopThreshold: Double = 0.9
    }

    // MARK: - Core Properties

    let id: String
    let name: String
    let avatar: AvatarType
    let description: String

    var tightness: Double
    var aggression: Double
    var bluffFreq: Double
    let foldTo3Bet: Double
    let cbetFreq: Double
    let cbetTurnFreq: Double
    let positionAwareness: Double
    let tiltSensitivity: Double
    var callDownTendency: Double
    let riskTolerance: Double
    let bluffDetection: Double
    let deepStackThreshold: Double
    var useGTOStrategy: Bool = false
    var currentTilt: Double = 0.0

    // MARK: - Effective Parameters

    var effectiveTightness: Double {
        max(Self.minEffectiveTightness, tightness - currentTilt * Self.tiltEffectOnTightness)
    }

    var effectiveAggression: Double {
        min(Self.maxEffectiveAggression, aggression + currentTilt * Self.tiltEffectOnAggression)
    }

    var effectiveBluffFreq: Double {
        min(Self.maxEffectiveBluffFreq, bluffFreq + currentTilt * Self.tiltEffectOnBluffFreq)
    }

    var effectiveCallDown: Double {
        min(Self.maxEffectiveCallDown, callDownTendency + currentTilt * Self.tiltEffectOnCallDown)
    }

    // MARK: - Position Adjustments

    func vpipAdjustment(seatOffset: Int, totalPlayers: Int) -> Double {
        guard positionAwareness > 0.1 else { return 0 }
        let posBonus = Self.positionBonuses[seatOffset] ?? 0.0
        return posBonus * positionAwareness
    }

    // MARK: - Preflop Threshold

    func preflopThreshold(seatOffset: Int, totalPlayers: Int) -> Double {
        let base = Self.Constants.preflopThresholdBase
        let adjustment = vpipAdjustment(seatOffset: seatOffset, totalPlayers: totalPlayers)
        let threshold = base - adjustment * tightness
        return min(max(threshold, Self.Constants.minPreflopThreshold), Self.Constants.maxPreflopThreshold)
    }

    // MARK: - Signature Actions

    enum SignatureAction: String {
        case none = ""
        case shrug = "耸肩"
        case quickRaise = "快速加注"
        case slowCall = "慢悠跟注"
        case hesitation = "犹豫不决"
        case confidentBet = "自信下注"
        case nervousFold = "紧张弃牌"
        case aggressivePush = "激进推全下"
    }

    func signatureAction(for actionType: String, isRaising: Bool, isCalling: Bool, isChecking: Bool) -> SignatureAction {
        let random = Double.random(in: 0...1)
        switch id {
        case "rock":
            return random > 0.7 ? .nervousFold : .none
        case "maniac":
            return isRaising && random > 0.5 ? .aggressivePush : .none
        case "calling_station":
            return isCalling && random > 0.6 ? .slowCall : .none
        case "bluff_jack":
            return isRaising && random > 0.6 ? .confidentBet : .none
        case "nit_steve":
            return random > 0.8 ? .hesitation : .none
        case "shark", "academic":
            return random > 0.7 ? .quickRaise : .none
        case "tilt_david":
            return random > 0.5 ? .hesitation : .none
        default:
            return .none
        }
    }

    func commentary(for actionType: String) -> String? {
        let random = Double.random(in: 0...1)
        switch id {
        case "rock":
            return random > 0.7 ? "这牌太强了..." : nil
        case "maniac":
            return random > 0.5 ? "来战！" : nil
        case "calling_station":
            return random > 0.6 ? "我跟..." : nil
        case "shark":
            return random > 0.6 ? "这把我吃定了" : nil
        case "nit_steve":
            return random > 0.8 ? "让我想想..." : nil
        case "tilt_david":
            return random > 0.5 ? "我就不信邪" : nil
        default:
            return nil
        }
    }

    // MARK: - Tournament Entry

    static func randomTournamentEntry(
        difficulty: AIProfile.Difficulty,
        stage: TournamentStage,
        averageStack: Int
    ) -> [AIProfile] {
        let profiles = difficulty.availableProfiles

        switch stage {
        case .early:
            return Array(profiles.filter { $0.tightness > 0.5 }.shuffled().prefix(2))
        case .middle:
            return Array(profiles.shuffled().prefix(3))
        case .late:
            return Array(profiles.filter { $0.aggression > 0.5 }.shuffled().prefix(2))
        case .finalTable:
            return Array(profiles.shuffled().prefix(1))
        }
    }
}
