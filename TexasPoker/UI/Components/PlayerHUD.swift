import SwiftUI

/// PlayerHUD is intentionally empty.
/// VPIP/PFR stats are now displayed exclusively via the Stats Badge
/// in PlayerAvatarView to avoid duplicate HUD elements.
struct PlayerHUD: View {
    let playerName: String
    let gameMode: GameMode

    var body: some View {
        EmptyView()
    }
}
