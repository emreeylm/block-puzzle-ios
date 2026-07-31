import Foundation

/// Izgara üzerinde bir hücre koordinatı. x sağa, y yukarı artar.
public struct GridPoint: Hashable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// Bir parçanın hücre düzeni. Koordinatlar normalize edilir (min x ve min y sıfıra çekilir).
public struct PieceShape: Hashable {
    public let cells: [GridPoint]
    public let width: Int
    public let height: Int

    public init(_ rawCells: [GridPoint]) {
        precondition(!rawCells.isEmpty, "PieceShape requires at least one cell")
        let minX = rawCells.map { $0.x }.min()!
        let minY = rawCells.map { $0.y }.min()!
        var normalized = rawCells.map { GridPoint(x: $0.x - minX, y: $0.y - minY) }
        normalized.sort { a, b in
            if a.y != b.y { return a.y < b.y }
            return a.x < b.x
        }
        self.cells = normalized
        self.width = normalized.map { $0.x }.max()! + 1
        self.height = normalized.map { $0.y }.max()! + 1
    }

    public var cellCount: Int { cells.count }
}

/// Oyuncunun eline gelen tek bir parça: şekil + renk.
public struct Piece: Hashable {
    public let shape: PieceShape
    public let colorIndex: Int

    public init(shape: PieceShape, colorIndex: Int) {
        self.shape = shape
        self.colorIndex = colorIndex
    }
}

/// Oyundaki tüm parça şekilleri. Yeni şekil eklemek = bu listeye eklemek.
public enum PieceCatalog {
    private static func shape(_ coords: [(Int, Int)]) -> PieceShape {
        PieceShape(coords.map { GridPoint(x: $0.0, y: $0.1) })
    }

    // Tekli ve çizgiler
    public static let single = shape([(0, 0)])
    public static let line2H = shape([(0, 0), (1, 0)])
    public static let line2V = shape([(0, 0), (0, 1)])
    public static let line3H = shape([(0, 0), (1, 0), (2, 0)])
    public static let line3V = shape([(0, 0), (0, 1), (0, 2)])
    public static let line4H = shape([(0, 0), (1, 0), (2, 0), (3, 0)])
    public static let line4V = shape([(0, 0), (0, 1), (0, 2), (0, 3)])
    public static let line5H = shape([(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)])
    public static let line5V = shape([(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)])

    // Kareler ve dikdörtgenler
    public static let square2 = shape([(0, 0), (1, 0), (0, 1), (1, 1)])
    public static let square3 = shape((0..<3).flatMap { x in (0..<3).map { y in (x, y) } })
    public static let rect2x3 = shape((0..<2).flatMap { x in (0..<3).map { y in (x, y) } })
    public static let rect3x2 = shape((0..<3).flatMap { x in (0..<2).map { y in (x, y) } })

    // Küçük köşeler (3 hücre, 4 yön)
    public static let cornerA = shape([(0, 0), (1, 0), (0, 1)])
    public static let cornerB = shape([(0, 0), (1, 0), (1, 1)])
    public static let cornerC = shape([(0, 0), (0, 1), (1, 1)])
    public static let cornerD = shape([(1, 0), (0, 1), (1, 1)])

    // Büyük L köşeler (5 hücre, 4 yön)
    public static let bigLA = shape([(0, 0), (1, 0), (2, 0), (0, 1), (0, 2)])
    public static let bigLB = shape([(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)])
    public static let bigLC = shape([(0, 2), (1, 2), (2, 2), (0, 0), (0, 1)])
    public static let bigLD = shape([(2, 0), (2, 1), (0, 2), (1, 2), (2, 2)])

    // Zikzak S/Z (4 hücre, 4 yön)
    public static let sH = shape([(1, 0), (2, 0), (0, 1), (1, 1)])
    public static let sV = shape([(0, 0), (0, 1), (1, 1), (1, 2)])
    public static let zH = shape([(0, 0), (1, 0), (1, 1), (2, 1)])
    public static let zV = shape([(1, 0), (0, 1), (1, 1), (0, 2)])

    // Artı (5 hücre)
    public static let plus = shape([(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)])

    // T şekilleri (4 hücre, 4 yön)
    public static let tA = shape([(0, 1), (1, 1), (2, 1), (1, 0)])
    public static let tB = shape([(0, 0), (1, 0), (2, 0), (1, 1)])
    public static let tC = shape([(0, 0), (0, 1), (0, 2), (1, 1)])
    public static let tD = shape([(1, 0), (1, 1), (1, 2), (0, 1)])

    public static let allShapes: [PieceShape] = [
        single,
        line2H, line2V, line3H, line3V, line4H, line4V, line5H, line5V,
        square2, square3, rect2x3, rect3x2,
        cornerA, cornerB, cornerC, cornerD,
        bigLA, bigLB, bigLC, bigLD,
        tA, tB, tC, tD,
        sH, sV, zH, zV,
        plus
    ]

    /// Parçaların geometrik eşleri: birlikte temiz dolgu yaparlar.
    /// (Büyük L + 2x2 = 3x3; 5'li + 3'lü çizgi = tam 8'lik satır; iki T = 4x2;
    /// köşe + ters köşe = 2x3 dikdörtgen.)
    private static let complements: [PieceShape: PieceShape] = [
        line3H: line5H, line3V: line5V,
        line5H: line3H, line5V: line3V,
        line4H: line4H, line4V: line4V,
        square2: square2,
        square3: line5H,
        rect2x3: rect2x3, rect3x2: rect3x2,
        cornerA: cornerD, cornerD: cornerA,
        cornerB: cornerC, cornerC: cornerB,
        bigLA: square2, bigLB: square2, bigLC: square2, bigLD: square2,
        tA: tB, tB: tA, tC: tD, tD: tC
    ]

    public static func complement(of shape: PieceShape) -> PieceShape? {
        complements[shape]
    }
}
