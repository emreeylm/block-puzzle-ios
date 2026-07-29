import Foundation

/// Oyun ilerledikçe zorluğun nasıl arttığını tanımlar: başta cömert
/// (bol kombo fırsatı, birbirini tamamlayan parçalar, garantili oynanabilir el),
/// skor yükseldikçe sertleşir. Tüm zorluk dengesi bu dosyada toplanır.
///
/// İlerleme skora bağlıdır: `score / rampScore`, 0...1 arasına kırpılır.
public struct DifficultyCurve: Equatable {
    /// Bu skora ulaşıldığında zorluk tavana oturur.
    public var rampScore: Int

    /// Ele "çizgi tamamlayabilen" parça koyma olasılığı (başlangıç → tavan).
    public var comboHelperStart: Double
    public var comboHelperEnd: Double

    /// Büyük parçanın eşini aynı ele koyma olasılığı (başlangıç → tavan).
    public var harmonyStart: Double
    public var harmonyEnd: Double

    /// Zor (5+ hücreli) şekillerin ağırlık çarpanı (başlangıç → tavan).
    public var hardShapeMultiplierStart: Double
    public var hardShapeMultiplierEnd: Double

    /// Bu ilerlemeye kadar el garantisi "üç parça da oynanabilir" hedefiyle başlar.
    public var fullHandGuaranteeUntil: Double

    public init(
        rampScore: Int = 6000,
        comboHelperStart: Double = 0.85,
        comboHelperEnd: Double = 0.06,
        harmonyStart: Double = 1.0,
        harmonyEnd: Double = 0.35,
        hardShapeMultiplierStart: Double = 0.10,
        hardShapeMultiplierEnd: Double = 1.6,
        fullHandGuaranteeUntil: Double = 0.7
    ) {
        self.rampScore = rampScore
        self.comboHelperStart = comboHelperStart
        self.comboHelperEnd = comboHelperEnd
        self.harmonyStart = harmonyStart
        self.harmonyEnd = harmonyEnd
        self.hardShapeMultiplierStart = hardShapeMultiplierStart
        self.hardShapeMultiplierEnd = hardShapeMultiplierEnd
        self.fullHandGuaranteeUntil = fullHandGuaranteeUntil
    }

    public static let standard = DifficultyCurve()

    /// 0 = oyunun başı, 1 = tam zorluk.
    public func progress(forScore score: Int) -> Double {
        guard rampScore > 0 else { return 1 }
        return min(1, max(0, Double(score) / Double(rampScore)))
    }

    public func comboHelperChance(at progress: Double) -> Double {
        interpolate(comboHelperStart, comboHelperEnd, progress)
    }

    public func harmonyChance(at progress: Double) -> Double {
        interpolate(harmonyStart, harmonyEnd, progress)
    }

    public func hardShapeMultiplier(at progress: Double) -> Double {
        interpolate(hardShapeMultiplierStart, hardShapeMultiplierEnd, progress)
    }

    /// El dağıtılırken sırayla denenecek "kaç parça oynanabilir olsun" hedefleri.
    /// Oyunun başında üç parçanın da sığması aranır, sonra gevşer.
    public func handGuaranteeTargets(at progress: Double) -> [Int] {
        progress < fullHandGuaranteeUntil ? [3, 2, 1] : [2, 1]
    }

    private func interpolate(_ start: Double, _ end: Double, _ progress: Double) -> Double {
        let t = min(1, max(0, progress))
        return start + (end - start) * t
    }
}
