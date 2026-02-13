import SwiftUI

extension Color {
    // Table colors
    static let tableBackground = Color("TableBackground")
    static let tableFelt = Color("TableFelt")
    
    // Card colors
    static let cardBackground = Color("CardBackground")
    
    // Text colors
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")
    
    // Button colors
    static let buttonPrimary = Color("ButtonPrimary")
    static let buttonDanger = Color("ButtonDanger")
    
    // MARK: - Gradients
    
    static let tableGradient = RadialGradient(
        gradient: Gradient(colors: [Color(hex: "0A3D0A"), Color(hex: "051F05")]),
        center: .center,
        startRadius: 100,
        endRadius: 500
    )

    static let cardBackGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "B71C1C"), Color(hex: "880E4F")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Fallback colors (if assets not created)
    
    /// Adaptive table background color based on color scheme
    static func adaptiveTableBackground(_ colorScheme: ColorScheme) -> Color {
        // Darker, more premium wood/felt tone
        colorScheme == .dark ? Color(hex: "1B1B1B") : Color(hex: "2C2C2C")
    }
    
    /// Adaptive table felt color based on color scheme
    static func adaptiveTableFelt(_ colorScheme: ColorScheme) -> Color {
        // Deep rich green
        colorScheme == .dark ? Color(hex: "0D330D") : Color(hex: "144514")
    }
    
    /// Adaptive card background color based on color scheme
    static func adaptiveCardBackground(_ colorScheme: ColorScheme) -> Color {
        // Real cards are always white-ish, even in dark mode
        return Color.white
    }
    
    /// Adaptive primary text color based on color scheme
    static func adaptivePrimaryText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    /// Adaptive secondary text color based on color scheme
    static func adaptiveSecondaryText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "999999") : Color(hex: "666666")
    }
    
    /// Adaptive button primary color based on color scheme
    static func adaptiveButtonPrimary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "0A84FF") : Color(hex: "007AFF")
    }
    
    /// Adaptive button danger color based on color scheme
    static func adaptiveButtonDanger(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "FF453A") : Color(hex: "FF3B30")
    }

    
    // MARK: - Chip Colors
    
    static let chipWhite = Color(hex: "E0E0E0")
    static let chipRed = Color(hex: "D32F2F")
    static let chipGreen = Color(hex: "388E3C")
    static let chipBlue = Color(hex: "1976D2")
    static let chipBlack = Color(hex: "212121")
    static let chipPurple = Color(hex: "7B1FA2")
    static let chipOrange = Color(hex: "F57C00")
    
    static func chipColor(for amount: Int) -> Color {
        switch amount {
        case 1...4: return chipWhite
        case 5...24: return chipRed
        case 25...99: return chipGreen
        case 100...499: return chipBlue
        case 500...999: return chipBlack
        case 1000...4999: return chipPurple
        default: return chipOrange
        }
    }
    
    static let chipColors: [Int: Color] = [
        1: chipWhite,
        5: chipRed,
        25: chipGreen,
        100: chipBlue,
        500: chipBlack,
        1000: chipPurple,
        5000: chipOrange
    ]
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
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
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
