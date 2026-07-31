import XCTest
@testable import GameCore

final class GameEngineTests: XCTestCase {
    private let single = PieceCatalog.single

    /// 2. satırda tek hücre eksik bir tahta hazırlar.
    private func boardWithAlmostFullRow(missingX: Int = 7, y: Int = 2) -> GameBoard {
        var board = GameBoard()
        for x in 0..<8 where x != missingX {
            board[GridPoint(x: x, y: y)] = 0
        }
        return board
    }

    func testInitialHandHasThreePieces() {
        let engine = GameEngine(seed: 42)
        XCTAssertEqual(engine.hand.compactMap { $0 }.count, 3)
        XCTAssertFalse(engine.isGameOver)
        XCTAssertEqual(engine.score, 0)
    }

    func testPlacementConsumesPieceAndScoresCells() {
        let board = GameBoard()
        let piece = Piece(shape: single, colorIndex: 0)
        let engine = GameEngine(board: board, hand: [piece, piece, piece])

        let outcome = engine.place(handIndex: 0, at: GridPoint(x: 0, y: 0))
        XCTAssertNotNil(outcome)
        XCTAssertEqual(outcome?.placementPoints, 10)
        XCTAssertEqual(outcome?.clearPoints, 0)
        XCTAssertEqual(engine.score, 10)
        XCTAssertNil(engine.hand[0])
    }

    func testIllegalPlacementReturnsNil() {
        let piece = Piece(shape: single, colorIndex: 0)
        var board = GameBoard()
        board[GridPoint(x: 0, y: 0)] = 1
        let engine = GameEngine(board: board, hand: [piece])

        XCTAssertNil(engine.place(handIndex: 0, at: GridPoint(x: 0, y: 0)))
        XCTAssertEqual(engine.score, 0)
        XCTAssertNotNil(engine.hand[0])
    }

    func testRowClearScoring() {
        let board = boardWithAlmostFullRow()
        let piece = Piece(shape: single, colorIndex: 3)
        let engine = GameEngine(board: board, hand: [piece, piece, piece])

        let outcome = engine.place(handIndex: 0, at: GridPoint(x: 7, y: 2))
        XCTAssertEqual(outcome?.clearedLineCount, 1)
        XCTAssertEqual(outcome?.comboStreak, 1)
        // 1 hücre × 10 + 100 * 1² * 1 combo = 110
        XCTAssertEqual(engine.score, 110)
        XCTAssertEqual(outcome?.clearedCells.count, 8)
        XCTAssertTrue(engine.board.isEmpty)
    }

    func testComboStreakMultipliesAndResets() {
        var board = GameBoard()
        // 0. ve 1. satırlar tek hücre eksik
        for x in 0..<7 {
            board[GridPoint(x: x, y: 0)] = 0
            board[GridPoint(x: x, y: 1)] = 0
        }
        let piece = Piece(shape: single, colorIndex: 0)
        let engine = GameEngine(
            board: board,
            hand: [piece, piece, piece],
            difficulty: DifficultyCurve(comboGraceStart: 0, comboGraceEnd: 0)
        )

        // 1. temizleme: streak 1 → 10 + 100*1*1*1 = 110
        engine.place(handIndex: 0, at: GridPoint(x: 7, y: 0))
        XCTAssertEqual(engine.comboStreak, 1)
        XCTAssertEqual(engine.score, 110)

        // 2. temizleme: streak 2 → +10 + 100*1*1*2 = +210
        engine.place(handIndex: 1, at: GridPoint(x: 7, y: 1))
        XCTAssertEqual(engine.comboStreak, 2)
        XCTAssertEqual(engine.score, 320)

        // Temizlemeyen hamle: streak sıfırlanır
        engine.place(handIndex: 2, at: GridPoint(x: 0, y: 5))
        XCTAssertEqual(engine.comboStreak, 0)
        XCTAssertEqual(engine.score, 330)
    }

    func testMultiLineClearBonus() {
        var board = GameBoard()
        // 0. satır ve 0. sütun, kesişimleri (0,0) hariç dolu
        for x in 1..<8 { board[GridPoint(x: x, y: 0)] = 0 }
        for y in 1..<8 { board[GridPoint(x: 0, y: y)] = 0 }
        let piece = Piece(shape: single, colorIndex: 0)
        let engine = GameEngine(board: board, hand: [piece, piece, piece])

        let outcome = engine.place(handIndex: 0, at: GridPoint(x: 0, y: 0))
        XCTAssertEqual(outcome?.clearedLineCount, 2)
        // 10 + 100 * 2² * 1 = 410
        XCTAssertEqual(engine.score, 410)
        // 15 benzersiz hücre temizlendi (8 + 8 - 1 kesişim)
        XCTAssertEqual(outcome?.clearedCells.count, 15)
    }

    func testHandRefillsAfterAllPiecesUsed() {
        let piece = Piece(shape: single, colorIndex: 0)
        let engine = GameEngine(board: GameBoard(), hand: [piece, piece, piece], seed: 7)

        engine.place(handIndex: 0, at: GridPoint(x: 0, y: 0))
        engine.place(handIndex: 1, at: GridPoint(x: 2, y: 0))
        XCTAssertEqual(engine.hand.compactMap { $0 }.count, 1)

        engine.place(handIndex: 2, at: GridPoint(x: 4, y: 0))
        // El tamamen boşaldı → yeniden 3 parça
        XCTAssertEqual(engine.hand.compactMap { $0 }.count, 3)
    }

    func testGameOverWhenNoPieceFits() {
        var board = GameBoard()
        // Satır/sütun tamamlamadan tahtayı damalı şekilde doldur:
        // hiçbir satır/sütun tam değil ama boş hücreler izole
        for y in 0..<8 {
            for x in 0..<8 where (x + y) % 2 == 0 {
                board[GridPoint(x: x, y: y)] = 1
            }
        }
        let square2 = PieceShape([
            GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0),
            GridPoint(x: 0, y: 1), GridPoint(x: 1, y: 1)
        ])
        let bigPiece = Piece(shape: square2, colorIndex: 0)
        let engine = GameEngine(board: board, hand: [bigPiece])
        XCTAssertTrue(engine.isGameOver)
        XCTAssertNil(engine.place(handIndex: 0, at: GridPoint(x: 0, y: 0)))
    }

    func testGameContinuesWhileAnyPieceFits() {
        var board = GameBoard()
        for y in 0..<8 {
            for x in 0..<8 where (x + y) % 2 == 0 {
                board[GridPoint(x: x, y: y)] = 1
            }
        }
        let square2 = PieceShape([
            GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0),
            GridPoint(x: 0, y: 1), GridPoint(x: 1, y: 1)
        ])
        let engine = GameEngine(
            board: board,
            hand: [Piece(shape: square2, colorIndex: 0), Piece(shape: single, colorIndex: 0)]
        )
        XCTAssertFalse(engine.isGameOver)
    }

    func testGeneratorFavorsMediumShapes() {
        var generator = PieceGenerator(seed: 123)
        let cornerShapes: Set<PieceShape> = [
            PieceCatalog.cornerA, PieceCatalog.cornerB,
            PieceCatalog.cornerC, PieceCatalog.cornerD
        ]
        var tiny = 0
        var medium = 0
        var huge = 0
        var corners = 0
        for _ in 0..<1000 {
            let shape = generator.makePiece().shape
            if shape.cellCount <= 2 { tiny += 1 }
            if (4...6).contains(shape.cellCount) { medium += 1 }
            if shape.cellCount >= 9 { huge += 1 }
            if cornerShapes.contains(shape) { corners += 1 }
        }
        // Ağırlıklara göre beklenti: minik ~%8, orta boy ~%63, 3x3 ~%8, köşeler ~%10
        XCTAssertLessThan(tiny, 140, "Minik taşlar nadir olmalı")
        XCTAssertGreaterThan(medium, 500)
        XCTAssertLessThan(huge, 140)
        XCTAssertLessThan(corners, 160, "Köşe parçaları oyunu istila etmemeli")
    }

    func testRefillRescuesUnplayableHand() {
        var board = GameBoard()
        // Yalnızca (0,0), (1,0) ve (0,1) boş; her satır/sütunda 2+ boşluk yok,
        // bu yüzden (0,0)'a koymak hiçbir çizgiyi tamamlamaz
        for y in 0..<8 {
            for x in 0..<8 where !(x == 0 && y == 0) && !(x == 1 && y == 0) && !(x == 0 && y == 1) {
                board[GridPoint(x: x, y: y)] = 1
            }
        }
        let engine = GameEngine(
            board: board,
            hand: [Piece(shape: single, colorIndex: 0)],
            seed: 42
        )
        engine.place(handIndex: 0, at: GridPoint(x: 0, y: 0))

        // Kalan boşluklara ((1,0) ve (0,1)) yalnızca tek blok sığar;
        // garanti mekanizması ele sığan bir parça koymuş olmalı
        XCTAssertFalse(engine.isGameOver)
        XCTAssertTrue(
            engine.hand.compactMap { $0 }.contains { engine.board.canPlaceAnywhere($0.shape) }
        )
    }

    func testComboHelperInjectedWhenChanceIsCertain() {
        var board = GameBoard()
        // 0. satırda tek hücre eksik (7,0); tahtanın geri kalanı boş
        for x in 0..<7 {
            board[GridPoint(x: x, y: 0)] = 0
        }
        let engine = GameEngine(
            board: board,
            hand: [Piece(shape: single, colorIndex: 0)],
            difficulty: DifficultyCurve(comboHelperStart: 1, comboHelperEnd: 1),
            seed: 5
        )
        // Nötr bir yere koy: hiçbir çizgi tamamlanmasın, el yenilensin
        engine.place(handIndex: 0, at: GridPoint(x: 3, y: 5))

        // %100 şansla yenilenen elde çizgi tamamlayabilen bir parça olmalı
        XCTAssertTrue(
            engine.hand.compactMap { $0 }.contains { engine.board.canCompleteLine(with: $0.shape) }
        )
    }

    func testComboHelperDisabledWithZeroChance() {
        let engine = GameEngine(difficulty: DifficultyCurve(comboHelperStart: 0, comboHelperEnd: 0), seed: 11)
        XCTAssertEqual(engine.hand.compactMap { $0 }.count, 3)
        XCTAssertFalse(engine.isGameOver)
    }

    /// Regresyon: uyum mekaniği, eldeki tek oynanabilir parçanın üzerine
    /// sığmayan bir eş yazıp oyunu haksız yere bitiriyordu.
    func testRefillNeverEndsGameWhileMovesExist() {
        // Dama deseni: boş hücreler izole, yalnızca tek bloklu parça sığar
        var checkerboard = GameBoard()
        for y in 0..<8 {
            for x in 0..<8 where (x + y) % 2 == 0 {
                checkerboard[GridPoint(x: x, y: y)] = 1
            }
        }

        for seed in 0..<60 {
            let engine = GameEngine(
                board: checkerboard,
                hand: (0..<3).map { _ in Piece(shape: single, colorIndex: 0) },
                seed: UInt64(seed)
            )
            // Üç tek bloğu izole boşluklara koy; hiçbir çizgi tamamlanmaz,
            // sonra el yenilenir
            engine.place(handIndex: 0, at: GridPoint(x: 1, y: 0))
            engine.place(handIndex: 1, at: GridPoint(x: 3, y: 0))
            engine.place(handIndex: 2, at: GridPoint(x: 5, y: 0))

            XCTAssertFalse(
                engine.isGameOver,
                "Seed \(seed): tahtada 29 boş hücre varken oyun bitti"
            )
            XCTAssertTrue(
                engine.hand.compactMap { $0 }.contains { engine.board.canPlaceAnywhere($0.shape) },
                "Seed \(seed): yenilenen elde oynanabilir parça yok"
            )
        }
    }

    func testHarmonySkippedWhenPartnerDoesNotFit() {
        // Tahtada yalnızca tek hücreler boş: hiçbir eş sığmaz, uyum atlanmalı
        var board = GameBoard()
        for y in 0..<8 {
            for x in 0..<8 where (x + y) % 2 == 0 {
                board[GridPoint(x: x, y: y)] = 1
            }
        }
        let engine = GameEngine(
            board: board,
            hand: (0..<3).map { _ in Piece(shape: single, colorIndex: 0) },
            seed: 1
        )
        engine.place(handIndex: 0, at: GridPoint(x: 1, y: 0))
        engine.place(handIndex: 1, at: GridPoint(x: 3, y: 0))
        engine.place(handIndex: 2, at: GridPoint(x: 5, y: 0))

        // Elde en az bir tek bloklu (sığan) parça bulunmalı
        XCTAssertTrue(engine.hand.compactMap { $0 }.contains { $0.shape.cellCount == 1 })
    }

    func testCanPlaceAnywhereRejectsOversizedShape() {
        let board = GameBoard(size: 4)
        let line5 = PieceShape((0..<5).map { GridPoint(x: $0, y: 0) })
        XCTAssertFalse(board.canPlaceAnywhere(line5))
    }

    func testHandColorsAreDistinct() {
        for seed in 0..<60 {
            let engine = GameEngine(seed: UInt64(seed))
            let colors = engine.hand.compactMap { $0?.colorIndex }
            XCTAssertEqual(colors.count, 3)
            XCTAssertEqual(
                Set(colors).count, colors.count,
                "Seed \(seed): elde tekrar eden renk var → \(colors)"
            )
        }
    }

    /// Uyum ve kombo yardımcısı yalnızca şekli değiştirmeli, rengi değil.
    func testHelperMechanicsKeepColorsDistinct() {
        for seed in 0..<60 {
            let engine = GameEngine(
                difficulty: DifficultyCurve(comboHelperStart: 1, comboHelperEnd: 1),
                seed: UInt64(seed)
            )
            // Eli tüket, yenilensin
            var guardCounter = 0
            while engine.hand.contains(where: { $0 != nil }), guardCounter < 12 {
                guardCounter += 1
                guard let index = engine.hand.firstIndex(where: { $0 != nil }),
                      let piece = engine.hand[index] else { break }
                var placed = false
                outer: for y in 0..<engine.board.size {
                    for x in 0..<engine.board.size {
                        if engine.place(handIndex: index, at: GridPoint(x: x, y: y)) != nil {
                            placed = true
                            break outer
                        }
                    }
                }
                if !placed { _ = piece; break }
            }

            let colors = engine.hand.compactMap { $0?.colorIndex }
            XCTAssertEqual(
                Set(colors).count, colors.count,
                "Seed \(seed): yenilenen elde tekrar eden renk var → \(colors)"
            )
        }
    }

    /// Kombo affı: oyunun başında seri, patlatmayan hamlelerde hemen kırılmaz.
    func testComboGraceKeepsStreakAlive() {
        var board = GameBoard()
        // 0. ve 1. satırlar tek hücre eksik
        for x in 0..<7 {
            board[GridPoint(x: x, y: 0)] = 0
            board[GridPoint(x: x, y: 1)] = 0
        }
        let piece = Piece(shape: single, colorIndex: 0)
        let engine = GameEngine(
            board: board,
            hand: [piece, piece, piece],
            difficulty: DifficultyCurve(comboGraceStart: 2, comboGraceEnd: 2)
        )

        engine.place(handIndex: 0, at: GridPoint(x: 7, y: 0))
        XCTAssertEqual(engine.comboStreak, 1)

        // Patlatmayan hamle: af sayesinde seri korunur
        engine.place(handIndex: 1, at: GridPoint(x: 3, y: 5))
        XCTAssertEqual(engine.comboStreak, 1, "Af varken seri tek boş hamlede kırılmamalı")

        // Sonraki patlatma seriyi 2'ye çıkarır: 10 + 100 * 1² * 2 = 210
        let outcome = engine.place(handIndex: 2, at: GridPoint(x: 7, y: 1))
        XCTAssertEqual(engine.comboStreak, 2)
        XCTAssertEqual(outcome?.clearPoints, 200)
    }

    func testComboGraceExpiresAfterLimit() {
        var board = GameBoard()
        for x in 0..<7 { board[GridPoint(x: x, y: 0)] = 0 }
        let piece = Piece(shape: single, colorIndex: 0)
        let engine = GameEngine(
            board: board,
            hand: Array(repeating: Piece(shape: single, colorIndex: 0), count: 4),
            difficulty: DifficultyCurve(comboGraceStart: 1, comboGraceEnd: 1)
        )
        _ = piece

        engine.place(handIndex: 0, at: GridPoint(x: 7, y: 0))
        XCTAssertEqual(engine.comboStreak, 1)

        engine.place(handIndex: 1, at: GridPoint(x: 2, y: 5))   // 1. boş hamle: affedilir
        XCTAssertEqual(engine.comboStreak, 1)

        engine.place(handIndex: 2, at: GridPoint(x: 4, y: 5))   // 2. boş hamle: af biter
        XCTAssertEqual(engine.comboStreak, 0)
    }

    func testComplementMapping() {
        XCTAssertEqual(PieceCatalog.complement(of: PieceCatalog.line5H), PieceCatalog.line3H)
        XCTAssertEqual(PieceCatalog.complement(of: PieceCatalog.line3H), PieceCatalog.line5H)
        XCTAssertEqual(PieceCatalog.complement(of: PieceCatalog.bigLA), PieceCatalog.square2)
        XCTAssertEqual(PieceCatalog.complement(of: PieceCatalog.tA), PieceCatalog.tB)
        XCTAssertEqual(PieceCatalog.complement(of: PieceCatalog.cornerA), PieceCatalog.cornerD)
        XCTAssertEqual(PieceCatalog.complement(of: PieceCatalog.cornerB), PieceCatalog.cornerC)
        XCTAssertNil(PieceCatalog.complement(of: PieceCatalog.single))
        XCTAssertNil(PieceCatalog.complement(of: PieceCatalog.line2H))
    }

    func testHarmonyPutsComplementInHand() {
        // %100 uyum şansıyla: elde eşleşebilir parça varsa, elde en az bir
        // tamamlayıcı çift bulunmalı. Board boş olduğundan kombo yardımcısı
        // devreye girmez ve eli bozamaz.
        for seed in 0..<40 {
            let engine = GameEngine(seed: UInt64(seed))
            let shapes = engine.hand.compactMap { $0?.shape }
            guard shapes.contains(where: {
                $0.cellCount >= 3 && PieceCatalog.complement(of: $0) != nil
            }) else { continue }

            let hasPair = shapes.indices.contains { i in
                shapes.indices.contains { j in
                    i != j && PieceCatalog.complement(of: shapes[i]) == shapes[j]
                }
            }
            XCTAssertTrue(hasPair, "Seed \(seed): elde tamamlayıcı çift yok")
        }
    }

    func testSeededEngineIsDeterministic() {
        let a = GameEngine(seed: 99)
        let b = GameEngine(seed: 99)
        XCTAssertEqual(a.hand.compactMap { $0?.shape }, b.hand.compactMap { $0?.shape })
        XCTAssertEqual(a.hand.compactMap { $0?.colorIndex }, b.hand.compactMap { $0?.colorIndex })
    }
}
