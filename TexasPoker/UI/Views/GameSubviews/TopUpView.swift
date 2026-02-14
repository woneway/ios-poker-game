import SwiftUI

/// 补码面板 - 现金桌补充筹码界面
struct TopUpView: View {
    let currentChips: Int
    let maxBuyIn: Int
    let bigBlind: Int
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void

    @State private var targetAmount: Double = 0.5  // 映射到 [currentChips, maxBuyIn]

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                // 标题
                Text("补码")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                // 当前筹码
                HStack {
                    Text("当前筹码:")
                        .foregroundColor(.white.opacity(0.7))
                    Text("$\(currentChips)")
                        .foregroundColor(.white)
                    Spacer()
                }

                // 目标筹码滑块
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("补到:")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("$\(computeTargetAmount())")
                            .foregroundColor(.yellow)
                        Text("(\(computeTargetAmount() / bigBlind) BB)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Slider(value: $targetAmount, in: 0...1)
                        .accentColor(.yellow)
                }

                // 补码金额
                let topUpAmount = computeTargetAmount() - currentChips
                HStack {
                    Text("补码金额:")
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("+$\(topUpAmount)")
                        .foregroundColor(.green)
                        .font(.headline)
                }

                // 快捷按钮
                HStack(spacing: 8) {
                    presetButton("半仓", value: normalizedValue(for: currentChips + (maxBuyIn - currentChips) / 2))
                    presetButton("满仓", value: 1.0)
                }

                // 按钮
                HStack(spacing: 16) {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Capsule().fill(Color.gray.opacity(0.3)))
                    }

                    Button(action: { onConfirm(computeTargetAmount()) }) {
                        Text("确认补码 $\(topUpAmount)")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Capsule().fill(Color.green))
                    }
                }
            }
            .padding(32)
        }
    }

    // MARK: - Helper Functions

    /// 计算目标金额（对齐到 BB 整数倍）
    private func computeTargetAmount() -> Int {
        let rawAmount = Double(currentChips) + targetAmount * Double(maxBuyIn - currentChips)
        // 对齐到 BB 整数倍
        let alignedAmount = (rawAmount / Double(bigBlind)).rounded() * Double(bigBlind)
        // 确保在有效范围内
        return max(currentChips, min(maxBuyIn, Int(alignedAmount)))
    }

    /// 将金额标准化到 0~1 范围
    private func normalizedValue(for amount: Int) -> Double {
        let clampedAmount = max(currentChips, min(maxBuyIn, amount))
        return Double(clampedAmount - currentChips) / Double(maxBuyIn - currentChips)
    }

    /// 快捷金额按钮
    private func presetButton(_ title: String, value: Double) -> some View {
        Button(action: { targetAmount = value }) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(targetAmount == value ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(targetAmount == value ? Color.green : Color.white.opacity(0.2))
                )
        }
    }
}

// MARK: - Preview

#Preview {
    TopUpView(
        currentChips: 500,
        maxBuyIn: 2000,
        bigBlind: 10,
        onConfirm: { amount in
            print("补码目标金额: $\(amount)")
        },
        onCancel: {
            print("取消补码")
        }
    )
}
