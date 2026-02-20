import Foundation
import CoreData

protocol DataRepositoryProtocol {
    func save<T: NSManagedObject>(_ object: T) throws
    func delete<T: NSManagedObject>(_ object: T) throws
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T]
    func saveContext() throws
}

final class DataRepository: DataRepositoryProtocol {
    static let shared = DataRepository()
    
    private let persistenceController: PersistenceController
    
    var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    func save<T: NSManagedObject>(_ object: T) throws {
        try object.managedObjectContext?.save()
    }
    
    func delete<T: NSManagedObject>(_ object: T) throws {
        viewContext.delete(object)
        try viewContext.save()
    }
    
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T] {
        try viewContext.fetch(request)
    }
    
    func saveContext() throws {
        if viewContext.hasChanges {
            try viewContext.save()
        }
    }
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistenceController.container.performBackgroundTask(block)
    }
}

final class StatisticsCache {
    static let shared = StatisticsCache()
    
    private var cache: [String: CachedStats] = [:]
    private let queue = DispatchQueue(label: "com.poker.statistics.cache", attributes: .concurrent)
    private let maxAge: TimeInterval = 60
    
    struct CachedStats {
        let stats: PlayerStats
        let timestamp: Date
    }
    
    func getStats(for key: String) -> PlayerStats? {
        queue.sync {
            guard let cached = cache[key] else { return nil }
            if Date().timeIntervalSince(cached.timestamp) > maxAge {
                cache.removeValue(forKey: key)
                return nil
            }
            return cached.stats
        }
    }
    
    func setStats(_ stats: PlayerStats, for key: String) {
        queue.async(flags: .barrier) {
            self.cache[key] = CachedStats(stats: stats, timestamp: Date())
        }
    }
    
    func invalidate(key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}
