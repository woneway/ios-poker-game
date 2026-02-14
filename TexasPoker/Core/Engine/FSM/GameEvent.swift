import Foundation

enum GameEvent {
    case start              // 开始新一手
    case dealComplete       // 发牌动画完成
    case playerActed        // 人类玩家完成操作
    case handOver           // 一手结束（摊牌或全员弃牌）
    case nextHand           // 开始下一手
    case startSpectating    // 进入观战模式
    case pauseSpectating    // 暂停观战
    case resumeSpectating   // 恢复观战
    case stopSpectating     // 退出观战
}
