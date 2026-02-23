import SwiftUI
import CoreData

@main
struct TexasPokerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var settings = GameSettings()
    
    init() {
        DataMigrationManager.shared.migrateIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            LobbyView(settings: settings)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
