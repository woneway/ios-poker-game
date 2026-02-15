import Foundation

/// 管理 AI 玩家的 Tilt（情绪失控）系统
struct TiltManager {

    /// 重置所有玩家的 tilt 值
    /// - Parameter players: 所有玩家（inout，会重置 aiProfile.currentTilt）
    static func resetAllTilt(players: inout [Player]) {
        for i in 0..<players.count {
            guard var profile = players[i].aiProfile else { continue }
            profile.currentTilt = 0.0
            players[i].aiProfile = profile
        }

        #if DEBUG
        print("🔄 TiltManager: 所有玩家 tilt 值已重置")
        #endif
    }

    /// 根据上一手牌结果更新所有 AI 玩家的 tilt 值
    /// - Parameters:
    ///   - players: 所有玩家（inout，会修改 aiProfile.currentTilt）
    ///   - lastHandLosers: 上一手牌输家的 ID 集合
    ///   - lastPotSize: 上一手牌底池大小
    static func updateTiltLevels(
        players: inout [Player],
        lastHandLosers: Set<UUID>,
        lastPotSize: Int
    ) {
        for i in 0..<players.count {
            // 只处理AI玩家（有人类玩家没有aiProfile）
            guard var profile = players[i].aiProfile else { continue }

            if lastHandLosers.contains(players[i].id) {
                // Lost last hand - increase tilt based on sensitivity and pot size
                let tiltIncrease = profile.tiltSensitivity * Double(lastPotSize) / 800.0
                profile.currentTilt = min(1.0, profile.currentTilt + tiltIncrease)
            } else {
                // Didn't lose - tilt decays slowly (realistic: takes many hands to cool down)
                let decayRate = 0.03 * (1.0 - profile.tiltSensitivity * 0.5)
                profile.currentTilt = max(0.0, profile.currentTilt - decayRate)
            }

            players[i].aiProfile = profile
        }
    }
}
