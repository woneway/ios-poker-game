import SwiftUI

/// Badge view for displaying player tendency
struct PlayerStyleBadgeView: View {
    let style: PlayerTendency
    var compact: Bool = false
    
    private var backgroundColor: Color {
        switch style {
        case .lag, .tag:
            return Color.blue.opacity(0.15)
        case .callingStation:
            return Color.orange.opacity(0.15)
        case .nit:
            return Color.red.opacity(0.15)
        case .lpp, .abc:
            return Color.green.opacity(0.15)
        case .unknown:
            return Color.gray.opacity(0.15)
        }
    }
    
    private var textColor: Color {
        switch style {
        case .lag, .tag:
            return Color.blue
        case .callingStation:
            return Color.orange
        case .nit:
            return Color.red
        case .lpp, .abc:
            return Color.green
        case .unknown:
            return Color.gray
        }
    }
    
    var body: some View {
        Text(style.rawValue)
            .font(compact ? .caption2 : .caption)
            .fontWeight(.medium)
            .foregroundColor(textColor)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 2 : 4)
            .background(backgroundColor)
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(PlayerTendency.allCases, id: \.self) { style in
            VStack(spacing: 8) {
                PlayerStyleBadgeView(style: style)
                PlayerStyleBadgeView(style: style, compact: true)
            }
        }
    }
    .padding()
}
