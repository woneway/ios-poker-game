import XCTest
@testable import TexasPoker

final class AIFullTournamentTest: XCTestCase {

    func test52PlayerTournament() {
        let profiles = AIProfile.allProfiles

        var rankSums: [String: (name: String, sum: Int, games: Int)] = [:]
        for p in profiles {
            rankSums[p.id] = (p.name, 0, 0)
        }

        for _ in 0..<5 {
            var chips: [(id: String, chips: Int)] = profiles.map { ($0.id, 1000) }

            for _ in 0..<40 {
                let active = chips.filter { $0.chips > 0 }
                if active.count < 2 { break }

                let tableSize = min(6, active.count)
                let table = Array(active.shuffled().prefix(tableSize))

                var pot = 0
                for i in 0..<table.count {
                    let bet = min(20, table[i].chips / 10)
                    if let idx = chips.firstIndex(where: { $0.id == table[i].id }) {
                        chips[idx].chips -= bet
                        pot += bet
                    }
                }

                let scores = table.map { t -> (idx: Int, score: Double) in
                    let p = profiles.first { $0.id == t.id }!
                    let score = p.aggression * 0.4 + p.positionAwareness * 0.3 + Double.random(in: 0...0.3)
                    return (table.firstIndex(where: { $0.id == t.id })!, score)
                }

                let winner = scores.max(by: { $0.score < $1.score })!
                if let wIdx = chips.firstIndex(where: { $0.id == table[winner.idx].id }) {
                    chips[wIdx].chips += pot
                }
            }

            let ranked = chips.sorted { $0.chips > $1.chips }
            for (pos, p) in ranked.enumerated() {
                if var entry = rankSums[p.id] {
                    entry.sum += pos + 1
                    entry.games += 1
                    rankSums[p.id] = entry
                }
            }
        }

        let sorted = rankSums.values.sorted { a, b in
            let avgA = Double(a.sum) / Double(max(1, a.games))
            let avgB = Double(b.sum) / Double(max(1, b.games))
            return avgA < avgB
        }

        var out = "\n=== 52人锦标赛排名 (5场) ===\n\n前26名:\n"
        for (i, r) in sorted.prefix(26).enumerated() {
            let avg = Double(r.sum) / Double(max(1, r.games))
            out += "\(i+1). \(r.name) avg:\(String(format:"%.1f", avg))\n"
        }
        out += "\n后26名:\n"
        for (i, r) in sorted.suffix(26).enumerated() {
            let avg = Double(r.sum) / Double(max(1, r.games))
            out += "\(27+i). \(r.name) avg:\(String(format:"%.1f", avg))\n"
        }

        print(out)
    }
}
