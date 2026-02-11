//
//  TexasPokerApp.swift
//  TexasPoker
//
//  Created by 连戊 on 2026/2/11.
//

import SwiftUI
import CoreData

@main
struct TexasPokerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
