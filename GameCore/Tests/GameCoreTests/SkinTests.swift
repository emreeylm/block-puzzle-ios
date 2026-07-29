import XCTest
@testable import GameCore

final class SkinTests: XCTestCase {
    private func makeManager(balance: Int = 0) -> (SkinManager, Wallet, UserDefaults) {
        let store = UserDefaults.makeTemporary()
        let wallet = Wallet(store: store)
        if balance > 0 { wallet.credit(balance) }
        let manager = SkinManager(store: store, wallet: wallet)
        return (manager, wallet, store)
    }

    func testDefaultSkinOwnedAndActive() {
        let (manager, _, _) = makeManager()
        XCTAssertTrue(manager.isOwned(SkinCatalog.defaultSkinID))
        XCTAssertEqual(manager.activeSkinID, SkinCatalog.defaultSkinID)
        XCTAssertEqual(manager.activeSkin.id, SkinCatalog.defaultSkinID)
    }

    func testPurchaseDeductsCoins() {
        let (manager, wallet, _) = makeManager(balance: 300)
        XCTAssertEqual(manager.purchase("neon"), .success)
        XCTAssertEqual(wallet.balance, 50)
        XCTAssertTrue(manager.isOwned("neon"))
    }

    func testPurchaseFailsWithInsufficientFunds() {
        let (manager, wallet, _) = makeManager(balance: 100)
        XCTAssertEqual(manager.purchase("neon"), .insufficientFunds)
        XCTAssertEqual(wallet.balance, 100)
        XCTAssertFalse(manager.isOwned("neon"))
    }

    func testPurchaseUnknownSkin() {
        let (manager, _, _) = makeManager(balance: 1000)
        XCTAssertEqual(manager.purchase("yok-boyle-skin"), .notFound)
    }

    func testRepurchaseRejected() {
        let (manager, wallet, _) = makeManager(balance: 500)
        XCTAssertEqual(manager.purchase("candy"), .success)
        XCTAssertEqual(manager.purchase("candy"), .alreadyOwned)
        XCTAssertEqual(wallet.balance, 350)
    }

    func testActivateRequiresOwnership() {
        let (manager, _, _) = makeManager(balance: 1000)
        XCTAssertFalse(manager.activate("wood"))
        XCTAssertEqual(manager.activeSkinID, SkinCatalog.defaultSkinID)

        XCTAssertEqual(manager.purchase("wood"), .success)
        XCTAssertTrue(manager.activate("wood"))
        XCTAssertEqual(manager.activeSkinID, "wood")
    }

    func testStatePersistsAcrossInstances() {
        let store = UserDefaults.makeTemporary()
        let wallet = Wallet(store: store)
        wallet.credit(500)

        let first = SkinManager(store: store, wallet: wallet)
        first.purchase("candy")
        first.activate("candy")

        let second = SkinManager(store: store, wallet: Wallet(store: store))
        XCTAssertTrue(second.isOwned("candy"))
        XCTAssertEqual(second.activeSkinID, "candy")
    }

    func testAllCatalogSkinsHaveEnoughBlockColors() {
        for skin in SkinCatalog.all {
            XCTAssertGreaterThanOrEqual(
                skin.blockHexes.count, PieceGenerator.defaultColorCount,
                "Skin \(skin.id) yeterli blok rengi tanımlamıyor"
            )
        }
    }
}
