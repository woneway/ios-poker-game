import SwiftUI

struct FlippingCard: View {
    let card: Card
    let delay: Double
    var width: CGFloat = 40
    
    // Hero 手牌始终显示正面，非 Hero 使用翻转动画
    var isHero: Bool = false
    @State private var isFlipped = false
    
    private var cardHeight: CGFloat { width * 1.2 }
    
    var body: some View {
        ZStack {
            // Hero 始终显示正面，不翻转
            if isHero {
                CardFaceView(card: card, width: width)
                    .frame(width: width, height: cardHeight)
            } else {
                // 非 Hero 玩家使用翻转动画
                CardBackView(width: width)
                    .frame(width: width, height: cardHeight)
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 90 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
                
                CardFaceView(card: card, width: width)
                    .frame(width: width, height: cardHeight)
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 0 : -90),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
        }
        .frame(width: width, height: cardHeight)
        .onAppear {
            if !isHero {
                withAnimation(.easeInOut(duration: 0.4).delay(delay)) {
                    isFlipped = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    SoundManager.shared.playSound(.flip)
                }
            }
        }
    }
}
