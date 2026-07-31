import Foundation

/// Oyun ilerledikçe zorluğun nasıl arttığını tanımlar: başta cömert
/// (bol kombo fırsatı, birbirini tamamlayan parçalar, garantili oynanabilir el),
/// oyun uzadıkça sertleşir. Tüm zorluk dengesi bu dosyada toplanır.
///
/// İlerleme **yerleştirilen parça sayısına** bağlıdır: `moves / rampMoves`,
/// 0...1 arasına kırpılır. Skora bağlamak, tek bir büyük kombonun oyuncuyu
/// aniden ileri zorluğa fırlatmasına yol açıyordu; hamle sayısı oyun süresiyle
/// orantılı, düzgün bir tempo verir.
public struct DifficultyCurve: Equatable {
    /// Bu kadar parça yerleştirildiğinde zorluk tavana oturur.
    public var rampMoves: Int

    /// Ele "çizgi tamamlayabilen" parça koyma olasılığı (başlangıç → tavan).
    public var comboHelperStart: Double
    public var comboHelperEnd: Double

    /// Büyük parçanın eşini aynı ele koyma olasılığı (başlangıç → tavan).
    public var harmonyStart: Double
    public var harmonyEnd: Double

    /// Zor (5+ hücreli) şekillerin ağırlık çarpanı (başlangıç → tavan).
    public var hardShapeMultiplierStart: Double
    public var hardShapeMultiplierEnd: Double

    /// Kombo serisinin hayatta kalabileceği, patlatmayan hamle sayısı
    /// (başlangıç → tavan). Oyunun başında zincir kurmayı kolaylaştırır.
    public var comboGraceStart: Int
    public var comboGraceEnd: Int

    /// Bu ilerlemeye kadar el garantisi "üç parça da oynanabilir" hedefiyle başlar.
    public var fullHandGuaranteeUntil: Double

    public init(
        rampMoves: Int = 350,
        comboHelperStart: Double = 1.0,
        comboHelperEnd: Double = 0.06,
        harmonyStart: Double = 1.0,
        harmonyEnd: Double = 0.35,
        hardShapeMultiplierStart: Double = 0.0,
        hardShapeMultiplierEnd: Double = 1.6,
        comboGraceStart: Int = 2,
        comboGraceEnd: Int = 0,
        fullHandGuaranteeUntil: Double = 0.85
    ) {
        self.rampMoves = rampMoves
        self.comboHelperStart = comboHelperStart
        self.comboHelperEnd = comboHelperEnd
        self.harmonyStart = harmonyStart
        self.harmonyEnd = harmonyEnd
        self.hardShapeMultiplierStart = hardShapeMultiplierStart
        self.hardShapeMultiplierEnd = hardShapeMultiplierEnd
        self.comboGraceStart = comboGraceStart
        self.comboGraceEnd = comboGraceEnd
        self.fullHandGuaranteeUntil = fullHandGuaranteeUntil
    }

    public static let standard = DifficultyCurve()

    /// 0 = oyunun başı, 1 = tam zorluk.
    public func progress(forMoves moves: Int) -> Double {
        guard rampMoves > 0 else { return 1 }
        return min(1, max(0, Double(moves) / Double(rampMoves)))
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

    /// Kombo serisi bu kadar patlatmayan hamleye kadar hayatta kalır.
    public func comboGrace(at progress: Double) -> Int {
        Int(interpolate(Double(comboGraceStart), Double(comboGraceEnd), progress).rounded())
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
