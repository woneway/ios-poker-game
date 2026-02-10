import SwiftUI
import Combine

@main
struct TexasPokerAppApp: App {
    @StateObject private var store = PokerGameStore()
    
    var body: some Scene {
        WindowGroup {
            GameView(store: store)
        }
    }
}
