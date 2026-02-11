import SwiftUI

/// 操作日志即时提示（面板收起时显示最新操作）
struct ActionLogToast: View {
    let entry: ActionLogEntry
    
    var body: some View {
        HStack(spacing: 4) {
            Text(entry.avatar)
                .font(.system(size: 11))
            Text(entry.playerName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
            Text(entry.actionText)
                .font(.system(size: 10))
                .foregroundColor(toastActionColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.7)))
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
    
    private var toastActionColor: Color {
        switch entry.action {
        case .fold: return .gray
        case .check: return .green
        case .call: return Color(hex: "4A90D9")
        case .raise: return .orange
        case .allIn: return .red
        }
    }
}
