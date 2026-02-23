# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A professional Texas Hold'em poker game for iOS built with SwiftUI. The app features AI opponents with unique personalities, multiple game modes (Cash Game and Tournament), and comprehensive statistics tracking. Pure client-side application with no backend.

## Commands

### Build
```bash
xcodebuild -project TexasPoker.xcodeproj \
           -scheme TexasPoker \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           -configuration Debug \
           build
```

### Generate Xcode Project
```bash
xcodegen generate
```

### Run Tests
```bash
# All tests
xcodebuild test -project TexasPoker.xcodeproj \
                -scheme TexasPoker \
                -destination 'platform=iOS Simulator,name=iPhone 15'

# Specific test class
xcodebuild test -project TexasPoker.xcodeproj \
                -scheme TexasPoker \
                -destination 'platform=iOS Simulator,name=iPhone 15' \
                -only-testing:TexasPokerTests/Core/Engine/HandEvaluatorTests
```

### Lint
```bash
swiftlint
```

## Architecture

### Pattern: MVVM + Finite State Machine (FSM)

**Game Flow:**
```
idle → dealing → waitingForAction → betting → showdown → (loop back to idle)
```

**Key State Components:**
- `PokerGameStore` (Core/Engine/FSM/) - State machine implementation
- `GameState` - State definitions
- `GameEvent` - Event definitions

### Core Modules

| Module | Location | Responsibility |
|--------|----------|----------------|
| **PokerEngine** | Core/Engine/ | Main game loop, card dealing, street progression |
| **BettingManager** | Core/Engine/ | Betting logic (check, call, raise, fold, all-in) |
| **ShowdownManager** | Core/Engine/ | Determines winners, distributes pot |
| **HandEvaluator** | Core/Engine/Evaluator/ | Evaluates hand strength |
| **DecisionEngine** | Core/AI/ | AI decision making |
| **ICMCalculator** | Core/AI/ | Independent Chip Model for tournament equity |
| **MonteCarloSimulator** | Core/AI/ | Win rate calculation |
| **CashGameManager** | Core/Engine/ | Cash game session management |
| **TournamentManager** | Core/Engine/ | Tournament blind structure, levels |
| **StatisticsCalculator** | Core/Data/ | VPIP, PFR, AF, and other poker stats |
| **PersistenceController** | Core/Data/ | Core Data stack |

### UI Architecture

SwiftUI-based with Combine for reactive state management:
- `GameTableView` - Main game table
- `PlayerView` - Player card display
- `ControlPanel` - Player action buttons (Check, Call, Raise, Fold, All-in)
- `SettingsView` - Game settings
- `StatisticsView` - Stats dashboard

## Key Technical Details

- **Target:** iOS 17.0+
- **Swift Version:** 5.0+
- **Bundle ID:** smartegg.TexasPoker
- **No external dependencies** - Uses only native Apple frameworks (SwiftUI, Combine, CoreData, XCTest)
- **Tests excluded from SwiftLint** (see .swiftlint.yml)

## Game Logic Important Files

- `Core/Engine/PokerEngine.swift` - Main game loop
- `Core/Engine/BettingManager.swift` - All betting operations
- `Core/Engine/ShowdownManager.swift` - Showdown and pot distribution
- `Core/Engine/Evaluator/HandEvaluator.swift` - Hand ranking logic
- `Core/AI/DecisionEngine.swift` - AI action selection
- `Core/Models/ActionLogEntry.swift` - Action history for statistics
