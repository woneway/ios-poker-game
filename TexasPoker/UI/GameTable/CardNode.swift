import SpriteKit

class CardNode: SKShapeNode {
    override init() {
        super.init()
        let rect = CGRect(x: 0, y: 0, width: 60, height: 90)
        self.path = CGPath(rect: rect, transform: nil)
        self.fillColor = .white
        self.strokeColor = .black
        self.lineWidth = 2
        
        // Simple label to show it's a card
        let label = SKLabelNode(text: "🂡")
        label.fontSize = 40
        label.fontColor = .black
        label.position = CGPoint(x: 30, y: 30)
        self.addChild(label)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
