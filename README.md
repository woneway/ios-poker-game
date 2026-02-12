# 🃏 iOS Texas Hold'em Poker

<div align="center">

![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![iOS](https://img.shields.io/badge/iOS-15+-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Active-success)

**A professional Texas Hold'em poker game built with SwiftUI**

[English](./README.md) | [中文](./README_CN.md)

</div>

---

## ✨ Features

### 🎮 Core Game Engine
- Complete Texas Hold'em rules implementation
- Multi-player support (2-8 players)
- Tournament and cash game modes
- Advanced betting system (check, call, raise, fold, all-in)

### 🤖 AI Opponents (7 Unique Personalities)
| Character | Style | VPIP | Aggression | Description |
|-----------|-------|------|------------|-------------|
| 🪨 **Rock** | Tight-Aggressive | 15% | High | Plays only premium hands |
| 😈 **Maniac** | Loose-Aggressive | 55% | Very High | Bets constantly, never folds |
| 👩 **Anna** | Loose-Passive | 40% | Very Low | Calls everything, never raises |
| 🦊 **Fox** | Balanced | 45% | Medium | Hard to read, strategic play |
| 🦈 **Shark** | Position-Play | 45% | High | Exploits position, harvests fish |
| 👩‍🏫 **Amy** | GTO-Math | 50% | Medium | Mathematical optimal play |
| 😤 **David** | Tilt-Based | Dynamic | Dynamic | Emotional player, can go on tilt |

### 🧠 Advanced AI System
- Monte Carlo simulation for win rate calculation
- ICM (Independent Chip Model) for tournament play
- Position-based strategy adjustment
- Opponent modeling and profiling
- Bluff frequency and timing optimization

### 📊 Statistics & Tracking
- Hands played
- Win rate by position
- VPIP/PFR tracking
- Session history
- Performance graphs

---

## 🛠 Technology Stack

| Layer | Technology |
|-------|------------|
| **Language** | Swift 5.9+ |
| **UI Framework** | SwiftUI (iOS 15+) |
| **State Management** | Combine + ObservableObject |
| **Architecture** | MVVM + Finite State Machine |
| **Persistence** | Core Data + UserDefaults |
| **Testing** | XCTest |

---

## 📁 Project Structure

```
TexasPoker/
├── App/
│   └── TexasPokerApp.swift          # App entry point
│
├── Core/
│   ├── AI/
│   │   ├── AIProfile.swift          # AI personality definitions
│   │   ├── DecisionEngine.swift      # AI decision making
│   │   ├── BluffDetector.swift      # Bluff probability
│   │   ├── ICMCalculator.swift      # Tournament equity
│   │   ├── MonteCarloSimulator.swift # Win rate calculation
│   │   ├── OpponentModeler.swift    # Player profiling
│   │   ├── RangeAnalyzer.swift      # Hand range analysis
│   │   └── DifficultyManager.swift   # AI difficulty levels
│   │
│   ├── Data/
│   │   ├── PersistenceController.swift # Core Data stack
│   │   ├── StatisticsCalculator.swift  # Stats computation
│   │   ├── DataMigrationManager.swift # Schema migration
│   │   ├── ActionRecorder.swift       # Hand history
│   │   └── DataExporter.swift         # Export functionality
│   │
│   ├── Engine/
│   │   ├── PokerEngine.swift         # Main game loop
│   │   ├── HandEvaluator.swift        # Hand strength evaluation
│   │   ├── BettingManager.swift      # Betting logic
│   │   ├── DealingManager.swift       # Card dealing
│   │   ├── ShowdownManager.swift     # Win determination
│   │   ├── TournamentManager.swift   # Tournament logic
│   │   ├── GameResultsManager.swift  # Result calculation
│   │   └── TiltManager.swift         # Emotional state tracking
│   │
│   ├── FSM/
│   │   ├── GameState.swift           # State definitions
│   │   ├── GameEvent.swift           # Game events
│   │   └── PokerGameStore.swift      # State machine
│   │
│   ├── Models/
│   │   ├── Card.swift                # Card model
│   │   ├── Deck.swift               # Deck management
│   │   ├── Player.swift              # Base player
│   │   ├── HumanPlayer.swift         # Human player
│   │   ├── AIPlayer.swift            # AI player wrapper
│   │   ├── Pot.swift                 # Pot model
│   │   ├── ActionLogEntry.swift      # Action logging
│   │   ├── BlindLevel.swift          # Blind structure
│   │   └── more models...
│   │
│   └── Utils/
│       ├── ColorTheme.swift          # UI theming
│       ├── DeviceHelper.swift        # Device adaptation
│       └── Constants.swift           # App constants
│
├── UI/
│   ├── Components/
│   │   ├── CardView.swift           # Card visualization
│   │   ├── ChipStackView.swift      # Chip stack display
│   │   ├── FlippingCard.swift       # Card flip animation
│   │   └── ActionButtons.swift      # Game actions
│   │
│   └── Views/
│       ├── GameTableView.swift      # Main table view
│       ├── PlayerView.swift         # Player info display
│       ├── ControlPanel.swift       # Player controls
│       ├── SettingsView.swift       # Settings screen
│       ├── StatisticsView.swift     # Stats dashboard
│       ├── RankingsView.swift       # Leaderboards
│       └── GameSubviews/           # Sub-components
│           ├── GameTopBar.swift
│           ├── GamePotDisplay.swift
│           ├── GameHeroControls.swift
│           ├── GameActionLogPanel.swift
│           └── GameTournamentInfo.swift
│
├── Resources/
│   ├── Assets.xcassets
│   ├── Sounds/
│   └── Data/
│
└── TexasPokerTests/
    ├── Core/
    │   └── Engine/
    │       └── HandEvaluatorTests.swift
    ├── UI/
    │   └── ColorThemeTests.swift
    └── UncalledBetTests.swift
```

---

## 🚀 Getting Started

### Prerequisites
- macOS 14+ or macOS 15+ (Apple Silicon recommended)
- Xcode 15+
- iOS 15.0+ Simulator or Device

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/ios-poker-game.git
cd ios-poker-game

# Open in Xcode
open TexasPoker.xcodeproj

# Select a simulator and run (Cmd+R)
```

### Building from Command Line

```bash
xcodebuild -project TexasPoker.xcodeproj \
           -scheme TexasPoker \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           -configuration Debug \
           build
```

---

## 📖 Usage

### Starting a Game
1. Launch the app
2. Select game mode (Cash Game / Tournament)
3. Choose opponents (1-7 AI players)
4. Set buy-in amount
5. Press "Deal" to start

### Game Controls
- **Check**: Available when no bet pending
- **Call**: Match the current bet
- **Raise**: Increase the bet
- **Fold**: Surrender the hand
- **All-In**: Commit all chips

### AI Customization
Each AI opponent can be customized:
- Personality profile
- Starting stack
- Difficulty level
- Avatar selection

---

## 🧪 Testing

```bash
# Run all tests
xcodebuild test -project TexasPoker.xcodeproj \
                -scheme TexasPoker \
                -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -project TexasPoker.xcodeproj \
                -scheme TexasPoker \
                -destination 'platform=iOS Simulator,name=iPhone 15' \
                -only-testing:TexasPokerTests/Core/Engine/HandEvaluatorTests
```

---

## 📈 Architecture

### State Machine
```
┌─────────────────────────────────────────────────────────┐
│                    Game States                           │
├─────────────────────────────────────────────────────────┤
│  idle → preFlop → flop → turn → river → showdown       │
│    ↑                                                    │
│    └───loop (new hand)                                 │
└─────────────────────────────────────────────────────────┘
```

### Decision Flow
```
Player Action
    ↓
Game Context (pot, position, hand strength)
    ↓
AI Decision Engine
    ├── Check hand strength (Monte Carlo)
    ├── Calculate pot odds
    ├── Apply personality adjustments
    └── Select action (weighted random)
    ↓
Execute Action
```

---

## 🎨 Screenshots

<div align="center">

| Game Table | Player View | Statistics |
|:----------:|:-----------:|:----------:|
| ![Table](./docs/images/table.png) | ![Player](./docs/images/player.png) | ![Stats](./docs/images/stats.png) |

</div>

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [SwiftUI](https://developer.apple.com/swiftui/) - Apple's modern UI framework
- [Combine](https://developer.apple.com/documentation/combine/) - Reactive programming framework
- [XCTest](https://developer.apple.com/documentation/xctest/) - Testing framework

---

<div align="center">

**Made with ❤️ by the Poker AI Team**

</div>
