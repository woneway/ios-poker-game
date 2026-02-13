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
            // Background with subtle texture
            RoundedRectangle(cornerRadius: width * 0.1)
                .fill(Color.adaptiveCardBackground(colorScheme))
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            
            // Inner Stroke for premium feel
            RoundedRectangle(cornerRadius: width * 0.1)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
            
            // Content
            VStack(spacing: -2) {
                // Top-left corner
                HStack {
                    VStack(spacing: -1) {
                        Text(card.rank.display)
                            .font(.system(size: width * 0.3, weight: .bold, design: .rounded))
                        Text(card.suit.rawValue)
                            .font(.system(size: width * 0.2))
                    }
                    Spacer()
                }
                .padding(.leading, 4)
                .padding(.top, 4)
                
                Spacer()
                
                // Center Suit
                Text(card.suit.rawValue)
                    .font(.system(size: width * 0.5))
                    .opacity(0.15)
                
                Spacer()
                
                // Bottom-right corner (inverted)
                HStack {
                    Spacer()
                    VStack(spacing: -1) {
                        Text(card.rank.display)
                            .font(.system(size: width * 0.3, weight: .bold, design: .rounded))
                        Text(card.suit.rawValue)
                            .font(.system(size: width * 0.2))
                    }
                    .rotationEffect(.degrees(180))
                }
                .padding(.trailing, 4)
                .padding(.bottom, 4)
            }
            .foregroundColor(isRed ? Color(hex: "D32F2F") : Color(hex: "212121"))
        }
    }
}

struct CardBackView: View {
    let width: CGFloat
    
    var body: some View {
        ZStack {
            // Background with Gradient
            RoundedRectangle(cornerRadius: width * 0.1)
                .fill(Color.cardBackGradient)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            // Pattern Overlay (Diamond grid)
            GeometryReader { geo in
                Path { path in
                    let size = 10.0
                    for x in stride(from: 0, to: geo.size.width, by: size) {
                        for y in stride(from: 0, to: geo.size.height, by: size) {
                            if Int(x/size + y/size) % 2 == 0 {
                                path.addRect(CGRect(x: x, y: y, width: size/2, height: size/2))
                            }
                        }
                    }
                }
                .fill(Color.black.opacity(0.1))
            }
            .clipShape(RoundedRectangle(cornerRadius: width * 0.1))
            
            // White Border
            RoundedRectangle(cornerRadius: width * 0.1)
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                .padding(2)
            
            // Center Emblem
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: width * 0.6, height: width * 0.6)
                .overlay(
                    Text("♠️")
                        .font(.system(size: width * 0.3))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(radius: 2)
                )
        }
    }
}
