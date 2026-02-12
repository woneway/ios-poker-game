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
        gradient: Gradient(colors: [Color(hex: "1a5c1a"), Color(hex: "0d3d0d")]),
        center: .center,
        startRadius: 100,
        endRadius: 500
    )

    static let cardBackGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "b82e2e"), Color(hex: "8a1c1c")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Fallback colors (if assets not created)
    
    /// Adaptive table background color based on color scheme
    static func adaptiveTableBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "0d3d0d") : Color(hex: "1a5c1a")
    }
    
    /// Adaptive table felt color based on color scheme
    static func adaptiveTableFelt(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "145214") : Color(hex: "1e6b1e")
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
    
    static let chipColors: [Int: Color] = [
        1: Color(hex: "FFFFFF"),    // White
        5: Color(hex: "FF3B30"),    // Red
        25: Color(hex: "34C759"),   // Green
        100: Color(hex: "007AFF"),  // Blue
        500: Color(hex: "000000"),  // Black
        1000: Color(hex: "AF52DE"), // Purple
        5000: Color(hex: "FF9500")  // Orange
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
