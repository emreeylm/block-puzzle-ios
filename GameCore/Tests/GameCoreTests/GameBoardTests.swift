import XCTest
@testable import GameCore

final class GameBoardTests: XCTestCase {
    private func piece(_ shape: PieceShape, color: Int = 0) -> Piece {
        Piece(shape: shape, colorIndex: color)
    }

    func testEmptyBoardAllowsPlacement() {
        let board = GameBoard()
        XCTAssertTrue(board.canPlace(PieceCatalog.single, at: GridPoint(x: 0, y: 0)))
        XCTAssertTrue(board.canPlace(PieceCatalog.single, at: GridPoint(x: 7, y: 7)))
    }

    func testPlacementOutOfBoundsRejected() {
        let board = GameBoard()
        let line3 = PieceShape([GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0), GridPoint(x: 2, y: 0)])
        XCTAssertFalse(board.canPlace(line3, at: GridPoint(x: 6, y: 0)))
        XCTAssertFalse(board.canPlace(PieceCatalog.single, at: GridPoint(x: 8, y: 0)))
        XCTAssertFalse(board.canPlace(PieceCatalog.single, at: GridPoint(x: -1, y: 0)))
    }

    func testOverlapRejected() {
        var board = GameBoard()
        XCTAssertTrue(board.place(piece(PieceCatalog.single), at: GridPoint(x: 3, y: 3)))
        XCTAssertFalse(board.canPlace(PieceCatalog.single, at: GridPoint(x: 3, y: 3)))
    }

    func testPlaceStoresColorIndex() {
        var board = GameBoard()
        board.place(piece(PieceCatalog.single, color: 4), at: GridPoint(x: 2, y: 5))
        XCTAssertEqual(board[GridPoint(x: 2, y: 5)], 4)
    }

    func testCompletedRowDetection() {
        var board = GameBoard()
        for x in 0..<8 {
            board.place(piece(PieceCatalog.single), at: GridPoint(x: x, y: 2))
        }
        XCTAssertEqual(board.completedRows(), [2])
        XCTAssertEqual(board.completedColumns(), [])
    }

    func testCompletedColumnDetection() {
        var board = GameBoard()
        for y in 0..<8 {
            board.place(piece(PieceCatalog.single), at: GridPoint(x: 5, y: y))
        }
        XCTAssertEqual(board.completedColumns(), [5])
        XCTAssertEqual(board.completedRows(), [])
    }

    func testClearRemovesCells() {
        var board = GameBoard()
        for x in 0..<8 {
            board.place(piece(PieceCatalog.single), at: GridPoint(x: x, y: 0))
        }
        board.clear(rows: [0], columns: [])
        XCTAssertTrue(board.isEmpty)
    }

    func testSimultaneousRowAndColumnClear() {
        var board = GameBoard()
        // 0. satırı ve 0. sütunu doldur (kesişim tek hücre)
        for x in 0..<8 { board.place(piece(PieceCatalog.single), at: GridPoint(x: x, y: 0)) }
        for y in 1..<8 { board.place(piece(PieceCatalog.single), at: GridPoint(x: 0, y: y)) }
        XCTAssertEqual(board.completedRows(), [0])
        XCTAssertEqual(board.completedColumns(), [0])
        board.clear(rows: [0], columns: [0])
        XCTAssertTrue(board.isEmpty)
    }

    func testCanPlaceAnywhereFalseWhenNoRoom() {
        var board = GameBoard()
        // Tahtayı tamamen doldur ama satır/sütun temizlenmeden test edebilmek
        // için doğrudan hücrelere yaz
        for y in 0..<8 {
            for x in 0..<8 {
                board[GridPoint(x: x, y: y)] = 1
            }
        }
        XCTAssertFalse(board.canPlaceAnywhere(PieceCatalog.single))
    }

    func testCanPlaceAnywhereForBigPieceOnCrowdedBoard() {
        var board = GameBoard()
        // Yalnızca sol üst 3x3 boş kalsın
        for y in 0..<8 {
            for x in 0..<8 where !(x < 3 && y < 3) {
                board[GridPoint(x: x, y: y)] = 1
            }
        }
        let square3 = PieceShape((0..<3).flatMap { x in (0..<3).map { y in GridPoint(x: x, y: y) } })
        XCTAssertTrue(board.canPlaceAnywhere(square3))
        let line4 = PieceShape((0..<4).map { GridPoint(x: $0, y: 0) })
        XCTAssertFalse(board.canPlaceAnywhere(line4))
    }

    func testLinesCompletedPreview() {
        var board = GameBoard()
        // 3. satırda son iki hücre eksik
        for x in 0..<6 {
            board[GridPoint(x: x, y: 3)] = 0
        }
        let line2 = PieceShape([GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0)])

        let completing = board.linesCompleted(byPlacing: line2, at: GridPoint(x: 6, y: 3))
        XCTAssertEqual(completing.rows, [3])
        XCTAssertEqual(completing.columns, [])

        let notCompleting = board.linesCompleted(byPlacing: line2, at: GridPoint(x: 0, y: 5))
        XCTAssertEqual(notCompleting.rows, [])

        // Geçersiz yerleştirme (taşma) boş dönmeli
        let invalid = board.linesCompleted(byPlacing: line2, at: GridPoint(x: 7, y: 3))
        XCTAssertEqual(invalid.rows, [])
        // Tahta değişmemiş olmalı
        XCTAssertEqual(board.completedRows(), [])
    }

    func testCanCompleteLine() {
        var board = GameBoard()
        // 4. satırda tek hücre eksik
        for x in 0..<7 {
            board[GridPoint(x: x, y: 4)] = 0
        }
        XCTAssertTrue(board.canCompleteLine(with: PieceCatalog.single))

        let line2 = PieceShape([GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0)])
        // Yatay 2'li satıra sığmaz (tek boşluk var) ama dikey konumda da
        // hiçbir çizgi tamamlayamaz
        XCTAssertFalse(GameBoard().canCompleteLine(with: line2))
        XCTAssertFalse(GameBoard().canCompleteLine(with: PieceCatalog.single))
    }

    func testShapeNormalization() {
        let shifted = PieceShape([GridPoint(x: 3, y: 4), GridPoint(x: 4, y: 4)])
        XCTAssertEqual(shifted.cells, [GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0)])
        XCTAssertEqual(shifted.width, 2)
        XCTAssertEqual(shifted.height, 1)
    }
}
