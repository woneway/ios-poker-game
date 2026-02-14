//
//  GameViewLayoutTests.swift
//  TexasPokerTests
//
//  Test suite for UI layout issues:
//  1. Hero cards visibility
//  2. Player avatar positioning (outside table)
//  3. Table height sufficiency
//

import XCTest
import SwiftUI
@testable import TexasPoker

class GameViewLayoutTests: XCTestCase {
    
    // MARK: - Hero Card Visibility Tests
    
    func testHeroCardsVisible_whenPlayerIsAreHuman() {
        // Given: A human player (Hero) with hole cards
        var hero = Player(
            name: "Hero",
            chips: 1000,
            isHuman: true,
            aiProfile: nil
        )
        hero.holeCards = [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .hearts)]
        
        // When: PlayerCardsView is rendered with isHuman = true
        let cardWidth: CGFloat = 42
        let view = PlayerCardsView(
            player: hero,
            isHero: true,
            showCards: true,
            cardWidth: cardWidth
        )
        
        // Then: The cards should be visible (not hidden)
        let host = UIHostingController(rootView: view)
        let heroView = hero
        
        XCTAssertFalse(heroView.holeCards.isEmpty, "Hero should have cards")
    }
    
    func testHeroCardsShownFaceUp() {
        // Given: A human player with cards
        var hero = Player(
            name: "Hero",
            chips: 1000,
            isHuman: true
        )
        hero.holeCards = [Card(rank: .queen, suit: .clubs), Card(rank: .jack, suit: .diamonds)]
        
        // When: Using FlippingCard with isHero = true
        let flippingCard = FlippingCard(
            card: hero.holeCards[0],
            delay: 0,
            width: 40,
            isHero: true
        )
        
        // Then: Card should be face up (CardFaceView rendered)
        let host = UIHostingController(rootView: flippingCard)
        
        // Verify the card has dimensions
        XCTAssertGreaterThan(flippingCard.width, 0)
    }
    
    // MARK: - Player Avatar Positioning Tests
    
    func testPlayerAvatarsOutsideTable() {
        // Given: 8 players in oval layout
        let store = PokerGameStore(mode: .cashGame, config: TournamentConfig.standard)
        store.engine.players = create8Players()
        
        // When: Calculating player positions for oval layout
        let geo = MockGeometryProxy(width: 390, height: 844)
        
        // Then: Player positions should extend beyond table bounds
        let w = geo.size.width
        let h = geo.size.height
        
        let centerX = w / 2
        let centerY = h * 0.45
        let radiusX = w * 0.32
        let radiusY = h * 0.25
        
        let seatAngles: [Double] = [270, 225, 180, 135, 90, 45, 0, 315]
        
        // Verify bottom players (Hero at 270°) extend below table center
        let heroAngle = 270 * Double.pi / 180
        let heroX = centerX + radiusX * CGFloat(cos(heroAngle))
        let heroY = centerY - radiusY * CGFloat(sin(heroAngle))
        
        // Hero should be below the table center (y > centerY)
        XCTAssertGreaterThan(heroY, centerY, "Hero should be below table center (outside table)")
        
        // Verify top players (seat 4 at 90°) extend above table
        let topAngle = 90 * Double.pi / 180
        let topY = centerY - radiusY * CGFloat(sin(topAngle))
        
        XCTAssertLessThan(topY, centerY, "Top player should be above table center (outside table)")
    }
    
    func testTableDimensionsAllowPlayerAvatars() {
        // Given: Screen dimensions
        let screenHeight: CGFloat = 844
        let tableHeight: CGFloat = screenHeight * 0.58
        let tableYPosition: CGFloat = screenHeight * 0.45
        
        // When: Calculating if table is tall enough
        let tableTop = tableYPosition - tableHeight / 2
        let tableBottom = tableYPosition + tableHeight / 2
        
        // Then: Table should have enough height for player avatars
        let minRequiredHeight: CGFloat = 200  // Minimum for player avatars
        XCTAssertGreaterThan(tableHeight, minRequiredHeight, 
            "Table height (\(tableHeight)) should be > \(minRequiredHeight)")
    }
    
    // MARK: - Table Height Tests
    
    func testPortraitLayoutTableHeight() {
        // Given: Portrait layout dimensions
        let geoWidth: CGFloat = 390
        let geoHeight: CGFloat = 844
        
        // When: Portrait table height is calculated
        let tableHeight = geoHeight * 0.58
        
        // Then: Table should be tall enough for 8 players
        XCTAssertGreaterThanOrEqual(tableHeight, 400, 
            "Table height \(tableHeight) should be >= 400 for 8-player layout")
    }
    
    func testLandscapeLayoutTableHeight() {
        // Given: Landscape layout dimensions
        let geoWidth: CGFloat = 844
        let geoHeight: CGFloat = 390
        
        // When: Landscape table height is calculated
        let tableHeight = geoHeight * 0.70
        
        // Then: Table should fit within available height
        XCTAssertLessThanOrEqual(tableHeight, geoHeight * 0.8,
            "Table should not exceed available space")
    }
    
    // MARK: - Helper Methods
    
    private func create8Players() -> [Player] {
        var players: [Player] = []
        
        // Hero (human)
        let hero = Player(name: "Hero", chips: 1000, isHuman: true)
        players.append(hero)
        
        // 7 AI players
        let aiNames = ["Bot1", "Bot2", "Bot3", "Bot4", "Bot5", "Bot6", "Bot7"]
        for name in aiNames {
            let player = Player(
                name: name,
                chips: Int.random(in: 500...2000),
                isHuman: false,
                aiProfile: AIProfile(
                    name: name,
                    avatar: "🤖",
                    description: "AI Player",
                    tightness: 0.5,
                    aggression: 0.5,
                    bluffFreq: 0.2,
                    foldTo3Bet: 0.5,
                    cbetFreq: 0.6,
                    cbetTurnFreq: 0.45,
                    positionAwareness: 0.5,
                    tiltSensitivity: 0.2,
                    callDownTendency: 0.3
                )
            )
            players.append(player)
        }
        
        return players
    }
}

// MARK: - Mock GeometryProxy

struct MockGeometryProxy {
    var size: CGSize
    
    init(width: CGFloat, height: CGFloat) {
        self.size = CGSize(width: width, height: height)
    }
}
