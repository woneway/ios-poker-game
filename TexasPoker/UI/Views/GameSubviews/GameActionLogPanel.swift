import SwiftUI

struct GameActionLogPanel: View {
    @ObservedObject var store: PokerGameStore
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                Text("操作日志")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                if !store.engine.actionLog.isEmpty {
                    Text("\(store.engine.actionLog.count)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.5))
            
            // Log entries (scrollable, most recent at bottom)
            if store.engine.actionLog.isEmpty {
                Spacer()
                Text("等待操作...")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(store.engine.actionLog) { entry in
                                actionLogRow(entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .onChangeCompat(of: store.engine.actionLog.count) { _ in
                        if let last = store.engine.actionLog.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.black.opacity(0.35))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    private func actionLogRow(_ entry: ActionLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                // Avatar
                Text(entry.avatar)
                    .font(.system(size: 10))
                
                // Action icon with color
                Image(systemName: entry.iconName)
                    .font(.system(size: 8))
                    .foregroundColor(actionColor(entry))
                
                // Action text
                Text(entry.actionText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(actionColor(entry))
                    .lineLimit(1)
                
                Spacer(minLength: 0)
            }
            
            // 签名动作和评语
            if entry.signatureAction != nil || entry.commentary != nil {
                HStack(spacing: 4) {
                    if let sig = entry.signatureAction {
                        Text("[\(sig)]")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    if let comment = entry.commentary {
                        Text(comment)
                            .font(.system(size: 8))
                            .italic()
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            actionColor(entry).opacity(0.08)
        )
    }
    
    private func actionColor(_ entry: ActionLogEntry) -> Color {
        switch entry.action {
        case .fold: return .gray
        case .check: return .green
        case .call: return Color(hex: "4A90D9")
        case .raise: return .orange
        case .allIn: return .red
        }
    }
}
