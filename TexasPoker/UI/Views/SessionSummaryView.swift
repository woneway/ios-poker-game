import SwiftUI

// MARK: - Session Summary View
/// Displays comprehensive stats after a hand ends
struct SessionSummaryView: View {
    let handNumber: Int
    let heroWinnings: Int
    let heroCards: [Card]
    let communityCards: [Card]
    let handResult: HandResult
    let totalHands: Int
    let totalProfit: Int
    let onDismiss: () -> Void
    let onNextHand: () -> Void
    
    @State private var showDetails = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { /* Prevent dismiss on tap */ }
            
            VStack(spacing: 16) {
                // Header
                Text("第 \(handNumber) 手结束")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                // Result badge
                resultBadge
                
                // Cards display
                VStack(spacing: 8) {
                    // Hero cards
                    HStack(spacing: 4) {
                        ForEach(heroCards) { card in
                            CardView(card: card, width: 50)
                        }
                    }
                    
                    // VS indicator
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    // Community cards
                    HStack(spacing: -8) {
                        ForEach(communityCards) { card in
                            CardView(card: card, width: 40)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                // Profit display
                HStack(spacing: 4) {
                    Image(systemName: heroWinnings >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundColor(heroWinnings >= 0 ? .green : .red)
                    Text(heroWinnings >= 0 ? "+$\(heroWinnings)" : "-$\(abs(heroWinnings))")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(heroWinnings >= 0 ? .green : .red)
                }
                
                // Session stats
                VStack(spacing: 8) {
                    HStack {
                        StatItem(title: "总手数", value: "\(totalHands)", icon: "number.circle")
                        StatItem(title: "总盈亏", value: (totalProfit >= 0 ? "+" : "") + "$\(totalProfit)", 
                                icon: "dollarsign.circle", color: totalProfit >= 0 ? .green : .red)
                    }
                    
                    if showDetails {
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        HStack {
                            StatItem(title: "手牌结果", value: handResult.description, icon: "hand.raised")
                            StatItem(title: "最佳组合", value: handResult.bestHand, icon: "crown.fill")
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                // Toggle details
                Button(action: { withAnimation { showDetails.toggle() } }) {
                    HStack {
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        Text(showDetails ? "收起详情" : "显示详情")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: onDismiss) {
                        Text("关闭")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 100, height: 40)
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onNextHand) {
                        HStack {
                            Text("下一手")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 120, height: 40)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green]),
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: .green.opacity(0.4), radius: 4, y: 2)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.adaptiveSurface(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            .padding(24)
        }
    }
    
    private var resultBadge: some View {
        let (text, color, icon): (String, Color, String) = {
            switch handResult {
            case .win:
                return ("获胜", .green, "crown.fill")
            case .loss:
                return ("失败", .red, "xmark.circle.fill")
            case .tie:
                return ("平局", .yellow, "equal.circle.fill")
            case .fold:
                return ("弃牌", .gray, "hand.raised.fill")
            }
        }()
        
        return HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(color.opacity(0.3))
        .overlay(
            Capsule()
                .stroke(color, lineWidth: 2)
        )
        .clipShape(Capsule())
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .blue
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Hand Result Enum
enum HandResult {
    case win
    case loss
    case tie
    case fold
    
    var description: String {
        switch self {
        case .win: return "获胜"
        case .loss: return "失败"
        case .tie: return "平局"
        case .fold: return "弃牌"
        }
    }
    
    var bestHand: String {
        switch self {
        case .win, .loss, .tie:
            return "-" // Would be populated with actual hand rank
        case .fold:
            return "N/A"
        }
    }
}

// MARK: - Session Summary Data
struct SessionSummaryData {
    let handNumber: Int
    let winnings: Int
    let heroCards: [Card]
    let communityCards: [Card]
    let result: HandResult
    let totalHands: Int
    let totalProfit: Int
}

// MARK: - Color Extensions
extension Color {
    static func adaptiveSurface(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7")
    }
}

// MARK: - Preview
struct SessionSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SessionSummaryView(
            handNumber: 15,
            heroWinnings: 250,
            heroCards: [
                Card(suit: .hearts, rank: .ace),
                Card(suit: .spades, rank: .king)
            ],
            communityCards: [
                Card(suit: .hearts, rank: .queen),
                Card(suit: .diamonds, rank: .jack),
                Card(suit: .clubs, rank: .ten),
                Card(suit: .spades, rank: .two),
                Card(suit: .hearts, rank: .three)
            ],
            handResult: .win,
            totalHands: 15,
            totalProfit: 450,
            onDismiss: {},
            onNextHand: {}
        )
    }
}
