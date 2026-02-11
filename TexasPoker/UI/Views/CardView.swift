import SwiftUI

struct CardView: View {
    let card: Card? // Nil means face down
    let width: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    private var height: CGFloat { width * 1.0 }
    private var isRed: Bool {
        guard let card = card else { return false }
        return card.suit == .hearts || card.suit == .diamonds
    }
    
    var body: some View {
        ZStack {
            if let card = card {
                // Face Up - adaptive background
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.adaptiveCardBackground(colorScheme))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                
                // Compact 2-row layout: rank on top, suit below
                VStack(spacing: -1) {
                    Text(card.rank.display)
                        .font(.system(size: width * 0.38, weight: .black, design: .rounded))
                    Text(card.suit.rawValue)
                        .font(.system(size: width * 0.32))
                }
                .foregroundColor(isRed ? .red : .black)
            } else {
                // Face Down (Card Back)
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color(red: 0, green: 0, blue: 0.5)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.white, lineWidth: 1.5)
                            .padding(3)
                    )
                    .overlay(
                        Text("♠️")
                            .font(.system(size: width * 0.35))
                            .foregroundColor(.white.opacity(0.2))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
            }
        }
        .frame(width: width, height: height)
    }
}
