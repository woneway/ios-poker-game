import SwiftUI

@Observable
final class ToastManager {
    static let shared = ToastManager()
    
    var currentEntry: ActionLogEntry?
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    func show(_ entry: ActionLogEntry, duration: TimeInterval = 2.0) {
        dismissTask?.cancel()
        currentEntry = entry
        
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled && currentEntry?.id == entry.id {
                currentEntry = nil
            }
        }
    }
    
    func dismiss() {
        dismissTask?.cancel()
        currentEntry = nil
    }
}
