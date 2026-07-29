import Foundation
import Observation
import GameCore

/// Uygulamanın gözlemlenebilir durumu. GameCore sınıfları Observation kullanmadığı için
/// SwiftUI'ın göreceği değerler (skor, bakiye, skin durumu) burada aynalanır;
/// tüm oyun/ekonomi işlemleri bu modelden geçer.
@MainActor
@Observable
final class AppModel {
    enum Screen {
        case menu
        case playing
        case store
    }

    var screen: Screen = .menu

    private(set) var engine: GameEngine
    private(set) var gameID = UUID()

    private(set) var score = 0
    private(set) var comboStreak = 0
    private(set) var isGameOver = false
    private(set) var isNewHighScore = false
    private(set) var lastEarnedCoins = 0

    private(set) var coinBalance: Int
    private(set) var highScore: Int
    private(set) var ownedSkinIDs: Set<String>
    private(set) var activeSkinID: String

    let wallet: Wallet
    let skins: SkinManager
    let economy = EconomyConfig.standard
    let gameCenter = GameCenterManager()

    private let store: UserDefaults
    private static let highScoreKey = "score.best"

    init(store: UserDefaults = .standard) {
        self.store = store
        let wallet = Wallet(store: store)
        self.wallet = wallet
        self.skins = SkinManager(store: store, wallet: wallet)
        self.engine = GameEngine()
        self.coinBalance = wallet.balance
        self.highScore = store.integer(forKey: AppModel.highScoreKey)
        self.ownedSkinIDs = skins.ownedIDs
        self.activeSkinID = skins.activeSkinID

        // UI testleri ve simülatör doğrulaması için ekran kısayolları
        if ProcessInfo.processInfo.arguments.contains("-autostart") {
            startNewGame()
        } else if ProcessInfo.processInfo.arguments.contains("-store") {
            screen = .store
        }

        #if DEBUG
        // Mağaza testleri için: "-coins 5000" argümanı bakiye yükler
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-coins"),
           arguments.indices.contains(index + 1),
           let amount = Int(arguments[index + 1]), amount > 0 {
            wallet.credit(amount)
            coinBalance = wallet.balance
        }
        #endif
    }

    var activeSkin: SkinDefinition { skins.activeSkin }


    // MARK: - Oyun akışı

    func startNewGame() {
        engine = GameEngine()
        gameID = UUID()
        score = 0
        comboStreak = 0
        isGameOver = false
        isNewHighScore = false
        lastEarnedCoins = 0
        screen = .playing
    }

    func place(handIndex: Int, at origin: GridPoint) -> PlacementOutcome? {
        guard let outcome = engine.place(handIndex: handIndex, at: origin) else { return nil }
        score = engine.score
        comboStreak = engine.comboStreak

        // Kombo ödülü: peş peşe patlatmalarda anında coin
        let comboBonus = economy.comboBonus(forStreak: outcome.comboStreak)
        if comboBonus > 0 {
            wallet.credit(comboBonus)
            coinBalance = wallet.balance
        }

        if engine.isGameOver {
            finishGame()
        }
        return outcome
    }

    private func finishGame() {
        isGameOver = true
        lastEarnedCoins = economy.coins(forScore: engine.score)
        wallet.credit(lastEarnedCoins)
        coinBalance = wallet.balance
        if engine.score > highScore {
            highScore = engine.score
            isNewHighScore = true
            store.set(highScore, forKey: AppModel.highScoreKey)
        }
        gameCenter.submit(score: engine.score)
    }

    func goToMenu() { screen = .menu }
    func goToStore() { screen = .store }

    // MARK: - Mağaza

    @discardableResult
    func buySkin(_ id: String) -> PurchaseResult {
        let result = skins.purchase(id)
        coinBalance = wallet.balance
        ownedSkinIDs = skins.ownedIDs
        if result == .success {
            skins.activate(id)
            activeSkinID = skins.activeSkinID
        }
        return result
    }

    func selectSkin(_ id: String) {
        if skins.activate(id) {
            activeSkinID = skins.activeSkinID
        }
    }
}
