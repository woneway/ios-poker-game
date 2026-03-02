import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    /// 主线程上下文 (UI 相关操作使用)
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// 创建一个新的后台上下文 (用于后台数据处理)
    /// 使用时需要在 context.perform {} 块中执行操作
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TexasPoker")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable lightweight migration so we can add fields like `profileId`
        // without breaking existing installs.
        if let desc = container.persistentStoreDescriptions.first {
            desc.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            desc.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// 线程安全地执行后台任务
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }

    /// For testing purposes
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
}
