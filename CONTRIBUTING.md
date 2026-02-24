# Contributing to iOS Poker Game

Thank you for your interest in contributing to the iOS Poker Game project!

## Code of Conduct

By participating in this project, you are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported
2. Use the [bug report template](.github/issue_template.md) to create a new issue
3. Include as much detail as possible:
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Device/iOS version

### Suggesting Features

1. Check the existing issues and pull requests
2. Use the [feature request template](.github/feature_request.md) to create a new issue
3. Explain the use case and why it would benefit the project

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/YourFeature`
3. Make your changes
4. Run tests to ensure nothing is broken
5. Commit with clear messages: `git commit -m 'Add some feature'`
6. Push to your fork: `git push origin feature/YourFeature`
7. Submit a pull request

## Development Setup

### Prerequisites

- macOS 14+ (Sonoma) or macOS 15+ (Sequoia)
- Xcode 15+
- Swift 5.9+
- iOS 15.0+ Simulator or device

### Building the Project

```bash
# Clone the repository
git clone https://github.com/yourusername/ios-poker-game.git
cd ios-poker-game

# Generate Xcode project (after modifying project.yml)
xcodegen generate

# Open in Xcode
open TexasPoker.xcodeproj

# Or build from command line
xcodebuild -project TexasPoker.xcodeproj \
           -scheme TexasPoker \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           build
```

### Linting

```bash
# Run SwiftLint
swiftlint
```

### Running Tests

```bash
xcodebuild test -project TexasPoker.xcodeproj \
                -scheme TexasPoker \
                -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

### Naming Conventions

- **Classes/Structs**: PascalCase (e.g., `PokerEngine`)
- **Functions/Methods**: camelCase (e.g., `calculateHandStrength`)
- **Constants**: camelCase with prefix (e.g., `maxPlayers`)
- **Enums**: PascalCase (e.g., `CardSuit`)

### File Organization

```
TexasPoker/
├── Core/
│   ├── AI/
│   ├── Data/
│   ├── Engine/
│   ├── FSM/
│   ├── Models/
│   └── Utils/
└── UI/
    ├── Components/
    └── Views/
```

## Commit Message Guidelines

Use clear, descriptive commit messages:

```
type: short description

Detailed description if needed

Fixes #issue_number
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code refactoring
- `test`: Tests
- `chore`: Maintenance

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
