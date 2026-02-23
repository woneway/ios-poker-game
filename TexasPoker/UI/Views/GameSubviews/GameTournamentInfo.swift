import SwiftUI

struct GameTournamentInfo: View {
    @ObservedObject var store: PokerGameStore
    
    var body: some View {
        HStack(spacing: 12) {
            // Current blinds
            VStack(alignment: .leading, spacing: 2) {
                Text("盲注")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(store.engine.smallBlindAmount)/\(store.engine.bigBlindAmount)")
                    .font(.system(size: 14, weight: .bold))
            }
            
            Divider()
                .frame(height: 30)
            
            // Level
            VStack(alignment: .leading, spacing: 2) {
                Text("级别")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(store.engine.currentBlindLevel + 1)")
                    .font(.system(size: 14, weight: .bold))
            }
            
            Divider()
                .frame(height: 30)
            
            // Hands until next level
            VStack(alignment: .leading, spacing: 2) {
                Text("下个级别")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                let remaining = (store.engine.tournamentConfig?.handsPerLevel ?? 10) - store.engine.handsAtCurrentLevel
                Text("\(remaining) 手")
                    .font(.system(size: 14, weight: .bold))
            }
            
            if store.engine.anteAmount > 0 {
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("前注")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(store.engine.anteAmount)")
                        .font(.system(size: 14, weight: .bold))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}
