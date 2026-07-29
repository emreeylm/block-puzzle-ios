import Foundation

/// Ekonomi kuralları: puanın coine dönüşüm oranı ve kombo ödülü burada tek yerde tutulur.
public struct EconomyConfig: Equatable {
    public var pointsPerCoin: Int
    /// Peş peşe patlatma (kombo, streak >= 2) başına anında verilen coin.
    public var coinsPerCombo: Int

    public init(pointsPerCoin: Int = 50, coinsPerCombo: Int = 5) {
        precondition(pointsPerCoin > 0)
        self.pointsPerCoin = pointsPerCoin
        self.coinsPerCombo = coinsPerCombo
    }

    public static let standard = EconomyConfig()

    /// Oyun sonu skorundan kazanılan coin (aşağı yuvarlanır).
    public func coins(forScore score: Int) -> Int {
        max(0, score) / pointsPerCoin
    }

    /// Bu patlatma bir kombo ise (üst üste en az 2. temizleme) verilecek anlık coin.
    public func comboBonus(forStreak streak: Int) -> Int {
        streak >= 2 ? coinsPerCombo : 0
    }
}

/// Oyuncunun coin cüzdanı. Her değişiklik anında kalıcı store'a yazılır.
public final class Wallet {
    private static let balanceKey = "wallet.balance"

    private let store: UserDefaults
    public private(set) var balance: Int

    public init(store: UserDefaults) {
        self.store = store
        self.balance = store.integer(forKey: Wallet.balanceKey)
    }

    public func credit(_ amount: Int) {
        guard amount > 0 else { return }
        balance += amount
        persist()
    }

    /// Yeterli bakiye varsa düşer ve true döner; yoksa hiçbir şey değişmez.
    @discardableResult
    public func spend(_ amount: Int) -> Bool {
        guard amount > 0, balance >= amount else { return false }
        balance -= amount
        persist()
        return true
    }

    private func persist() {
        store.set(balance, forKey: Wallet.balanceKey)
    }
}
