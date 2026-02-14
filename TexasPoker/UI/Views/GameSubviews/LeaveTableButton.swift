import SwiftUI

struct LeaveTableButton: View {
    @ObservedObject var store: PokerGameStore
    let isInHand: Bool  // true = 显示"打完就走"，false = 显示"离开牌桌"
    
    var body: some View {
        if store.engine.gameMode == .cashGame {
            if isInHand {
                // "打完就走" 标记按钮
                Button(action: {
                    store.isLeavingAfterHand.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: store.isLeavingAfterHand
                              ? "checkmark.circle.fill" : "arrow.right.circle")
                        Text(store.isLeavingAfterHand ? "已标记离开" : "打完就走")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(store.isLeavingAfterHand ? .orange : .white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            store.isLeavingAfterHand
                                ? Color.orange.opacity(0.2)
                                : Color.white.opacity(0.1)
                        )
                    )
                }
            } else {
                // "离开牌桌" 按钮
                Button(action: {
                    store.showLeaveConfirm = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.circle")
                        Text("离开牌桌")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                }
            }
        }
    }
}

// MARK: - Preview
struct LeaveTableButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.green.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Preview would need a proper store setup
                // For now, showing static preview
                LeaveTableButton(
                    store: PokerGameStore(),
                    isInHand: false
                )
                
                LeaveTableButton(
                    store: PokerGameStore(),
                    isInHand: true
                )
            }
        }
    }
}
