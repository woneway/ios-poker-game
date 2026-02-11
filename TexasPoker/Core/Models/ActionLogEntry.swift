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
    
    /// 动作描述（中文）
    var actionText: String {
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
