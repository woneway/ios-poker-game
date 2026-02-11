import SwiftUI

@main
struct TexasPokerApp: App {
    @StateObject private var settings = GameSettings()
    
    var body: some Scene {
        WindowGroup {
            GameViewContainer(settings: settings)
        }
    }
}

struct GameViewContainer: View {
    @ObservedObject var settings: GameSettings
    @StateObject private var store: PokerGameStore
    
    init(settings: GameSettings) {
        self.settings = settings
        let config = settings.getTournamentConfig()
        _store = StateObject(wrappedValue: PokerGameStore(mode: settings.gameMode, config: config))
    }
    
    var body: some View {
        GameView(settings: settings)
    }
}
