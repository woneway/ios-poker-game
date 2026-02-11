import SwiftUI

@main
struct TexasPokerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var settings = GameSettings()
    
    init() {
        // Run data migration on app startup
        DataMigrationManager.shared.migrateIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            GameViewContainer(settings: settings)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
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
