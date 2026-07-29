import GameKit
import Observation
import UIKit

/// Game Center entegrasyonu: kimlik doğrulama ve skor gönderimi.
/// Backend gerektirmez — liderlik tablosunu Apple barındırır.
///
/// ÖNEMLİ: `highScoreLeaderboardID` App Store Connect'te oluşturulacak
/// liderlik tablosunun kimliğiyle birebir aynı olmalıdır.
@MainActor
@Observable
final class GameCenterManager {
    static let highScoreLeaderboardID = "com.emre.blockpuzzle.highscore"

    private(set) var isAuthenticated = false
    /// Doğrulama denendi ve sonuçlandı mı (başarılı ya da başarısız).
    private(set) var didAttemptAuthentication = false

    func authenticate() {
        guard !didAttemptAuthentication else { return }

        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            MainActor.assumeIsolated {
                if let viewController {
                    // Apple'ın giriş ekranı: kullanıcı henüz oturum açmamış
                    Self.topViewController()?.present(viewController, animated: true)
                    return
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self.didAttemptAuthentication = true
            }
        }
    }

    /// Skoru liderlik tablosuna gönderir. Oturum yoksa sessizce atlanır —
    /// oyun akışı Game Center'a bağımlı değildir.
    func submit(score: Int) {
        guard isAuthenticated, score > 0 else { return }
        GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [Self.highScoreLeaderboardID]
        ) { _ in }
    }

    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController

        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
