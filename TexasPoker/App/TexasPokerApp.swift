import SwiftUI
import CoreData

@main
struct TexasPokerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var settings = GameSettings()

    init() {
        DataMigrationManager.shared.migrateIfNeeded()
        // 启动定期清理定时器，防止内存泄漏
        DecisionEngine.startPeriodicCleanup()
    }

    var body: some Scene {
        WindowGroup {
            LobbyView(settings: settings)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
