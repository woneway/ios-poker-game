import Foundation

/// 结算结果
struct HandResult {
    let winnerIDs: [UUID]
    let winMessage: String
    let loserIDs: Set<UUID>
    let totalPot: Int
}

/// 结算管理器 — 处理 showdown 和奖池分配
enum ShowdownManager {

    /// 唯一存活者（所有人弃牌）赢得全部奖池
    static func distributeSingleWinner(
        winner: Player,
        potTotal: Int,
        players: inout [Player]
    ) -> HandResult {
        if let index = players.firstIndex(where: { $0.id == winner.id }) {
            players[index].chips += potTotal
        }

        let losers = findLosers(players: players, winnerIDs: [winner.id])
        return HandResult(
            winnerIDs: [winner.id],
            winMessage: "\(winner.name) 赢得 $\(potTotal)!",
            loserIDs: losers,
            totalPot: potTotal
        )
    }

    /// Showdown: 逐池结算（支持主池 + 多个边池）
    static func distributeWithSidePots(
        eligible: [Player],
        pot: Pot,
        communityCards: [Card],
        players: inout [Player]
    ) -> HandResult {
        var message = ""
        var allWinnerIDs: [UUID] = []
        var allWinnerIDSet = Set<UUID>()

        for (potIdx, portion) in pot.portions.enumerated() {
            let potEligible = eligible.filter { portion.eligiblePlayerIDs.contains($0.id) }
            guard !potEligible.isEmpty else { continue }

            // Single eligible player gets the pot
            if potEligible.count == 1 {
                let winner = potEligible[0]
                if let index = players.firstIndex(where: { $0.id == winner.id }) {
                    players[index].chips += portion.amount
                    allWinnerIDSet.insert(winner.id)
                    if !allWinnerIDs.contains(winner.id) { allWinnerIDs.append(winner.id) }
                    let potLabel = potIdx == 0 ? "主池" : "边池\(potIdx)"
                    message += "\(winner.name) 赢得\(potLabel) $\(portion.amount)! "
                }
                continue
            }

            // Evaluate hands
            var playerScores: [(Player, Int, [Int])] = []
            for player in potEligible {
                let score = HandEvaluator.evaluate(holeCards: player.holeCards, communityCards: communityCards)
                playerScores.append((player, score.0, score.1))
            }

            playerScores.sort { (lhs, rhs) in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return PokerUtils.compareKickers(lhs.2, rhs.2) > 0
            }

            guard let best = playerScores.first else { continue }
            let potWinners = playerScores.filter {
                $0.1 == best.1 && PokerUtils.compareKickers($0.2, best.2) == 0
            }.map { $0.0 }

            let winAmount = portion.amount / potWinners.count
            let remainder = portion.amount % potWinners.count
            let potLabel = potIdx == 0 ? "主池" : "边池\(potIdx)"

            for (i, winner) in potWinners.enumerated() {
                if let index = players.firstIndex(where: { $0.id == winner.id }) {
                    let bonus = (i == 0) ? remainder : 0
                    players[index].chips += winAmount + bonus
                    allWinnerIDSet.insert(winner.id)
                    if !allWinnerIDs.contains(winner.id) { allWinnerIDs.append(winner.id) }
                    message += "\(winner.name) 赢得\(potLabel) $\(winAmount + bonus)! "
                }
            }
        }

        let losers = findLosers(players: players, winnerIDs: allWinnerIDSet)
        return HandResult(
            winnerIDs: allWinnerIDs,
            winMessage: message.trimmingCharacters(in: .whitespaces),
            loserIDs: losers,
            totalPot: pot.total
        )
    }

    /// 追踪输家（用于 tilt 系统）
    static func findLosers(players: [Player], winnerIDs: Set<UUID>) -> Set<UUID> {
        Set(players.filter {
            ($0.status == .active || $0.status == .allIn || $0.status == .folded) &&
            !winnerIDs.contains($0.id) && $0.totalBetThisHand > 0
        }.map { $0.id })
    }
}
