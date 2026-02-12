import SwiftUI

struct FlippingCard: View {
    let card: Card
    let delay: Double
    var width: CGFloat = 40
    @State private var isFlipped = false
    
    var body: some View {
        ZStack {
            // Card back
            CardBackView(width: width)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? 90 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
            
            // Card front
            CardFaceView(card: card, width: width)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -90),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .frame(width: width, height: width * 1.4)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).delay(delay)) {
                isFlipped = true
            }
            // Play flip sound with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                SoundManager.shared.playSound(.flip)
            }
        }
    }
}
