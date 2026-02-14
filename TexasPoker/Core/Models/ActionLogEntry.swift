import Foundation

/// 操作日志条目
struct ActionLogEntry: Identifiable {
    let id = UUID()
    let playerName: String
    let avatar: String
    let action: PlayerAction
    let amount: Int?      // 涉及金额（call/raise/allIn）
    let street: Street
    let timestamp: Date = Date()
    var systemMessage: String?  // 系统消息（可选）
    
    /// 便利初始化器 - 用于创建系统消息类型的日志
    init(systemMessage: String) {
        self.playerName = ""
        self.avatar = ""
        self.action = .fold  // 占位
        self.amount = nil
        self.street = .preFlop
        self.systemMessage = systemMessage
    }

    /// 标准初始化器 - 用于创建玩家动作日志
    init(playerName: String, avatar: String, action: PlayerAction, amount: Int?, street: Street) {
        self.playerName = playerName
        self.avatar = avatar
        self.action = action
        self.amount = amount
        self.street = street
        self.systemMessage = nil
    }
    
    /// 动作描述（中文）
    var actionText: String {
        if let msg = systemMessage { return msg }
        
        switch action {
        case .fold: return "弃牌"
        case .check: return "过牌"
        case .call: return amount.map { "跟注 $\($0)" } ?? "跟注"
        case .raise(let to): return "加注到 $\(to)"
        case .allIn: return "全下 $\(amount ?? 0)"
        }
    }
    
    /// 动作图标（SF Symbol）
    var iconName: String {
        switch action {
        case .fold: return "hand.raised.slash.fill"
        case .check: return "checkmark.circle.fill"
        case .call: return "arrow.right.circle.fill"
        case .raise: return "arrow.up.circle.fill"
        case .allIn: return "flame.fill"
        }
    }
    
    /// 动作颜色
    var color: String {
        switch action {
        case .fold: return "gray"
        case .check: return "green"
        case .call: return "blue"
        case .raise: return "orange"
        case .allIn: return "red"
        }
    }
}
