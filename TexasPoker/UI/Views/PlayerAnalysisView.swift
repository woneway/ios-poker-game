import SwiftUI

/// Player analysis main entry view
/// NavigationStack wrapper with support for hiding back button when accessed from settings
struct PlayerAnalysisView: View {
    let hideBackButton: Bool
    
    init(hideBackButton: Bool = false) {
        self.hideBackButton = hideBackButton
    }
    
    var body: some View {
        NavigationStack {
            PlayerListView()
                .navigationTitle("玩家分析")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    if hideBackButton {
                        ToolbarItem(placement: .navigationBarLeading) {
                            EmptyView()
                        }
                    }
                }
        }
    }
}

#Preview {
    PlayerAnalysisView()
}
