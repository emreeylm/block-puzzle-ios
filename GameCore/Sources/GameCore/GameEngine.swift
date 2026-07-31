import Foundation

/// Temizlenen bir hücre: animasyon için konum + rengin ne olduğu.
public struct ClearedCell: Hashable {
    public let point: GridPoint
    public let colorIndex: Int

    public init(point: GridPoint, colorIndex: Int) {
        self.point = point
        self.colorIndex = colorIndex
    }
}

/// Tek bir yerleştirmenin sonucu.
public struct PlacementOutcome: Equatable {
    public let placementPoints: Int
    public let clearPoints: Int
    public let clearedLineCount: Int
    public let clearedCells: [ClearedCell]
    public let comboStreak: Int

    public var totalPoints: Int { placementPoints + clearPoints }
}

/// Bir oyun oturumunun tamamı: tahta, eldeki parçalar, skor, combo, oyun sonu.
/// UI'dan tamamen bağımsızdır; SpriteKit/SwiftUI bu sınıfı yalnızca çağırır ve okur.
public final class GameEngine {
    public private(set) var board: GameBoard
    public private(set) var hand: [Piece?]
    public private(set) var score = 0
    public private(set) var comboStreak = 0
    public private(set) var isGameOver = false
    /// Yerleştirilen toplam parça sayısı. Zorluk ilerlemesi buna bağlıdır.
    public private(set) var placementCount = 0

    public let handSize: Int
    public let colorCount: Int
    /// Zorluk eğrisi: skor arttıkça yardımcı mekanikler kısılır, parçalar sertleşir.
    public let difficulty: DifficultyCurve

    /// Yerleştirme puanı: hücre başına `placementPointsPerCell`.
    /// Temizleme puanı: `lineClearBase * satırSayısı² * comboSerisi`.
    private static let placementPointsPerCell = 10
    private static let lineClearBase = 100

    private var generator: PieceGenerator

    /// 0 = oyunun başı (kolay), 1 = tam zorluk. UI göstergesi için de kullanılabilir.
    public var difficultyProgress: Double {
        difficulty.progress(forMoves: placementCount)
    }

    /// Her el yenilenmesinde, ele "çizgi tamamlayabilen" bir parça koyma olasılığı.
    /// Kombo zincirlerini besleyen gizli cömertlik mekaniği; oyun ilerledikçe azalır.
    public var comboHelperChance: Double {
        difficulty.comboHelperChance(at: difficultyProgress)
    }

    /// Elde büyük bir parça varken, aynı ele onun geometrik eşini koyma olasılığı
    /// (büyük L yanında 2x2, 5'li çizgi yanında 3'lü çizgi gibi). İlerledikçe azalır.
    public var harmonyChance: Double {
        difficulty.harmonyChance(at: difficultyProgress)
    }

    public init(
        boardSize: Int = GameBoard.defaultSize,
        handSize: Int = 3,
        colorCount: Int = PieceGenerator.defaultColorCount,
        difficulty: DifficultyCurve = .standard,
        seed: UInt64? = nil
    ) {
        self.board = GameBoard(size: boardSize)
        self.handSize = handSize
        self.colorCount = colorCount
        self.difficulty = difficulty
        self.generator = PieceGenerator(seed: seed)
        self.hand = []
        refillHand()
        updateGameOver()
    }

    /// Test kancası: belirli bir tahta ve el ile başlat.
    init(
        board: GameBoard,
        hand: [Piece?],
        colorCount: Int = PieceGenerator.defaultColorCount,
        difficulty: DifficultyCurve = .standard,
        seed: UInt64? = nil
    ) {
        self.board = board
        self.hand = hand
        self.handSize = hand.count
        self.colorCount = colorCount
        self.difficulty = difficulty
        self.generator = PieceGenerator(seed: seed)
        updateGameOver()
    }


    public func canPlace(handIndex: Int, at origin: GridPoint) -> Bool {
        guard !isGameOver, hand.indices.contains(handIndex), let piece = hand[handIndex] else { return false }
        return board.canPlace(piece.shape, at: origin)
    }

    /// Eldeki parçayı tahtaya yerleştirir. Geçersiz hamlede nil döner.
    @discardableResult
    public func place(handIndex: Int, at origin: GridPoint) -> PlacementOutcome? {
        guard !isGameOver,
              hand.indices.contains(handIndex),
              let piece = hand[handIndex],
              board.canPlace(piece.shape, at: origin) else { return nil }

        board.place(piece, at: origin)

        let rows = board.completedRows()
        let columns = board.completedColumns()
        var cleared: [ClearedCell] = []
        var seen = Set<GridPoint>()
        for y in rows {
            for x in 0..<board.size {
                let p = GridPoint(x: x, y: y)
                if seen.insert(p).inserted, let color = board[p] {
                    cleared.append(ClearedCell(point: p, colorIndex: color))
                }
            }
        }
        for x in columns {
            for y in 0..<board.size {
                let p = GridPoint(x: x, y: y)
                if seen.insert(p).inserted, let color = board[p] {
                    cleared.append(ClearedCell(point: p, colorIndex: color))
                }
            }
        }
        board.clear(rows: rows, columns: columns)

        let lineCount = rows.count + columns.count
        comboStreak = lineCount > 0 ? comboStreak + 1 : 0
        placementCount += 1

        let placementPoints = piece.shape.cellCount * GameEngine.placementPointsPerCell
        let clearPoints = lineCount > 0
            ? GameEngine.lineClearBase * lineCount * lineCount * max(comboStreak, 1)
            : 0
        score += placementPoints + clearPoints

        hand[handIndex] = nil
        if hand.allSatisfy({ $0 == nil }) {
            refillHand()
        }
        updateGameOver()

        return PlacementOutcome(
            placementPoints: placementPoints,
            clearPoints: clearPoints,
            clearedLineCount: lineCount,
            clearedCells: cleared,
            comboStreak: comboStreak
        )
    }

    /// Sığmayan el yüzünden haksız oyun sonu yaşanmaması için yeniden deneme sayısı.
    private static let refillAttempts = 6

    private func refillHand() {
        let progress = difficultyProgress
        let hardMultiplier = difficulty.hardShapeMultiplier(at: progress)

        // Zorluk eğrisinin verdiği hedefler sırayla denenir: oyunun başında
        // üç parçanın da sığması aranır, ilerledikçe garanti gevşer.
        var candidate: [Piece] = []
        var found = false
        search: for minimumPlayable in difficulty.handGuaranteeTargets(at: progress) {
            for _ in 0..<GameEngine.refillAttempts {
                candidate = generator.makeHand(
                    count: handSize,
                    colorCount: colorCount,
                    hardShapeMultiplier: hardMultiplier
                )
                let playable = candidate.filter { board.canPlaceAnywhere($0.shape) }.count
                if playable >= min(minimumPlayable, handSize) {
                    found = true
                    break search
                }
            }
        }

        // Hâlâ sığan yoksa: kataloğdaki sığabilen en küçük şekli ilk yuvaya koy.
        // Hiçbir şekil sığmıyorsa el olduğu gibi kalır ve oyun meşru şekilde biter.
        if !found,
           let rescue = PieceCatalog.allShapes
            .sorted(by: { $0.cellCount < $1.cellCount })
            .first(where: { board.canPlaceAnywhere($0) }),
           !candidate.isEmpty {
            candidate[0] = Piece(shape: rescue, colorIndex: candidate[0].colorIndex)
        }

        harmonizeHand(&candidate)
        injectComboHelperIfLucky(into: &candidate)
        hand = candidate.map { Optional($0) }
    }

    /// Elde tamamlayıcısı tanımlı bir parça (>= 3 hücre) varsa, şans tutarsa
    /// başka bir yuvaya onun geometrik eşini koyar. Yalnızca şekil değişir;
    /// yuvanın rengi korunur ki eldeki renkler tekrarsız kalsın.
    private func harmonizeHand(_ candidate: inout [Piece]) {
        let eligible = candidate.indices.filter {
            candidate[$0].shape.cellCount >= 3 &&
            PieceCatalog.complement(of: candidate[$0].shape) != nil
        }
        guard candidate.count >= 2,
              harmonyChance > 0,
              generator.chance(harmonyChance),
              // Eldeki en büyük eşleşebilir parçayı eşle (köşe ancak elde
              // daha büyük parça yokken eşlenir)
              let bigIndex = eligible.max(by: {
                  candidate[$0].shape.cellCount < candidate[$1].shape.cellCount
              }),
              let partner = PieceCatalog.complement(of: candidate[bigIndex].shape)
        else { return }

        // Eş zaten eldeyse dokunma
        guard !candidate.enumerated().contains(where: { $0.offset != bigIndex && $0.element.shape == partner }) else { return }

        // Eş tahtaya sığmıyorsa uyum uygulanmaz. Aksi halde eldeki tek
        // oynanabilir parçanın (ya da kurtarma parçasının) üzerine yazıp
        // oyunu haksız yere bitirebilir.
        guard board.canPlaceAnywhere(partner) else { return }

        var otherSlots = Array(candidate.indices)
        otherSlots.remove(at: bigIndex)
        let target = otherSlots[generator.index(upTo: otherSlots.count)]
        candidate[target] = Piece(shape: partner, colorIndex: candidate[target].colorIndex)
    }

    /// Şans tutarsa (comboHelperChance) ve elde zaten yoksa, ele mevcut tahtada
    /// bir çizgiyi tamamlayabilecek bir parça koyar.
    private func injectComboHelperIfLucky(into candidate: inout [Piece]) {
        guard !candidate.isEmpty,
              comboHelperChance > 0,
              generator.chance(comboHelperChance),
              !candidate.contains(where: { board.canCompleteLine(with: $0.shape) })
        else { return }

        let helpers = PieceCatalog.allShapes.filter { board.canCompleteLine(with: $0) }
        guard let shape = generator.pick(helpers) else { return }

        let slot = generator.index(upTo: candidate.count)
        candidate[slot] = Piece(shape: shape, colorIndex: candidate[slot].colorIndex)
    }

    private func updateGameOver() {
        let remaining = hand.compactMap { $0 }
        isGameOver = !remaining.isEmpty && !remaining.contains { board.canPlaceAnywhere($0.shape) }
    }
}
