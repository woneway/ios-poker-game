import SwiftUI

struct CardView: View {
    let card: Card? // Nil means face down
    let width: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    private var height: CGFloat { width * 1.2 }
    
    var body: some View {
        ZStack {
            if let card = card {
                CardFaceView(card: card, width: width)
            } else {
                CardBackView(width: width)
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

struct CardFaceView: View {
    let card: Card
    let width: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    private var isRed: Bool {
        return card.suit == .hearts || card.suit == .diamonds
    }
    
    private var height: CGFloat { width * 1.2 }
    
    var body: some View {
        ZStack {
            // Background with subtle texture
            RoundedRectangle(cornerRadius: width * 0.1)
                .fill(Color.adaptiveCardBackground(colorScheme))
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            
            // Inner Stroke for premium feel
            RoundedRectangle(cornerRadius: width * 0.1)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
            
            // Content — compact layout for 1.2 aspect ratio
            VStack(spacing: 0) {
                // Top-left: rank + suit
                HStack {
                    VStack(spacing: -1) {
                        Text(card.rank.display)
                            .font(.system(size: width * 0.32, weight: .bold, design: .rounded))
                        Text(card.suit.rawValue)
                            .font(.system(size: width * 0.22))
                    }
                    .minimumScaleFactor(0.6)
                    Spacer()
                }
                .padding(.leading, 3)
                .padding(.top, 2)
                
                Spacer(minLength: 0)
                
                // Center: large suit icon
                Text(card.suit.rawValue)
                    .font(.system(size: width * 0.45))
                
                Spacer(minLength: 0)
            }
            .padding(.bottom, 2)
            .foregroundColor(isRed ? Color(hex: "D32F2F") : Color(hex: "212121"))
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

struct CardBackView: View {
    let width: CGFloat
    private var height: CGFloat { width * 1.2 }
    
    var body: some View {
        ZStack {
            // Background with Gradient
            RoundedRectangle(cornerRadius: width * 0.1)
                .fill(Color.cardBackGradient)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            // Pattern Overlay (Diamond grid) — 使用 Canvas 替代 GeometryReader 避免尺寸溢出
            Canvas { context, size in
                let step: CGFloat = 10
                for x in stride(from: CGFloat(0), to: size.width, by: step) {
                    for y in stride(from: CGFloat(0), to: size.height, by: step) {
                        if Int(x / step + y / step) % 2 == 0 {
                            let rect = CGRect(x: x, y: y, width: step / 2, height: step / 2)
                            context.fill(Path(rect), with: .color(.black.opacity(0.1)))
                        }
                    }
                }
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
        .frame(width: width, height: height)
        .clipped()
    }
}
