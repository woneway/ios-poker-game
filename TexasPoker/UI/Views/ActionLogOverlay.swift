import SwiftUI

/// 操作日志浮层面板（竖屏模式，从右侧滑入）
struct ActionLogOverlay: View {
    let entries: [ActionLogEntry]
    let panelWidth: CGFloat
    let onClose: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            header
            logList
        }
        .frame(width: panelWidth)
        .background(Color.black.opacity(0.35))
        // iOS 15 compatibility: avoid UnevenRoundedRectangle (iOS 16+)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .offset(x: max(0, dragOffset))
        .gesture(dismissGesture)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.7))
            Text("操作日志")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            if !entries.isEmpty {
                Text("\(entries.count)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
            }
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .accessibilityLabel("关闭操作日志")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))
    }
    
    // MARK: - Log List
    
    @ViewBuilder
    private var logList: some View {
        if entries.isEmpty {
            Spacer()
            Text("等待操作...")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
            Spacer()
        } else {
            ScrollViewReader { proxy in
                if #available(iOS 17.0, *) {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(entries) { entry in
                                logRow(entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .onChange(of: entries.count, initial: false) { _, _ in
                        if let last = entries.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(entries) { entry in
                                logRow(entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .onChange(of: entries.count) { _ in
                        if let last = entries.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func logRow(_ entry: ActionLogEntry) -> some View {
        HStack(spacing: 4) {
            Text(entry.avatar)
                .font(.system(size: 10))
            Image(systemName: entry.iconName)
                .font(.system(size: 8))
                .foregroundColor(actionColor(entry))
            Text(entry.actionText)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(actionColor(entry))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(actionColor(entry).opacity(0.08))
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
    
    // MARK: - Dismiss Gesture
    
    private var dismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.width > 0 {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                if value.translation.width > 50 {
                    onClose()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        dragOffset = 0
                    }
                }
            }
    }
}
