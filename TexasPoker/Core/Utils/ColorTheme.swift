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
        colorScheme == .dark ? Color(hex: "2c2c2c") : Color.white
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
}
