import Foundation

/// 8x8 (veya istenen boyutta) oyun tahtası. Her hücre ya boş (nil) ya da bir renk indeksi tutar.
/// Saf değer tipi: render veya UI bilgisi içermez.
public struct GameBoard: Equatable {
    public static let defaultSize = 8

    public let size: Int
    private var cells: [Int?]

    public init(size: Int = GameBoard.defaultSize) {
        precondition(size > 0)
        self.size = size
        self.cells = Array(repeating: nil, count: size * size)
    }

    public subscript(point: GridPoint) -> Int? {
        get { cells[point.y * size + point.x] }
        set { cells[point.y * size + point.x] = newValue }
    }

    public func cell(x: Int, y: Int) -> Int? {
        cells[y * size + x]
    }

    public func contains(_ point: GridPoint) -> Bool {
        point.x >= 0 && point.x < size && point.y >= 0 && point.y < size
    }

    public var occupiedCells: [(point: GridPoint, colorIndex: Int)] {
        var result: [(GridPoint, Int)] = []
        for y in 0..<size {
            for x in 0..<size {
                if let color = cell(x: x, y: y) {
                    result.append((GridPoint(x: x, y: y), color))
                }
            }
        }
        return result
    }

    public var isEmpty: Bool { cells.allSatisfy { $0 == nil } }

    // MARK: - Yerleştirme

    public func canPlace(_ shape: PieceShape, at origin: GridPoint) -> Bool {
        for cell in shape.cells {
            let target = GridPoint(x: origin.x + cell.x, y: origin.y + cell.y)
            guard contains(target), self[target] == nil else { return false }
        }
        return true
    }

    /// Parçayı yerleştirir; geçersizse false döner ve tahta değişmez.
    @discardableResult
    public mutating func place(_ piece: Piece, at origin: GridPoint) -> Bool {
        guard canPlace(piece.shape, at: origin) else { return false }
        for cell in piece.shape.cells {
            self[GridPoint(x: origin.x + cell.x, y: origin.y + cell.y)] = piece.colorIndex
        }
        return true
    }

    /// Bu şekil bu noktaya konursa hangi satır/sütunlar tamamlanır.
    /// Yerleştirme geçersizse boş döner. UI'ın "patlayacak bloklar" önizlemesi için.
    public func linesCompleted(byPlacing shape: PieceShape, at origin: GridPoint) -> (rows: [Int], columns: [Int]) {
        guard canPlace(shape, at: origin) else { return ([], []) }
        var preview = self
        preview.place(Piece(shape: shape, colorIndex: 0), at: origin)
        return (preview.completedRows(), preview.completedColumns())
    }

    /// Bu şeklin, tahtanın herhangi bir yerinde en az bir çizgi tamamlayan
    /// bir yerleşimi var mı? (Kombo yardımcısı mekaniği için.)
    public func canCompleteLine(with shape: PieceShape) -> Bool {
        guard shape.width <= size, shape.height <= size else { return false }
        for y in 0...(size - shape.height) {
            for x in 0...(size - shape.width) {
                let origin = GridPoint(x: x, y: y)
                guard canPlace(shape, at: origin) else { continue }
                let lines = linesCompleted(byPlacing: shape, at: origin)
                if !lines.rows.isEmpty || !lines.columns.isEmpty { return true }
            }
        }
        return false
    }

    public func canPlaceAnywhere(_ shape: PieceShape) -> Bool {
        guard shape.width <= size, shape.height <= size else { return false }
        for y in 0...(size - shape.height) {
            for x in 0...(size - shape.width) {
                if canPlace(shape, at: GridPoint(x: x, y: y)) { return true }
            }
        }
        return false
    }

    // MARK: - Satır/sütun temizleme

    public func completedRows() -> [Int] {
        (0..<size).filter { y in (0..<size).allSatisfy { x in cell(x: x, y: y) != nil } }
    }

    public func completedColumns() -> [Int] {
        (0..<size).filter { x in (0..<size).allSatisfy { y in cell(x: x, y: y) != nil } }
    }

    public mutating func clear(rows: [Int], columns: [Int]) {
        for y in rows {
            for x in 0..<size {
                self[GridPoint(x: x, y: y)] = nil
            }
        }
        for x in columns {
            for y in 0..<size {
                self[GridPoint(x: x, y: y)] = nil
            }
        }
    }
}
