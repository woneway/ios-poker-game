import SwiftUI
import UIKit

struct DeviceHelper {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static func isLandscape(_ geo: GeometryProxy) -> Bool {
        geo.size.width > geo.size.height
    }
    
    static var scaleFactor: CGFloat {
        isIPad ? 1.5 : 1.0
    }
    
    static func cardWidth(for geo: GeometryProxy) -> CGFloat {
        let base: CGFloat = 40
        if isIPad {
            return base * 1.5
        }
        return base
    }
    
    static func cardHeight(for geo: GeometryProxy) -> CGFloat {
        let width = cardWidth(for: geo)
        return width * 1.4 // Standard poker card aspect ratio
    }
}
