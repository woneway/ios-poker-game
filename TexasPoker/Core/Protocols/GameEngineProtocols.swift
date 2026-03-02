import Foundation
import Combine

// MARK: - 动作记录协议
/// 用于记录游戏中的玩家动作和手牌历史
protocol ActionRecorderProtocol: AnyObject {
    /// 开始记录一手新牌
    func startHand(handNumber: Int, gameMode: GameMode, players: [Player])

    /// 记录玩家动作
    func recordAction(
        playerName: String,
        playerUniqueId: String?,
        action: PlayerAction,
        amount: Int,
        street: Street,
        isVoluntary: Bool,
        position: String,
        isHuman: Bool
    )

    /// 结束当前手牌并保存所有数据
    func endHand(
        finalPot: Int,
        communityCards: [Card],
        heroCards: [Card],
        winners: [String]
    )
}

// MARK: - 事件发布协议
/// 用于发布游戏事件供 UI 层监听
protocol EventPublisherProtocol: AnyObject {
    /// 发布玩家动作事件
    func publishPlayerAction(playerID: UUID, action: String, isThinking: Bool)

    /// 发布筹码动画事件
    func publishChipAnimation(seatIndex: Int, amount: Int)

    /// 发布赢家筹码动画事件
    func publishWinnerChipAnimation(seatIndex: Int, amount: Int)

    /// 发布玩家获胜事件
    func publishPlayerWon(playerID: UUID)

    /// 发布玩家统计更新事件
    func publishPlayerStatsUpdated()
}

// MARK: - 音效管理协议
/// 用于播放游戏音效
protocol SoundManagerProtocol: AnyObject {
    /// 播放音效
    func playSound(_ sound: SoundType)
}

// MARK: - 动画管理协议
/// 用于管理玩家动画
protocol AnimationManagerProtocol: AnyObject {
    /// 开始玩家动画
    func startAnimation(for playerId: String, type: PlayerAnimationType)

    /// 停止玩家动画
    func stopAnimation(for playerId: String)

    /// 设置玩家情绪
    func setEmotion(for playerId: String, emotion: PlayerEmotion)
}

// MARK: - 资金管理协议
/// 用于管理 AI 玩家的资金变化
protocol BankrollManagerProtocol: AnyObject {
    /// 记录玩家获胜
    func recordWin(_ playerId: String, amount: Int)

    /// 记录玩家失败
    func recordLoss(_ playerId: String, amount: Int)
}
