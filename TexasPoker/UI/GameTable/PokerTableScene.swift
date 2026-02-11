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
    
    /// Animate chip from player position to pot center
    func animateChipToPot(from seatIndex: Int, amount: Int) {
        let seatAngles: [Double] = [270, 225, 180, 135, 90, 45, 0, 315]
        
        guard seatIndex >= 0 && seatIndex < seatAngles.count else { return }
        
        let centerX = size.width / 2
        let centerY = size.height * 0.42
        let radiusX = size.width * 0.38
        let radiusY = size.height * 0.28
        
        let angle = seatAngles[seatIndex] * .pi / 180
        let startX = centerX + radiusX * CGFloat(cos(angle))
        let startY = centerY - radiusY * CGFloat(sin(angle))
        
        let chip = ChipNode(amount: amount)
        chip.position = CGPoint(x: startX, y: startY)
        addChild(chip)
        
        // Parabolic path
        let controlPoint = CGPoint(
            x: (startX + centerX) / 2,
            y: min(startY, centerY * 0.3) - 50
        )
        
        let path = UIBezierPath()
        path.move(to: chip.position)
        path.addQuadCurve(
            to: CGPoint(x: centerX, y: centerY * 0.3),
            controlPoint: controlPoint
        )
        
        let moveAction = SKAction.follow(
            path.cgPath,
            asOffset: false,
            orientToPath: false,
            duration: 0.5
        )
        moveAction.timingMode = .easeOut
        
        let scaleAction = SKAction.scale(to: 0.7, duration: 0.5)
        let group = SKAction.group([moveAction, scaleAction])
        
        let sequence = SKAction.sequence([
            group,
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ])
        
        chip.run(sequence)
        SoundManager.shared.playSound(.chip)
    }
    
    /// Animate chips from pot center to winner position
    func animateWinnerChips(to seatIndex: Int, amount: Int) {
        let seatAngles: [Double] = [270, 225, 180, 135, 90, 45, 0, 315]
        
        guard seatIndex >= 0 && seatIndex < seatAngles.count else { return }
        
        let centerX = size.width / 2
        let centerY = size.height * 0.42
        let radiusX = size.width * 0.38
        let radiusY = size.height * 0.28
        
        let angle = seatAngles[seatIndex] * .pi / 180
        let endX = centerX + radiusX * CGFloat(cos(angle))
        let endY = centerY - radiusY * CGFloat(sin(angle))
        
        // Create 5 chips flying to winner
        for i in 0..<5 {
            let chip = ChipNode(amount: amount / 5)
            chip.position = CGPoint(x: centerX, y: centerY * 0.3)
            addChild(chip)
            
            let delay = Double(i) * 0.1
            let moveAction = SKAction.move(
                to: CGPoint(x: endX + CGFloat.random(in: -10...10), y: endY + CGFloat.random(in: -10...10)),
                duration: 0.8
            )
            moveAction.timingMode = .easeOut
            
            let scaleAction = SKAction.scale(to: 0.8, duration: 0.8)
            let group = SKAction.group([moveAction, scaleAction])
            
            let sequence = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                group,
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ])
            
            chip.run(sequence)
        }
        
        SoundManager.shared.playSound(.win)
    }
}

// MARK: - ChipNode

class ChipNode: SKShapeNode {
    init(amount: Int) {
        super.init()
        
        // Create chip circle
        let circle = SKShapeNode(circleOfRadius: 15)
        circle.fillColor = .systemRed
        circle.strokeColor = .white
        circle.lineWidth = 2
        
        // Add amount label
        let label = SKLabelNode(text: "\(amount)")
        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.fontName = "HelveticaNeue-Bold"
        
        addChild(circle)
        addChild(label)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
