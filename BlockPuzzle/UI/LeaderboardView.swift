import SwiftUI
import GameKit

/// Game Center'ın kendi liderlik tablosu ekranını SwiftUI içinde gösterir.
struct LeaderboardView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let controller = GKGameCenterViewController(
            leaderboardID: GameCenterManager.highScoreLeaderboardID,
            playerScope: .global,
            timeScope: .allTime
        )
        controller.gameCenterDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator { dismiss() }
    }

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            onFinish()
        }
    }
}
