import SwiftUI

@main
struct TexasPokerApp: App {
    @StateObject private var store = PokerGameStore()
    
    var body: some Scene {
        WindowGroup {
            GameView(store: store)
        }
    }
}
