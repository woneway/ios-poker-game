import SwiftUI

/// 买入选择视图 - 现金桌买入金额选择界面
struct BuyInView: View {
    let config: CashGameConfig
    let onConfirm: (Int) -> Void
    
    @State private var buyInAmount: Double = 0.5  // 0~1 映射到 min~max
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // 标题
                Text("选择买入金额")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                // 盲注信息
                Text("盲注 \(config.smallBlind)/\(config.bigBlind)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                
                // 金额显示
                let amount = computeAmount()
                Text("$\(amount)")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.yellow)
                
                Text("\(amount / config.bigBlind) BB")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                
                // 滑块
                Slider(value: $buyInAmount, in: 0...1)
                    .accentColor(.yellow)
                    .padding(.horizontal, 40)
                
                // 快捷按钮
                HStack(spacing: 8) {
                    presetButton("Min", value: 0)
                    presetButton("40BB", value: normalizedValue(for: config.bigBlind * 40))
                    presetButton("60BB", value: normalizedValue(for: config.bigBlind * 60))
                    presetButton("80BB", value: normalizedValue(for: config.bigBlind * 80))
                    presetButton("Max", value: 1.0)
                }
                
                // 确认按钮
                Button(action: { onConfirm(computeAmount()) }) {
                    Text("确认买入 $\(computeAmount())")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Capsule().fill(Color.yellow))
                }
                .padding(.horizontal, 40)
            }
            .padding(32)
        }
    }
    
    // MARK: - Helper Functions
    
    /// 计算当前滑块值对应的买入金额（对齐到 BB 整数倍）
    private func computeAmount() -> Int {
        let rawAmount = Double(config.minBuyIn) + buyInAmount * Double(config.maxBuyIn - config.minBuyIn)
        // 对齐到 BB 整数倍
        let alignedAmount = (rawAmount / Double(config.bigBlind)).rounded() * Double(config.bigBlind)
        // 确保在有效范围内
        return max(config.minBuyIn, min(config.maxBuyIn, Int(alignedAmount)))
    }
    
    /// 将金额标准化到 0~1 范围
    private func normalizedValue(for amount: Int) -> Double {
        let clampedAmount = max(config.minBuyIn, min(config.maxBuyIn, amount))
        return Double(clampedAmount - config.minBuyIn) / Double(config.maxBuyIn - config.minBuyIn)
    }
    
    /// 快捷金额按钮
    private func presetButton(_ title: String, value: Double) -> some View {
        Button(action: { buyInAmount = value }) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(buyInAmount == value ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(buyInAmount == value ? Color.yellow : Color.white.opacity(0.2))
                )
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    BuyInView(
        config: .default,
        onConfirm: { amount in
            print("买入金额: $\(amount)")
        }
    )
}
