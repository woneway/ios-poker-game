import SpriteKit

class PokerTableScene: SKScene {
    
    var onAnimationComplete: (() -> Void)?
    
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
    }
    
    // MARK: - Animations
    
    func dealCardAnimation(to position: CGPoint, delay: TimeInterval = 0) {
        let card = CardNode()
        card.position = CGPoint(x: size.width / 2, y: size.height * 0.4)
        card.setScale(0.5)
        addChild(card)
        
        let moveAction = SKAction.move(to: position, duration: 0.3)
        moveAction.timingMode = .easeOut
        
        let scaleAction = SKAction.scale(to: 0.25, duration: 0.3)
        let group = SKAction.group([moveAction, scaleAction])
        
        let sequence = SKAction.sequence([
            SKAction.wait(forDuration: delay),
            group,
            SKAction.wait(forDuration: 0.3),
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ])
        
        card.run(sequence)
    }
    
    /// Play deal animation only for active seat indices
    /// - Parameter activeSeatIndices: indices of players still in the game (0-7)
    func playDealAnimation(activeSeatIndices: [Int] = Array(0..<8)) {
        // Seat angles matching GameView's oval layout (degrees, counterclockwise from right)
        let seatAngles: [Double] = [270, 225, 180, 135, 90, 45, 0, 315]
        
        let centerX = size.width / 2
        let centerY = size.height * 0.42
        let radiusX = size.width * 0.38
        let radiusY = size.height * 0.28
        
        var cardIndex = 0
        for seatIdx in activeSeatIndices {
            guard seatIdx >= 0 && seatIdx < seatAngles.count else { continue }
            let angle = seatAngles[seatIdx] * .pi / 180
            let x = centerX + radiusX * CGFloat(cos(angle))
            let y = centerY - radiusY * CGFloat(sin(angle))
            let pos = CGPoint(x: x, y: y)
            
            // Deal 2 cards per player
            dealCardAnimation(to: pos, delay: Double(cardIndex) * 0.08)
            cardIndex += 1
            dealCardAnimation(to: CGPoint(x: pos.x + 8, y: pos.y), delay: Double(cardIndex) * 0.08)
            cardIndex += 1
        }
        
        let totalDuration = Double(cardIndex) * 0.08 + 0.8
        
        run(SKAction.sequence([
            SKAction.wait(forDuration: totalDuration),
            SKAction.run { [weak self] in self?.onAnimationComplete?() }
        ]))
        
        SoundManager.shared.playSound(.deal)
    }
}
