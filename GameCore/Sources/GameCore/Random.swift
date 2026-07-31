import Foundation

/// Deterministik testler için tohumlanabilir RNG (SplitMix64).
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Oyuncunun eline gelecek parçaları üretir.
/// Şekiller hücre sayısına göre ağırlıklandırılır: küçük parçalar sık,
/// tahtayı kilitleyen büyük parçalar (3x3, büyük L) nadir gelir.
public struct PieceGenerator {
    public static let defaultColorCount = 6

    /// Zorluk ayar tablosu: şekil başına ağırlık. Dengeleme burada yapılır.
    /// DİKKAT: Ağırlıklar yön (orientation) başınadır — 4 yönü olan bir aile
    /// (köşe, T, büyük L) toplamda 4 katını alır. Aile toplamını sabit tutmak
    /// için çok yönlü ailelere düşük birim ağırlık verilir; yoksa köşe gibi
    /// parçalar oyunu istila eder.
    static let weightsByShape: [PieceShape: Int] = {
        var weights: [PieceShape: Int] = [:]
        // Tüm aileler ~eşit pay (8); minikler bilinçli düşük, 3x3 hafif kısık
        weights[PieceCatalog.single] = 2                                    // aile: 2
        [PieceCatalog.line2H, PieceCatalog.line2V].forEach { weights[$0] = 2 }   // aile: 4
        [PieceCatalog.line3H, PieceCatalog.line3V].forEach { weights[$0] = 4 }   // aile: 8
        [PieceCatalog.cornerA, PieceCatalog.cornerB,
         PieceCatalog.cornerC, PieceCatalog.cornerD].forEach { weights[$0] = 2 } // aile: 8
        [PieceCatalog.line4H, PieceCatalog.line4V].forEach { weights[$0] = 4 }   // aile: 8
        weights[PieceCatalog.square2] = 8                                   // aile: 8
        [PieceCatalog.tA, PieceCatalog.tB,
         PieceCatalog.tC, PieceCatalog.tD].forEach { weights[$0] = 2 }      // aile: 8
        [PieceCatalog.line5H, PieceCatalog.line5V].forEach { weights[$0] = 4 }   // aile: 8
        [PieceCatalog.bigLA, PieceCatalog.bigLB,
         PieceCatalog.bigLC, PieceCatalog.bigLD].forEach { weights[$0] = 2 }     // aile: 8
        [PieceCatalog.rect2x3, PieceCatalog.rect3x2].forEach { weights[$0] = 4 } // aile: 8
        weights[PieceCatalog.square3] = 6                                   // aile: 6
        return weights
    }()

    /// Bu hücre sayısından itibaren şekil "zor" sayılır ve zorluk eğrisiyle ölçeklenir.
    static let hardShapeCellThreshold = 5

    /// Zor = büyük **ve** hantal. Düz çizgiler bunun dışındadır: 5'li çizgi
    /// beş hücre olmasına rağmen satır doldurmanın en kolay yoludur, onu
    /// bastırmak oyunu kolaylaştırmaz, zorlaştırır. Asıl hantal olanlar
    /// büyük L, 2x3 dikdörtgen ve 3x3 karedir.
    private static func isHard(_ shape: PieceShape) -> Bool {
        let isStraightLine = shape.width == 1 || shape.height == 1
        return shape.cellCount >= hardShapeCellThreshold && !isStraightLine
    }

    private static let weightedShapes: [(shape: PieceShape, weight: Int, isHard: Bool)] =
        PieceCatalog.allShapes.map {
            ($0, weightsByShape[$0] ?? 3, isHard($0))
        }

    private var rng: any RandomNumberGenerator

    public init(seed: UInt64? = nil) {
        if let seed {
            rng = SeededGenerator(seed: seed)
        } else {
            rng = SystemRandomNumberGenerator()
        }
    }

    /// `hardShapeMultiplier`: 5+ hücreli şekillerin ağırlık çarpanı. 1.0 nötr;
    /// oyunun başında küçük (zor parçalar seyrek), ilerledikçe büyür.
    public mutating func makePiece(
        colorCount: Int = PieceGenerator.defaultColorCount,
        hardShapeMultiplier: Double = 1.0
    ) -> Piece {
        Piece(
            shape: makeShape(hardShapeMultiplier: hardShapeMultiplier),
            colorIndex: Int.random(in: 0..<max(colorCount, 1), using: &rng)
        )
    }

    private mutating func makeShape(hardShapeMultiplier: Double) -> PieceShape {
        // Ağırlıklar ondalık tutulur: tam sayıya yuvarlamak, düşük çarpanlarda
        // zor parçaların payını olduğundan yüksek sabitliyordu.
        var weights: [Double] = []
        weights.reserveCapacity(PieceGenerator.weightedShapes.count)
        var total = 0.0
        for entry in PieceGenerator.weightedShapes {
            let weight = entry.isHard
                ? Double(entry.weight) * max(0, hardShapeMultiplier)
                : Double(entry.weight)
            weights.append(weight)
            total += weight
        }

        var roll = Double.random(in: 0..<total, using: &rng)
        var shape = PieceGenerator.weightedShapes[0].shape
        for (index, entry) in PieceGenerator.weightedShapes.enumerated() {
            roll -= weights[index]
            if roll < 0 {
                shape = entry.shape
                break
            }
        }
        return shape
    }

    /// Elin renkleri tekrarsız dağıtılır: aynı anda gelen parçalar birbirinden
    /// ayırt edilebilsin diye. Renk sayısı el boyutundan azsa renkler tükenince
    /// havuz baştan doldurulur.
    public mutating func makeHand(
        count: Int,
        colorCount: Int = PieceGenerator.defaultColorCount,
        hardShapeMultiplier: Double = 1.0
    ) -> [Piece] {
        let palette = max(colorCount, 1)
        var available: [Int] = []
        return (0..<count).map { _ in
            if available.isEmpty { available = Array(0..<palette) }
            let color = available.remove(at: Int.random(in: 0..<available.count, using: &rng))
            return Piece(
                shape: makeShape(hardShapeMultiplier: hardShapeMultiplier),
                colorIndex: color
            )
        }
    }

    /// Verilen olasılıkla true döner (0...1).
    public mutating func chance(_ probability: Double) -> Bool {
        guard probability > 0 else { return false }
        guard probability < 1 else { return true }
        return Double.random(in: 0..<1, using: &rng) < probability
    }

    public mutating func pick<T>(_ items: [T]) -> T? {
        items.randomElement(using: &rng)
    }

    public mutating func index(upTo count: Int) -> Int {
        Int.random(in: 0..<max(count, 1), using: &rng)
    }
}
