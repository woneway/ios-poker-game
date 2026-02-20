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

/// AI 决策推理即时提示
struct AIDecisionToast: View {
    let event: AIDecisionEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                Text(event.playerName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(event.action)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(actionColor)
            }
            
            Text(event.reasoning)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
            
            HStack(spacing: 8) {
                Label("\(String(format: "%.0f%%", event.equity * 100))", systemImage: "chart.bar")
                    .font(.system(size: 8))
                    .foregroundColor(.blue)
                Label("\(String(format: "%.0f%%", event.potOdds * 100))", systemImage: "percent")
                    .font(.system(size: 8))
                    .foregroundColor(.orange)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.75)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.5), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private var actionColor: Color {
        switch event.action.lowercased() {
        case "fold": return .gray
        case "check": return .green
        case "call": return .blue
        case "raise": return .orange
        case "allin": return .red
        default: return .white
        }
    }
}
