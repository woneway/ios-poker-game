import SwiftUI

struct CardView: View {
    let card: Card? // Nil means face down
    let width: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    private var height: CGFloat { width * 1.0 }
    
    var body: some View {
        ZStack {
            if let card = card {
                CardFaceView(card: card, width: width)
            } else {
                CardBackView(width: width)
            }
        }
        .frame(width: width, height: height)
    }
}

struct CardFaceView: View {
    let card: Card
    let width: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    private var isRed: Bool {
        return card.suit == .hearts || card.suit == .diamonds
    }
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.adaptiveCardBackground(colorScheme))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
            
            // Inner Stroke
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
            
            // Content
            VStack(spacing: -1) {
                Text(card.rank.display)
                    .font(.system(size: width * 0.38, weight: .heavy, design: .rounded))
                Text(card.suit.rawValue)
                    .font(.system(size: width * 0.32))
            }
            .foregroundColor(isRed ? .red : .black)
        }
    }
}

struct CardBackView: View {
    let width: CGFloat
    
    var body: some View {
        ZStack {
            // Background with Gradient
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.cardBackGradient)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
            
            // White Border
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.white, lineWidth: 1.5)
                .padding(3)
            
            // Center Icon
            Text("♠️")
                .font(.system(size: width * 0.35))
                .foregroundColor(.white.opacity(0.2))
        }
    }
}
