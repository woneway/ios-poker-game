import SwiftUI

struct CashSessionSummaryView: View {
    let session: CashGameSession
    let onBackToMenu: () -> Void
    let onRejoin: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // 标题
                Text("Session 总结")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                // 盈亏显示
                let profit = session.netProfit
                VStack(spacing: 4) {
                    Text(profit >= 0 ? "盈利" : "亏损")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(profit >= 0 ? "+" : "")\(profit)")
                        .font(.system(size: 48, weight: .black))
                        .foregroundColor(profit >= 0 ? .green : .red)
                }
                
                // 详细统计
                VStack(spacing: 12) {
                    statRow("手数", "\(session.handsPlayed) 手")
                    statRow("时长", formatDuration(session.duration))
                    statRow("初始买入", "$\(session.initialBuyIn)")
                    if session.topUpTotal > 0 {
                        statRow("补码总额", "$\(session.topUpTotal)")
                    }
                    statRow("最终筹码", "$\(session.finalChips)")
                    if session.maxWin > 0 {
                        statRow("最大盈利", "+\(session.maxWin)")
                    }
                    if session.maxLoss < 0 {
                        statRow("最大亏损", "\(session.maxLoss)")
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                // 按钮
                HStack(spacing: 16) {
                    Button(action: onBackToMenu) {
                        Text("返回菜单")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Capsule().fill(Color.gray.opacity(0.3)))
                    }
                    
                    Button(action: onRejoin) {
                        Text("重新入座")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Capsule().fill(Color.yellow))
                    }
                }
            }
            .padding(32)
        }
    }
    
    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .foregroundColor(.white)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#if DEBUG
struct CashSessionSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        let session = CashGameSession(buyIn: 1000)
        
        CashSessionSummaryView(
            session: session,
            onBackToMenu: {},
            onRejoin: {}
        )
    }
}
#endif
