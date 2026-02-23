import SwiftUI

struct GamePotDisplay: View {
    @ObservedObject var store: PokerGameStore
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.yellow)
                Text("底池：$\(formattedPot)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.yellow)
            }
            
            // 只在 showdown 阶段且有边池时显示边池详情
            if store.state == .showdown && store.engine.pot.hasSidePots {
                let mainAmount = store.engine.pot.portions.first?.amount ?? 0
                Text("主池: $\(mainAmount)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.yellow.opacity(0.8))
                ForEach(Array(store.engine.pot.sidePots.enumerated()), id: \.offset) { idx, sidePot in
                    Text("边池\(idx + 1): $\(sidePot.amount)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    /// 格式化底池金额（千位逗号）
    private var formattedPot: String {
        let amount = store.engine.pot.total
        if amount >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        }
        return "\(amount)"
    }
}
