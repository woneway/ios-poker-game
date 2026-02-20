import Foundation

struct MemoryEntry: Codable {
    let id: UUID
    let timestamp: Date
    let type: MemoryType
    let importance: Double
    let content: MemoryContent
    let decayRate: Double
    
    enum MemoryType: String, Codable {
        case hand
        case opponent
        case situation
        case mistake
        case success
    }
    
    struct MemoryContent: Codable {
        let title: String
        let description: String
        let keyInsight: String?
        let tags: [String]
    }
    
    var currentRelevance: Double {
        let age = Date().timeIntervalSince(timestamp)
        let daysOld = age / 86400
        return max(0, importance * exp(-decayRate * daysOld))
    }
}

class AIMemorySystem {
    static let shared = AIMemorySystem()
    
    private var memories: [String: [MemoryEntry]] = [:]
    private let queue = DispatchQueue(label: "com.poker.memory", attributes: .concurrent)
    
    private let shortTermDecay = 0.5
    private let longTermDecay = 0.1
    
    private init() {}
    
    func remember(
        playerId: String,
        type: MemoryEntry.MemoryType,
        title: String,
        description: String,
        insight: String? = nil,
        tags: [String] = []
    ) {
        let importance: Double
        switch type {
        case .mistake:
            importance = 0.9
        case .success:
            importance = 0.7
        case .opponent:
            importance = 0.6
        case .situation:
            importance = 0.5
        case .hand:
            importance = 0.3
        }
        
        let entry = MemoryEntry(
            id: UUID(),
            timestamp: Date(),
            type: type,
            importance: importance,
            content: MemoryEntry.MemoryContent(
                title: title,
                description: description,
                keyInsight: insight,
                tags: tags
            ),
            decayRate: type == .hand ? shortTermDecay : longTermDecay
        )
        
        queue.async(flags: .barrier) {
            self.memories[playerId, default: []].append(entry)
            self.cleanupMemories(playerId: playerId)
        }
    }
    
    func rememberOpponentPlay(
        playerId: String,
        opponentId: String,
        action: String,
        result: String,
        insight: String
    ) {
        remember(
            playerId: playerId,
            type: .opponent,
            title: "对手 \(opponentId) 的 \(action)",
            description: result,
            insight: insight,
            tags: [opponentId, action]
        )
    }
    
    func rememberMistake(
        playerId: String,
        situation: String,
        whatWentWrong: String,
        lesson: String
    ) {
        remember(
            playerId: playerId,
            type: .mistake,
            title: "错误: \(situation)",
            description: whatWentWrong,
            insight: lesson,
            tags: ["mistake", situation]
        )
    }
    
    func rememberSuccess(
        playerId: String,
        situation: String,
        whatWorked: String,
        principle: String
    ) {
        remember(
            playerId: playerId,
            type: .success,
            title: "成功: \(situation)",
            description: whatWorked,
            insight: principle,
            tags: ["success", situation]
        )
    }
    
    func recallRelevant(playerId: String, context: String, limit: Int = 5) -> [MemoryEntry] {
        return queue.sync {
            guard let entries = memories[playerId] else { return [] }
            
            let relevant = entries
                .filter { $0.content.tags.contains(context) || $0.content.description.contains(context) }
                .sorted { $0.currentRelevance > $1.currentRelevance }
                .prefix(limit)
            
            return Array(relevant)
        }
    }
    
    func recallOpponent(playerId: String, opponentId: String) -> [MemoryEntry] {
        return queue.sync {
            guard let entries = memories[playerId] else { return [] }
            
            return entries
                .filter { $0.type == .opponent && $0.content.tags.contains(opponentId) }
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(10)
                .map { $0 }
        }
    }
    
    func getKeyLessons(playerId: String) -> [String] {
        return queue.sync {
            guard let entries = memories[playerId] else { return [] }
            
            return entries
                .filter { $0.type == .mistake || $0.type == .success }
                .filter { $0.currentRelevance > 0.3 }
                .compactMap { $0.content.keyInsight }
                .prefix(10)
                .map { $0 }
        }
    }
    
    func getDecisionPatterns(playerId: String) -> [String: Int] {
        return queue.sync {
            guard let entries = memories[playerId] else { return [:] }
            
            var patterns: [String: Int] = [:]
            for entry in entries {
                for tag in entry.content.tags {
                    patterns[tag, default: 0] += 1
                }
            }
            
            return patterns
        }
    }
    
    private func cleanupMemories(playerId: String) {
        guard var entries = memories[playerId] else { return }
        
        entries.removeAll { $0.currentRelevance < 0.1 }
        
        if entries.count > 200 {
            entries = Array(entries.sorted { $0.currentRelevance > $1.currentRelevance }.prefix(200))
        }
        
        memories[playerId] = entries
    }
    
    func clearMemory(playerId: String) {
        queue.async(flags: .barrier) {
            self.memories.removeValue(forKey: playerId)
        }
    }
    
    func exportMemories(playerId: String) -> Data? {
        return queue.sync {
            guard let entries = memories[playerId] else { return nil }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try? encoder.encode(entries)
        }
    }
    
    func importMemories(playerId: String, data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let entries = try? decoder.decode([MemoryEntry].self, from: data) else { return }
        
        queue.async(flags: .barrier) {
            self.memories[playerId] = entries
        }
    }
}

class HandMemory {
    static let shared = HandMemory()
    
    private var handMemory: [UUID: HandRecord] = [:]
    private let queue = DispatchQueue(label: "com.poker.handmemory", attributes: .concurrent)
    
    private init() {}
    
    struct HandRecord: Codable {
        let id: UUID
        let timestamp: Date
        let holeCards: [String]
        let position: Int
        let preflopAction: String
        let communityCards: [String]
        let finalAction: String
        let result: String
        let profit: Int
        let mistakes: [String]
        let learnings: [String]
    }
    
    func recordHand(
        id: UUID,
        holeCards: [Card],
        position: Int,
        preflopAction: PlayerAction,
        communityCards: [Card],
        finalAction: PlayerAction,
        result: HandResult,
        profit: Int,
        mistakes: [String] = [],
        learnings: [String] = []
    ) {
        let record = HandRecord(
            id: id,
            timestamp: Date(),
            holeCards: holeCards.map { $0.id },
            position: position,
            preflopAction: preflopAction.description,
            communityCards: communityCards.map { $0.id },
            finalAction: finalAction.description,
            result: result.rawValue,
            profit: profit,
            mistakes: mistakes,
            learnings: learnings
        )
        
        queue.async(flags: .barrier) {
            self.handMemory[id] = record
        }
    }
    
    func getHand(id: UUID) -> HandRecord? {
        return queue.sync {
            handMemory[id]
        }
    }
    
    func getRecentHands(limit: Int = 20) -> [HandRecord] {
        return queue.sync {
            Array(handMemory.values.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
        }
    }
    
    func getProfitableHands() -> [HandRecord] {
        return queue.sync {
            handMemory.values
                .filter { $0.profit > 0 }
                .sorted { $0.profit > $1.profit }
                .prefix(10)
                .map { $0 }
        }
    }
    
    func getLosingHands() -> [HandRecord] {
        return queue.sync {
            handMemory.values
                .filter { $0.profit < 0 }
                .sorted { $0.profit < $1.profit }
                .prefix(10)
                .map { $0 }
        }
    }
    
    func analyzeMistakes() -> MistakeAnalysis {
        return queue.sync {
            let allMistakes = handMemory.values.flatMap { $0.mistakes }
            
            var mistakeCounts: [String: Int] = [:]
            for mistake in allMistakes {
                mistakeCounts[mistake, default: 0] += 1
            }
            
            let sorted = mistakeCounts.sorted { $0.value > $1.value }
            
            return MistakeAnalysis(
                totalMistakes: allMistakes.count,
                uniqueMistakes: mistakeCounts.count,
                mostCommon: Array(sorted.prefix(5).map { $0.key })
            )
        }
    }
}

struct MistakeAnalysis {
    let totalMistakes: Int
    let uniqueMistakes: Int
    let mostCommon: [String]
}

class StrategicInsightGenerator {
    static let shared = StrategicInsightGenerator()
    
    private init() {}
    
    func generateInsights(playerId: String) -> [StrategicInsight] {
        var insights: [StrategicInsight] = []
        
        let lessons = AIMemorySystem.shared.getKeyLessons(playerId: playerId)
        
        for lesson in lessons.prefix(5) {
            insights.append(StrategicInsight(
                category: .strategy,
                title: "经验总结",
                description: lesson,
                confidence: 0.7
            ))
        }
        
        let patterns = AIMemorySystem.shared.getDecisionPatterns(playerId: playerId)
        for (pattern, count) in patterns.sorted(by: { $0.value > $1.value }).prefix(3) {
            insights.append(StrategicInsight(
                category: .pattern,
                title: "决策模式: \(pattern)",
                description: "出现 \(count) 次",
                confidence: Double(count) / 20.0
            ))
        }
        
        let mistakeAnalysis = HandMemory.shared.analyzeMistakes()
        if mistakeAnalysis.totalMistakes > 0 {
            insights.append(StrategicInsight(
                category: .improvement,
                title: "需要改进",
                description: "发现 \(mistakeAnalysis.totalMistakes) 个错误，最常见: \(mistakeAnalysis.mostCommon.first ?? "无")",
                confidence: 0.8
            ))
        }
        
        return insights
    }
}

struct StrategicInsight {
    enum Category {
        case strategy
        case pattern
        case improvement
    }
    
    let category: Category
    let title: String
    let description: String
    let confidence: Double
}
