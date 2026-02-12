import SwiftUI

struct GameTopBar: View {
    @ObservedObject var store: PokerGameStore
    @Binding var showSettings: Bool
    let unreadLogCount: Int
    let onToggleActionLog: () -> Void
    
    var body: some View {
        HStack {
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Text(streetName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.4)))
            
            Spacer()
            
            Text("Hand #\(store.engine.handNumber)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            
            // 日志切换按钮（仅竖屏有效，横屏面板始终可见）
            Button(action: { onToggleActionLog() }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                    if unreadLogCount > 0 {
                        Text("\(min(unreadLogCount, 99))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Circle().fill(Color.red))
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .accessibilityLabel("操作日志，\(unreadLogCount)条未读")
        }
    }
    
    private var streetName: String {
        switch store.engine.currentStreet {
        case .preFlop: return "Pre-Flop"
        case .flop: return "Flop"
        case .turn: return "Turn"
        case .river: return "River"
        }
    }
}
