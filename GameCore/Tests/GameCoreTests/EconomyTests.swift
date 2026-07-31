import XCTest
@testable import GameCore

final class EconomyTests: XCTestCase {
    func testCoinConversionRoundsDown() {
        let config = EconomyConfig(pointsPerCoin: 500)
        XCTAssertEqual(config.coins(forScore: 0), 0)
        XCTAssertEqual(config.coins(forScore: 499), 0)
        XCTAssertEqual(config.coins(forScore: 500), 1)
        XCTAssertEqual(config.coins(forScore: 12499), 24)
        XCTAssertEqual(config.coins(forScore: -100), 0)
    }

    func testComboBonusOnlyFromSecondStreak() {
        let config = EconomyConfig()
        XCTAssertEqual(config.comboBonus(forStreak: 0), 0)
        XCTAssertEqual(config.comboBonus(forStreak: 1), 0)
        XCTAssertEqual(config.comboBonus(forStreak: 2), 5)
        XCTAssertEqual(config.comboBonus(forStreak: 7), 5)
    }

    func testWalletCreditAndSpend() {
        let wallet = Wallet(store: UserDefaults.makeTemporary())
        XCTAssertEqual(wallet.balance, 0)

        wallet.credit(100)
        XCTAssertEqual(wallet.balance, 100)

        XCTAssertTrue(wallet.spend(40))
        XCTAssertEqual(wallet.balance, 60)

        XCTAssertFalse(wallet.spend(61))
        XCTAssertEqual(wallet.balance, 60)
    }

    func testWalletIgnoresNonPositiveAmounts() {
        let wallet = Wallet(store: UserDefaults.makeTemporary())
        wallet.credit(-5)
        wallet.credit(0)
        XCTAssertEqual(wallet.balance, 0)
        XCTAssertFalse(wallet.spend(0))
        XCTAssertFalse(wallet.spend(-3))
    }

    func testWalletPersistsAcrossInstances() {
        let store = UserDefaults.makeTemporary()
        Wallet(store: store).credit(250)

        let reloaded = Wallet(store: store)
        XCTAssertEqual(reloaded.balance, 250)
    }
}

extension UserDefaults {
    /// Her test için izole, boş bir store.
    static func makeTemporary() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }
}
