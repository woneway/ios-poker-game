import Foundation

struct BankrollState {
    var currentBankroll: Int
    var buyInSize: Int
    var maxBuyIns: Int
    var riskOfRuin: Double
    
    var buyInCount: Double {
        Double(currentBankroll) / Double(buyInSize)
    }
    
    var isBuyInRecommended: Bool {
        buyInCount < Double(maxBuyIns) / 2.0
    }
    
    var isTablingRecommended: Bool {
        buyInCount >= 2
    }
}

class AIBankrollManager {
    static let shared = AIBankrollManager()
    
    private var playerBankrolls: [String: BankrollState] = [:]
    
    private init() {}
    
    func initializePlayer(_ playerId: String, startingBankroll: Int, buyInSize: Int = 1000, maxBuyIns: Int = 20) {
        playerBankrolls[playerId] = BankrollState(
            currentBankroll: startingBankroll,
            buyInSize: buyInSize,
            maxBuyIns: maxBuyIns,
            riskOfRuin: calculateRiskOfRuin(buyInCount: Double(startingBankroll) / Double(buyInSize), maxBuyIns: maxBuyIns)
        )
    }
    
    func recordWin(_ playerId: String, amount: Int) {
        guard var state = playerBankrolls[playerId] else { return }
        state.currentBankroll += amount
        state.riskOfRuin = calculateRiskOfRuin(buyInCount: Double(state.currentBankroll) / Double(state.buyInSize), maxBuyIns: state.maxBuyIns)
        playerBankrolls[playerId] = state
    }
    
    func recordLoss(_ playerId: String, amount: Int) {
        guard var state = playerBankrolls[playerId] else { return }
        state.currentBankroll -= amount
        state.riskOfRuin = calculateRiskOfRuin(buyInCount: Double(state.currentBankroll) / Double(state.buyInSize), maxBuyIns: state.maxBuyIns)
        playerBankrolls[playerId] = state
    }
    
    func shouldRebuy(_ playerId: String) -> Bool {
        guard let state = playerBankrolls[playerId] else { return false }
        return state.isBuyInRecommended
    }
    
    func shouldLeaveTable(_ playerId: String) -> Bool {
        guard let state = playerBankrolls[playerId] else { return false }
        return state.riskOfRuin > 0.3
    }
    
    private func calculateRiskOfRuin(buyInCount: Double, maxBuyIns: Int) -> Double {
        guard buyInCount > 0 else { return 1.0 }
        let ratio = buyInCount / Double(maxBuyIns)
        return max(0, 1 - ratio)
    }
    
    func getBankrollState(_ playerId: String) -> BankrollState? {
        return playerBankrolls[playerId]
    }
}
