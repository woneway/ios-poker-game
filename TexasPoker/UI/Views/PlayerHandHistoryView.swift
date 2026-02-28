import SwiftUI

/// View for displaying a player's hand history
struct PlayerHandHistoryView: View {
    let playerName: String
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss
    @State private var handHistories: [StatisticsCalculator.HandHistorySummary] = []
    @State private var isLoading: Bool = true

    private let getHandHistoryUseCase: GetHandHistoryUseCase

    init(playerName: String, gameMode: GameMode) {
        self.playerName = playerName
        self.gameMode = gameMode
        self.getHandHistoryUseCase = GetHandHistoryUseCase()
    }

    init(playerName: String, gameMode: GameMode, useCase: GetHandHistoryUseCase) {
        self.playerName = playerName
        self.gameMode = gameMode
        self.getHandHistoryUseCase = useCase
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if handHistories.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无历史牌局")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(handHistories, id: \.id) { summary in
                            HandHistoryRowView(summary: summary, playerName: playerName)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("历史牌局")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadHandHistories()
            }
        }
    }

    private func loadHandHistories() {
        isLoading = true
        handHistories = getHandHistoryUseCase.execute(playerName: playerName, gameMode: gameMode)
        isLoading = false
    }
}

/// Row view for a single hand history entry
struct HandHistoryRowView: View {
    let summary: StatisticsCalculator.HandHistorySummary
    let playerName: String
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    private var isWinner: Bool {
        summary.winnerNames.contains(playerName)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Hand number and date
            HStack {
                Text("第 \(summary.handNumber) 手")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Text(dateFormatter.string(from: summary.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Community cards
            if !summary.communityCards.isEmpty {
                HStack(spacing: 4) {
                    ForEach(summary.communityCards, id: \.self) { card in
                        CardView(card: card, width: 30)
                    }
                }
            }
            
            // Player's cards (if available)
            if !summary.heroCards.isEmpty {
                HStack(spacing: 4) {
                    Text("你的手牌:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(summary.heroCards, id: \.self) { card in
                        CardView(card: card, width: 30)
                    }
                }
            }
            
            // Result
            HStack {
                // Winner info
                VStack(alignment: .leading, spacing: 2) {
                    Text("赢家: \(summary.winnerNames.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("底池: $\(summary.finalPot)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Profit/Loss
                Text(formatCurrency(summary.profit))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(summary.profit >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        
        let formattedAmount = formatter.string(from: NSNumber(value: abs(amount))) ?? "\(abs(amount))"
        
        if amount >= 0 {
            return "+$\(formattedAmount)"
        } else {
            return "-$\(formattedAmount)"
        }
    }
}

/// Compact card view for hand history
struct MiniCardView: View {
    let card: Card
    let size: CardSize
    
    enum CardSize {
        case small, medium, large
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 20
            case .large: return 28
            }
        }
        
        var frameSize: CGFloat {
            switch self {
            case .small: return 24
            case .medium: return 36
            case .large: return 48
            }
        }
    }
    
    private var cardColor: Color {
        switch card.suit {
        case .hearts, .diamonds:
            return .red
        case .spades, .clubs:
            return .black
        }
    }
    
    private var suitSymbol: String {
        switch card.suit {
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .spades: return "♠"
        case .clubs: return "♣"
        }
    }
    
    var body: some View {
        Text("\(card.rank.rawValue)\(suitSymbol)")
            .font(.system(size: size.fontSize, weight: .medium))
            .foregroundColor(cardColor)
            .frame(width: size.frameSize, height: size.frameSize * 1.4)
            .background(Color.white)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    PlayerHandHistoryView(playerName: "石头", gameMode: .cashGame)
}
