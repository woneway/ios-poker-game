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
        let radiusX = size.width * 0.48  // 匹配 GameView 中的玩家位置半径
        let radiusY = size.height * 0.32
        
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
        let radiusX = size.width * 0.48  // 匹配 GameView 中的玩家位置半径
        let radiusY = size.height * 0.32
        
        let angle = seatAngles[seatIndex] * .pi / 180
        let startX = centerX + radiusX * CGFloat(cos(angle))
        let startY = centerY - radiusY * CGFloat(sin(angle))
        
        let chip = ChipNode(amount: amount)
        chip.position = CGPoint(x: startX, y: startY)
        chip.setScale(0.8)
        addChild(chip)
        
        // Parabolic path with randomization
        let controlPoint = CGPoint(
            x: (startX + centerX) / 2 + CGFloat.random(in: -20...20),
            y: min(startY, centerY * 0.3) - 80
        )
        
        let path = UIBezierPath()
        path.move(to: chip.position)
        path.addQuadCurve(
            to: CGPoint(x: centerX + CGFloat.random(in: -15...15), y: centerY * 0.3 + CGFloat.random(in: -15...15)),
            controlPoint: controlPoint
        )
        
        let moveAction = SKAction.follow(
            path.cgPath,
            asOffset: false,
            orientToPath: false,
            duration: 0.6
        )
        moveAction.timingMode = .easeOut
        
        // Add rotation for realism
        let rotateAction = SKAction.rotate(byAngle: CGFloat.pi * 2, duration: 0.6)
        
        let scaleAction = SKAction.scale(to: 0.6, duration: 0.6)
        let group = SKAction.group([moveAction, rotateAction, scaleAction])
        
        let sequence = SKAction.sequence([
            group,
            SKAction.wait(forDuration: 0.1),
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
        let radiusX = size.width * 0.48  // 匹配 GameView 中的玩家位置半径
        let radiusY = size.height * 0.32
        
        let angle = seatAngles[seatIndex] * .pi / 180
        let endX = centerX + radiusX * CGFloat(cos(angle))
        let endY = centerY - radiusY * CGFloat(sin(angle))
        
        // Create 8 chips flying to winner with slight spread
        for i in 0..<8 {
            let chip = ChipNode(amount: amount / 8)
            chip.position = CGPoint(x: centerX + CGFloat.random(in: -20...20), y: centerY * 0.3 + CGFloat.random(in: -20...20))
            chip.setScale(0.6)
            addChild(chip)
            
            let delay = Double(i) * 0.05
            let moveAction = SKAction.move(
                to: CGPoint(x: endX + CGFloat.random(in: -20...20), y: endY + CGFloat.random(in: -20...20)),
                duration: 0.8
            )
            moveAction.timingMode = .easeOut
            
            let scaleAction = SKAction.scale(to: 0.8, duration: 0.8)
            let rotateAction = SKAction.rotate(byAngle: CGFloat.random(in: -3...3), duration: 0.8)
            let group = SKAction.group([moveAction, scaleAction, rotateAction])
            
            let sequence = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                group,
                SKAction.wait(forDuration: 0.2),
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ])
            
            chip.run(sequence)
        }
        
        // Add confetti explosion at winner's position
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.6),
            SKAction.run { [weak self] in
                self?.createConfetti(at: CGPoint(x: endX, y: endY))
            }
        ]))
        
        SoundManager.shared.playSound(.win)
    }
    
    private func createConfetti(at position: CGPoint) {
        let colors: [UIColor] = [.red, .green, .blue, .yellow, .cyan, .magenta, .orange]
        
        for _ in 0..<15 {
            let confetti = SKShapeNode(rectOf: CGSize(width: 6, height: 6))
            confetti.fillColor = colors.randomElement()!
            confetti.strokeColor = .clear
            confetti.position = position
            addChild(confetti)
            
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 30...100)
            let dest = CGPoint(
                x: position.x + cos(angle) * distance,
                y: position.y + sin(angle) * distance
            )
            
            let move = SKAction.move(to: dest, duration: 0.8)
            move.timingMode = .easeOut
            let rotate = SKAction.rotate(byAngle: CGFloat.random(in: -5...5), duration: 0.8)
            let fade = SKAction.fadeOut(withDuration: 0.3)
            
            let seq = SKAction.sequence([
                SKAction.group([move, rotate]),
                fade,
                SKAction.removeFromParent()
            ])
            
            confetti.run(seq)
        }
    }
}

// MARK: - ChipNode

class ChipNode: SKNode {
    private let mainCircle: SKShapeNode
    private let label: SKLabelNode
    
    init(amount: Int) {
        mainCircle = SKShapeNode(circleOfRadius: 16)
        label = SKLabelNode(text: "\(amount)")
        
        super.init()
        
        // Determine color based on amount
        let baseColor: UIColor
        switch amount {
        case 1...4: baseColor = UIColor(hex: "E0E0E0") // White
        case 5...24: baseColor = UIColor(hex: "D32F2F") // Red
        case 25...99: baseColor = UIColor(hex: "388E3C") // Green
        case 100...499: baseColor = UIColor(hex: "1976D2") // Blue
        case 500...999: baseColor = UIColor(hex: "212121") // Black
        case 1000...4999: baseColor = UIColor(hex: "7B1FA2") // Purple
        default: baseColor = UIColor(hex: "F57C00") // Orange
        }
        
        // Main chip body - Simplified for performance
        mainCircle.fillColor = baseColor
        mainCircle.strokeColor = .white
        mainCircle.lineWidth = 2
        
        // Label styling
        label.fontSize = amount >= 1000 ? 10 : 12
        label.fontColor = (amount >= 1 && amount <= 4) ? .black : .white
        label.verticalAlignmentMode = .center
        label.fontName = "HelveticaNeue-Bold"
        label.zPosition = 1
        
        // Simple shadow
        let shadow = SKShapeNode(circleOfRadius: 16)
        shadow.fillColor = .black
        shadow.alpha = 0.2
        shadow.lineWidth = 0
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -1
        addChild(shadow)
        
        addChild(mainCircle)
        addChild(label)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Helper for UIColor from Hex
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue:  CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
