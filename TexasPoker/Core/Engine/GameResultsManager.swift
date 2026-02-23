import Foundation

/// 管理游戏最终排名和淘汰追踪
struct GameResultsManager {

    /// 追踪新淘汰的玩家，追加到淘汰顺序中
    /// 使用 Set 优化查找效率 O(1)
    static func trackEliminations(
        players: [Player],
        handNumber: Int,
        eliminationOrder: inout [(name: String, avatar: String, hand: Int, isHuman: Bool)]
    ) {
        // 构建已淘汰玩家名称 Set，O(n)
        let existingNames = Set(eliminationOrder.map { $0.name })

        for player in players {
            // O(1) 查找
            if player.chips <= 0 && !existingNames.contains(player.name) {
                let avatar = player.aiProfile?.avatar ?? (player.isHuman ? "🎯" : "🤖")
                eliminationOrder.append((
                    name: player.name,
                    avatar: avatar,
                    hand: handNumber,
                    isHuman: player.isHuman
                ))
            }
        }
    }

    /// 生成最终排名结果（1st place first）
    static func generateFinalResults(
        players: [Player],
        handNumber: Int,
        eliminationOrder: [(name: String, avatar: String, hand: Int, isHuman: Bool)]
    ) -> [PlayerResult] {
        var results: [PlayerResult] = []

        // Winner(s) - players still with chips
        let alive = players.filter { $0.chips > 0 }
        for (i, p) in alive.enumerated() {
            let avatar = p.aiProfile?.avatar ?? (p.isHuman ? "🎯" : "🤖")
            results.append(PlayerResult(
                name: p.name,
                avatar: avatar,
                rank: i + 1,
                finalChips: p.chips,
                handsPlayed: handNumber,
                isHuman: p.isHuman
            ))
        }

        // Eliminated players - reverse elimination order (last eliminated = 2nd place)
        let eliminated = eliminationOrder.reversed()
        for (i, entry) in eliminated.enumerated() {
            let rank = alive.count + i + 1
            results.append(PlayerResult(
                name: entry.name,
                avatar: entry.avatar,
                rank: rank,
                finalChips: 0,
                handsPlayed: entry.hand,
                isHuman: entry.isHuman
            ))
        }

        return results.sorted { $0.rank < $1.rank }
    }
}
