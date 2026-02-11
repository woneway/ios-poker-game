# Color Assets Setup for Dark/Light Mode

## Overview
This document describes how to manually create color assets in Xcode for dark/light mode support.

## Instructions

### 1. Open Xcode Project
1. Open `TexasPoker.xcodeproj` in Xcode
2. Navigate to `TexasPoker/Assets.xcassets` in the Project Navigator

### 2. Create Color Sets

For each color below, follow these steps:
1. Right-click in the Assets.xcassets area
2. Select "New Color Set"
3. Rename the color set to the name specified
4. Select the color set
5. In the Attributes Inspector (right panel), set "Appearances" to "Any, Dark"
6. Click on "Any Appearance" color well and set the light mode color
7. Click on "Dark Appearance" color well and set the dark mode color

### 3. Color Definitions

#### TableBackground
- **Light Mode**: `#1a5c1a` (RGB: 26, 92, 26)
- **Dark Mode**: `#0d3d0d` (RGB: 13, 61, 13)
- **Usage**: Main background gradient for the poker table

#### TableFelt
- **Light Mode**: `#1e6b1e` (RGB: 30, 107, 30)
- **Dark Mode**: `#145214` (RGB: 20, 82, 20)
- **Usage**: Table felt ellipse color

#### CardBackground
- **Light Mode**: `#ffffff` (RGB: 255, 255, 255) - White
- **Dark Mode**: `#2c2c2c` (RGB: 44, 44, 44)
- **Usage**: Background color for face-up cards

#### PrimaryText
- **Light Mode**: `#000000` (RGB: 0, 0, 0) - Black
- **Dark Mode**: `#ffffff` (RGB: 255, 255, 255) - White
- **Usage**: Primary text color throughout the app

#### SecondaryText
- **Light Mode**: `#666666` (RGB: 102, 102, 102)
- **Dark Mode**: `#999999` (RGB: 153, 153, 153)
- **Usage**: Secondary/dimmed text color

#### ButtonPrimary
- **Light Mode**: `#007AFF` (RGB: 0, 122, 255) - iOS Blue
- **Dark Mode**: `#0A84FF` (RGB: 10, 132, 255) - iOS Dark Blue
- **Usage**: Primary action buttons (Deal, Call, etc.)

#### ButtonDanger
- **Light Mode**: `#FF3B30` (RGB: 255, 59, 48) - iOS Red
- **Dark Mode**: `#FF453A` (RGB: 255, 69, 58) - iOS Dark Red
- **Usage**: Destructive actions (Fold button)

## 4. Verification

After creating all color sets:
1. Build the project (⌘+B)
2. Run the app in the simulator
3. Test light mode: Settings app → Display & Brightness → Light
4. Test dark mode: Settings app → Display & Brightness → Dark
5. Verify colors look correct in both modes

## 5. Fallback Behavior

If color assets are not created, the app will use fallback colors defined in `ColorTheme.swift`:
- `Color.adaptiveTableBackground(colorScheme)`
- `Color.adaptiveTableFelt(colorScheme)`
- `Color.adaptiveCardBackground(colorScheme)`
- etc.

These fallback functions use the same color values as the assets, so the app will work correctly even without the assets (though using assets is the recommended approach).

## Notes

- The app automatically follows the system appearance setting
- No code changes are needed to switch between light/dark mode
- Colors have been chosen to maintain good contrast in both modes
- The brown table border (`#8B4513`) remains the same in both modes for consistency
