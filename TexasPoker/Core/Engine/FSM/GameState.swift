import Foundation

enum GameState: Equatable {
    case idle               // 等待开始新一手
    case dealing            // 发牌动画播放中
    case waitingForAction   // 等待人类玩家操作（显示操作按钮）
    case betting            // AI 正在思考/行动中
    case showdown           // 一手结束，显示结果
    
    var description: String {
        switch self {
        case .idle: return "Idle"
        case .dealing: return "Dealing"
        case .waitingForAction: return "WaitingForAction"
        case .betting: return "Betting"
        case .showdown: return "Showdown"
        }
    }
}
