import SpriteKit
import UIKit
import GameCore

/// Oyun sahnesi: tahtayı ve eldeki parçaları çizer, sürükle-bırak ile
/// yerleştirmeyi yönetir. Tüm oyun kararları AppModel/GameEngine'e sorulur;
/// bu sınıf yalnızca görselleştirir.
final class GameScene: SKScene {
    private unowned let model: AppModel
    private let theme: SkinTheme

    /// Sarsıntı efekti için tüm oyun katmanlarını taşıyan kapsayıcı.
    private let contentLayer = SKNode()
    private let frameLayer = SKNode()
    private let gridLayer = SKNode()
    private let blocksLayer = SKNode()
    private let ghostLayer = SKNode()
    private let trayLayer = SKNode()
    private let effectsLayer = SKNode()
    private var layersAttached = false

    private var cellSize: CGFloat = 0
    private var boardOrigin = CGPoint.zero
    private var trayPieceNodes: [Int: SKNode] = [:]
    private var boardBlockNodes: [GridPoint: SKSpriteNode] = [:]
    private var previewedPoints: [GridPoint] = []

    private struct DragState {
        let handIndex: Int
        let node: SKNode
        let delta: CGPoint
        let homePosition: CGPoint
        let homeScale: CGFloat
    }

    private var drag: DragState?
    private var backgroundNode: SKSpriteNode?
    private var lastGhostOrigin: GridPoint?
    private var blockTextureCache: [Int: SKTexture] = [:]
    private var highlightTextureCache: [Int: SKTexture] = [:]

    /// Patlayacak satır önizlemesinde bloğun kendi renginin ne kadar açılacağı
    /// ve nabız animasyonunun anahtarı.
    private static let previewLighten: CGFloat = 0.45
    private static let previewPulseKey = "previewPulse"

    private let placeHaptic = UIImpactFeedbackGenerator(style: .light)
    private let clearHaptic = UIImpactFeedbackGenerator(style: .heavy)

    init(model: AppModel) {
        self.model = model
        self.theme = SkinTheme(model.activeSkin)
        super.init(size: CGSize(width: 390, height: 600))
        scaleMode = .resizeFill
        anchorPoint = .zero
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        backgroundColor = theme.outerBackground
        if !layersAttached {
            layersAttached = true
            frameLayer.zPosition = 0
            gridLayer.zPosition = 1
            blocksLayer.zPosition = 2
            ghostLayer.zPosition = 3
            trayLayer.zPosition = 4
            effectsLayer.zPosition = 10
            [frameLayer, gridLayer, blocksLayer, ghostLayer, trayLayer, effectsLayer]
                .forEach(contentLayer.addChild)
            addChild(contentLayer)
        }
        rebuildAll()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard view != nil, size.width > 0, size.height > 0 else { return }
        rebuildAll()
    }

    // MARK: - Yerleşim

    private var boardSize: Int { model.engine.board.size }

    private func rebuildAll() {
        let n = CGFloat(boardSize)
        cellSize = min((size.width - 40) / n, (size.height * 0.62) / n)
        let boardSide = cellSize * n
        boardOrigin = CGPoint(
            x: (size.width - boardSide) / 2,
            y: size.height - boardSide - 16
        )
        drag = nil
        lastGhostOrigin = nil
        ghostLayer.removeAllChildren()
        effectsLayer.removeAllChildren()
        buildBackground()
        buildFrame(boardSide: boardSide)
        buildGrid()
        renderBoard()
        renderTray()
    }

    private func cellCenter(_ point: GridPoint) -> CGPoint {
        CGPoint(
            x: boardOrigin.x + (CGFloat(point.x) + 0.5) * cellSize,
            y: boardOrigin.y + (CGFloat(point.y) + 0.5) * cellSize
        )
    }

    private func traySlotCenter(_ index: Int) -> CGPoint {
        let slotWidth = size.width / 3
        return CGPoint(
            x: slotWidth * (CGFloat(index) + 0.5),
            y: boardOrigin.y / 2
        )
    }

    /// Hücre/blok köşe yuvarlaklığı — aktif skin'den gelir.
    private var cellCornerRadius: CGFloat {
        cellSize * theme.cornerRadiusFactor
    }

    /// Ahşap skinde ekran zemini düz renk yerine dikey plakalı tahta olur.
    /// Sarsıntıdan etkilenmemesi için contentLayer'ın dışında durur.
    private func buildBackground() {
        backgroundNode?.removeFromParent()
        backgroundNode = nil
        guard theme.frameStyle == .woodCarved else { return }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size)
            cg.setFillColor(theme.outerBackground.cgColor)
            cg.fill(rect)
            drawWoodGrain(cg, in: rect, base: theme.outerBackground, lineCount: 90, seed: 0xF00D)

            // Dikey plaka ayrımları
            let plankWidth = size.width / 4
            cg.setFillColor(SKColor.black.withAlphaComponent(0.22).cgColor)
            var x = plankWidth
            while x < size.width {
                cg.fill(CGRect(x: x, y: 0, width: 2, height: size.height))
                cg.setFillColor(theme.outerBackground.lightened(0.18).withAlphaComponent(0.35).cgColor)
                cg.fill(CGRect(x: x + 2, y: 0, width: 1, height: size.height))
                cg.setFillColor(SKColor.black.withAlphaComponent(0.22).cgColor)
                x += plankWidth
            }
        }

        let node = SKSpriteNode(texture: SKTexture(image: image))
        node.size = size
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        node.zPosition = -10
        addChild(node)
        backgroundNode = node
    }

    private func buildFrame(boardSide: CGFloat) {
        frameLayer.removeAllChildren()

        let inset: CGFloat
        let cornerRadius: CGFloat
        switch theme.frameStyle {
        case .candyStripe: inset = 15; cornerRadius = 26
        case .goldTrim: inset = 11; cornerRadius = 16
        case .neonGlow: inset = 10; cornerRadius = 14
        case .woodCarved: inset = 18; cornerRadius = 24
        case .plain: inset = 8; cornerRadius = 8
        }

        let rect = CGRect(
            x: boardOrigin.x - inset,
            y: boardOrigin.y - inset,
            width: boardSide + inset * 2,
            height: boardSide + inset * 2
        )

        let board = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
        board.fillColor = theme.boardFill
        board.strokeColor = theme.frameStyle == .plain ? theme.frame : .clear
        board.lineWidth = theme.frameStyle == .plain ? 3 : 0
        frameLayer.addChild(board)

        switch theme.frameStyle {
        case .plain:
            break

        case .candyStripe:
            addFrameSprite(makeStripedFrameTexture(
                size: rect.size,
                thickness: inset,
                cornerRadius: cornerRadius
            ), in: rect)

        case .goldTrim:
            // Kalın dış altın hat + ince iç altın hat
            let outer = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
            outer.fillColor = .clear
            outer.strokeColor = theme.frame
            outer.lineWidth = 2.5
            frameLayer.addChild(outer)

            let innerInset: CGFloat = inset * 0.55
            let inner = SKShapeNode(
                rect: rect.insetBy(dx: innerInset, dy: innerInset),
                cornerRadius: max(2, cornerRadius - innerInset)
            )
            inner.fillColor = .clear
            inner.strokeColor = theme.frame.lightened(0.25).withAlphaComponent(0.55)
            inner.lineWidth = 1
            frameLayer.addChild(inner)

        case .woodCarved:
            addFrameSprite(makeWoodFrameTexture(
                size: rect.size,
                thickness: inset,
                cornerRadius: cornerRadius
            ), in: rect)

        case .neonGlow:
            // Hale taşması için doku çerçeveden geniş üretilir
            let bleed = inset * 2.4
            let textureRect = rect.insetBy(dx: -bleed, dy: -bleed)
            addFrameSprite(makeNeonFrameTexture(
                size: textureRect.size,
                bleed: bleed,
                thickness: inset * 0.5,
                cornerRadius: cornerRadius
            ), in: textureRect)
        }
    }

    private func addFrameSprite(_ texture: SKTexture, in rect: CGRect) {
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = rect.size
        sprite.position = CGPoint(x: rect.midX, y: rect.midY)
        frameLayer.addChild(sprite)
    }

    /// Oyulmuş ahşap çerçeve: damarlı kalın halka, dışta açık ve içte koyu
    /// kenarla kabartma hissi verir.
    private func makeWoodFrameTexture(
        size: CGSize,
        thickness: CGFloat,
        cornerRadius: CGFloat
    ) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            let outerRect = CGRect(origin: .zero, size: size)
            let innerRect = outerRect.insetBy(dx: thickness, dy: thickness)
            let innerRadius = max(2, cornerRadius - thickness * 0.6)

            let ring = UIBezierPath(roundedRect: outerRect, cornerRadius: cornerRadius)
            ring.append(UIBezierPath(roundedRect: innerRect, cornerRadius: innerRadius))
            ring.usesEvenOddFillRule = true

            cg.saveGState()
            cg.addPath(ring.cgPath)
            cg.clip(using: .evenOdd)

            cg.setFillColor(theme.frame.cgColor)
            cg.fill(outerRect)
            drawWoodGrain(cg, in: outerRect, base: theme.frame, lineCount: 40, seed: 0x5EED)

            // Üstten gelen ışık: çerçevenin üst yarısı hafif aydınlık
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    SKColor.white.withAlphaComponent(0.14).cgColor,
                    SKColor.clear.cgColor,
                    SKColor.black.withAlphaComponent(0.22).cgColor
                ] as CFArray,
                locations: [0, 0.5, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: 0, y: size.height),
                    options: []
                )
            }
            cg.restoreGState()

            // Dış kenarda açık, iç kenarda koyu hat → oyulmuş görünüm
            cg.addPath(UIBezierPath(roundedRect: outerRect.insetBy(dx: 1, dy: 1), cornerRadius: cornerRadius).cgPath)
            cg.setStrokeColor(theme.frame.lightened(0.35).cgColor)
            cg.setLineWidth(2)
            cg.strokePath()

            cg.addPath(UIBezierPath(roundedRect: innerRect, cornerRadius: innerRadius).cgPath)
            cg.setStrokeColor(theme.frame.darkened(0.55).cgColor)
            cg.setLineWidth(3)
            cg.strokePath()
        }
        return SKTexture(image: image)
    }

    /// Neon çerçeve: camgöbeğinden magentaya degrade yapan, dışa ışıyan hat.
    private func makeNeonFrameTexture(
        size: CGSize,
        bleed: CGFloat,
        thickness: CGFloat,
        cornerRadius: CGFloat
    ) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            let path = UIBezierPath(
                roundedRect: CGRect(
                    x: bleed, y: bleed,
                    width: size.width - bleed * 2,
                    height: size.height - bleed * 2
                ),
                cornerRadius: cornerRadius
            ).cgPath

            // Hale: giderek genişleyen, soluklaşan hatlar (screen ile toplanır)
            cg.setBlendMode(.screen)
            let glowColor = theme.frame.blended(with: theme.frameAccent, ratio: 0.5)
            for step in 0..<4 {
                cg.addPath(path)
                cg.setLineWidth(thickness * (1.6 + CGFloat(step) * 2.2))
                cg.setStrokeColor(glowColor.withAlphaComponent(0.16 - CGFloat(step) * 0.03).cgColor)
                cg.strokePath()
            }
            cg.setBlendMode(.normal)

            // Keskin degrade hat: yol çizgiye dönüştürülüp içine degrade basılır
            cg.saveGState()
            cg.addPath(path)
            cg.setLineWidth(thickness)
            cg.replacePathWithStrokedPath()
            cg.clip()
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    theme.frame.cgColor,
                    theme.frame.blended(with: theme.frameAccent, ratio: 0.5).cgColor,
                    theme.frameAccent.cgColor
                ] as CFArray,
                locations: [0, 0.5, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
            cg.restoreGState()
        }
        return SKTexture(image: image)
    }

    /// Şeker kamışı çerçeve: beyaz halka üzerine çapraz renkli şeritler.
    private func makeStripedFrameTexture(
        size: CGSize,
        thickness: CGFloat,
        cornerRadius: CGFloat
    ) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext

            // Halka: dış yuvarlak dikdörtgenden içteki oyulur
            let ring = UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerRadius: cornerRadius
            )
            ring.append(UIBezierPath(
                roundedRect: CGRect(
                    x: thickness,
                    y: thickness,
                    width: size.width - thickness * 2,
                    height: size.height - thickness * 2
                ),
                cornerRadius: max(2, cornerRadius - thickness)
            ))
            ring.usesEvenOddFillRule = true

            cg.saveGState()
            cg.addPath(ring.cgPath)
            cg.clip(using: .evenOdd)

            cg.setFillColor(SKColor.white.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            cg.setFillColor(theme.frame.cgColor)
            let stripeWidth = thickness * 0.8
            var offset = -size.height
            while offset < size.width {
                cg.beginPath()
                cg.addLines(between: [
                    CGPoint(x: offset, y: 0),
                    CGPoint(x: offset + stripeWidth, y: 0),
                    CGPoint(x: offset + stripeWidth + size.height, y: size.height),
                    CGPoint(x: offset + size.height, y: size.height)
                ])
                cg.closePath()
                cg.fillPath()
                offset += stripeWidth * 2
            }
            cg.restoreGState()
        }
        return SKTexture(image: image)
    }

    private func buildGrid() {
        gridLayer.removeAllChildren()

        switch theme.gridStyle {
        case .filledCells:
            for y in 0..<boardSize {
                for x in 0..<boardSize {
                    let cell = SKShapeNode(
                        rectOf: CGSize(width: cellSize - 2, height: cellSize - 2),
                        cornerRadius: cellCornerRadius
                    )
                    cell.fillColor = theme.emptyCell
                    cell.strokeColor = .clear
                    cell.lineWidth = 0
                    cell.position = cellCenter(GridPoint(x: x, y: y))
                    gridLayer.addChild(cell)
                }
            }

        case .woodenCells:
            // Tek bir damarlı hücre dokusu üretilip tüm hücrelerde kullanılır
            let texture = makeWoodCellTexture()
            for y in 0..<boardSize {
                for x in 0..<boardSize {
                    let cell = SKSpriteNode(texture: texture)
                    cell.size = CGSize(width: cellSize - 2, height: cellSize - 2)
                    cell.position = cellCenter(GridPoint(x: x, y: y))
                    gridLayer.addChild(cell)
                }
            }

        case .lines:
            let side = cellSize * CGFloat(boardSize)
            let lineColor = theme.emptyCell.withAlphaComponent(0.75)

            for index in 0...boardSize {
                let offset = CGFloat(index) * cellSize

                let horizontal = SKShapeNode(rectOf: CGSize(width: side, height: 1))
                horizontal.fillColor = lineColor
                horizontal.strokeColor = .clear
                horizontal.position = CGPoint(
                    x: boardOrigin.x + side / 2,
                    y: boardOrigin.y + offset
                )
                gridLayer.addChild(horizontal)

                let vertical = SKShapeNode(rectOf: CGSize(width: 1, height: side))
                vertical.fillColor = lineColor
                vertical.strokeColor = .clear
                vertical.position = CGPoint(
                    x: boardOrigin.x + offset,
                    y: boardOrigin.y + side / 2
                )
                gridLayer.addChild(vertical)
            }

            // Kesişim noktaları
            for row in 1..<boardSize {
                for column in 1..<boardSize {
                    let dot = SKShapeNode(circleOfRadius: 1.6)
                    dot.fillColor = theme.emptyCell.lightened(0.4)
                    dot.strokeColor = .clear
                    dot.position = CGPoint(
                        x: boardOrigin.x + CGFloat(column) * cellSize,
                        y: boardOrigin.y + CGFloat(row) * cellSize
                    )
                    gridLayer.addChild(dot)
                }
            }
        }
    }

    /// Boş ahşap hücre: damarlı, kenarları içe gölgeli (oyulmuş) kare.
    private func makeWoodCellTexture() -> SKTexture {
        let s = GameScene.blockCanvas
        let radius = s * theme.cornerRadiusFactor * 0.5

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        let image = renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(x: 0, y: 0, width: s, height: s)

            cg.saveGState()
            cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath)
            cg.clip()
            cg.setFillColor(theme.emptyCell.cgColor)
            cg.fill(rect)
            drawWoodGrain(cg, in: rect, base: theme.emptyCell, lineCount: 10, seed: 0xCE11)

            // İçe gölge: üstte koyu, altta hafif açık → oyuk hissi
            cg.setFillColor(SKColor.black.withAlphaComponent(0.28).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: s, height: s * 0.08))
            cg.setFillColor(theme.emptyCell.lightened(0.22).withAlphaComponent(0.5).cgColor)
            cg.fill(CGRect(x: 0, y: s * 0.93, width: s, height: s * 0.07))
            cg.restoreGState()
        }
        return SKTexture(image: image)
    }

    /// Blok dokusu, renk indeksine göre önbelleklenir.
    private func blockTexture(colorIndex: Int) -> SKTexture {
        if let cached = blockTextureCache[colorIndex] { return cached }
        let texture = makeBlockTexture(base: theme.blockColor(colorIndex))
        blockTextureCache[colorIndex] = texture
        return texture
    }

    /// Patlayacak satır önizlemesi için bloğun açık tonlu hali.
    /// Beyaza değil, kendi renginin parlak tonuna gider — her skin'de belirgin.
    private func highlightTexture(colorIndex: Int) -> SKTexture {
        if let cached = highlightTextureCache[colorIndex] { return cached }
        let base = theme.blockColor(colorIndex).lightened(GameScene.previewLighten)
        let texture = makeBlockTexture(base: base)
        highlightTextureCache[colorIndex] = texture
        return texture
    }

    /// Neon bloklarda hale dokunun dışına taştığı için sprite hücreden büyük çizilir.
    private var blockSpriteScale: CGFloat {
        theme.pattern == .neon ? GameScene.neonCanvas / GameScene.blockCanvas : 1
    }

    private static let blockCanvas: CGFloat = 128
    private static let neonCanvas: CGFloat = 176

    /// Skin'in blok stiline göre doku üretir.
    private func makeBlockTexture(base: SKColor) -> SKTexture {
        switch theme.pattern {
        case .candy: return makeCandyBlockTexture(base: base)
        case .neon: return makeNeonBlockTexture(base: base)
        case .wood: return makeWoodBlockTexture(base: base)
        case .dots: return makeDiceBlockTexture(base: base)
        default: return makeBevelBlockTexture(base: base)
        }
    }

    /// Zar bloğu: çok yuvarlak pastel küp, çapraz degrade ve beş beyaz nokta.
    private func makeDiceBlockTexture(base: SKColor) -> SKTexture {
        let s = GameScene.blockCanvas
        let radius = s * theme.cornerRadiusFactor
        let body = CGRect(x: 2, y: 2, width: s - 4, height: s - 4)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        let image = renderer.image { context in
            let cg = context.cgContext

            // Alt kenar: küpün kalınlığı
            cg.setFillColor(base.darkened(0.28).cgColor)
            cg.addPath(UIBezierPath(
                roundedRect: body.offsetBy(dx: 0, dy: s * 0.035),
                cornerRadius: radius
            ).cgPath)
            cg.fillPath()

            cg.saveGState()
            cg.addPath(UIBezierPath(roundedRect: body, cornerRadius: radius).cgPath)
            cg.clip()

            // Gövde: üst-soldan alt-sağa degrade
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [base.lightened(0.3).cgColor, base.darkened(0.08).cgColor] as CFArray,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: body.minX, y: body.minY),
                    end: CGPoint(x: body.maxX, y: body.maxY),
                    options: []
                )
            }

            // Üst-solda yumuşak parlama
            cg.setFillColor(SKColor.white.withAlphaComponent(0.22).cgColor)
            cg.fillEllipse(in: CGRect(
                x: body.minX - body.width * 0.1,
                y: body.minY - body.height * 0.15,
                width: body.width * 0.85,
                height: body.height * 0.6
            ))

            // Zarın beş noktası (dört köşe + merkez)
            let dotRadius = s * 0.088
            let positions: [(Double, Double)] = [
                (0.28, 0.28), (0.72, 0.28), (0.5, 0.5), (0.28, 0.72), (0.72, 0.72)
            ]
            for (fx, fy) in positions {
                let center = CGPoint(
                    x: body.minX + body.width * fx,
                    y: body.minY + body.height * fy
                )
                // Noktanın altında ince gölge → hafif gömülü görünüm
                cg.setFillColor(base.darkened(0.22).withAlphaComponent(0.55).cgColor)
                cg.fillEllipse(in: CGRect(
                    x: center.x - dotRadius, y: center.y - dotRadius + s * 0.012,
                    width: dotRadius * 2, height: dotRadius * 2
                ))
                cg.setFillColor(SKColor.white.withAlphaComponent(0.96).cgColor)
                cg.fillEllipse(in: CGRect(
                    x: center.x - dotRadius, y: center.y - dotRadius,
                    width: dotRadius * 2, height: dotRadius * 2
                ))
            }
            cg.restoreGState()

            // İnce koyu kontur
            cg.addPath(UIBezierPath(roundedRect: body, cornerRadius: radius).cgPath)
            cg.setStrokeColor(base.darkened(0.3).cgColor)
            cg.setLineWidth(s * 0.022)
            cg.strokePath()
        }
        return SKTexture(image: image)
    }

    /// Ahşap damarı: yatay, düzensiz genişlikte açık/koyu şeritler.
    /// Tohum sabit verilir ki doku her üretimde aynı çıksın.
    private func drawWoodGrain(
        _ cg: CGContext,
        in rect: CGRect,
        base: SKColor,
        lineCount: Int,
        seed: UInt64
    ) {
        var rng = SeededGenerator(seed: seed)
        for _ in 0..<lineCount {
            let y = rect.minY + CGFloat.random(in: 0...1, using: &rng) * rect.height
            let thickness = CGFloat.random(in: 0.4...2.4, using: &rng)
            let isDark = Bool.random(using: &rng)
            let alpha = CGFloat.random(in: 0.05...0.16, using: &rng)
            let tint = isDark ? base.darkened(0.55) : base.lightened(0.45)
            cg.setFillColor(tint.withAlphaComponent(alpha).cgColor)
            cg.fill(CGRect(x: rect.minX, y: y, width: rect.width, height: thickness))
        }
    }

    /// Ahşap blok: mat boyalı karo — üstte açık, altta koyu kenar, hafif damar.
    private func makeWoodBlockTexture(base: SKColor) -> SKTexture {
        let s = GameScene.blockCanvas
        let radius = s * theme.cornerRadiusFactor
        let edge = s * 0.09

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        let image = renderer.image { context in
            let cg = context.cgContext
            let body = CGRect(x: 1, y: 1, width: s - 2, height: s - 2)

            // Gövde: yukarıdan aşağıya hafif degrade
            cg.saveGState()
            cg.addPath(UIBezierPath(roundedRect: body, cornerRadius: radius).cgPath)
            cg.clip()
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [base.lightened(0.16).cgColor, base.darkened(0.1).cgColor] as CFArray,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: body.midX, y: body.minY),
                    end: CGPoint(x: body.midX, y: body.maxY),
                    options: []
                )
            }

            drawWoodGrain(cg, in: body, base: base, lineCount: 14, seed: 0xB10C)

            // Üstte açık, altta koyu kenar (boyalı karo kalınlığı)
            cg.setFillColor(base.lightened(0.4).withAlphaComponent(0.85).cgColor)
            cg.fill(CGRect(x: body.minX, y: body.minY, width: body.width, height: edge * 0.55))
            cg.setFillColor(base.darkened(0.35).withAlphaComponent(0.9).cgColor)
            cg.fill(CGRect(x: body.minX, y: body.maxY - edge * 0.7, width: body.width, height: edge * 0.7))
            cg.restoreGState()

            // Koyu dış hat
            cg.addPath(UIBezierPath(roundedRect: body, cornerRadius: radius).cgPath)
            cg.setStrokeColor(base.darkened(0.5).cgColor)
            cg.setLineWidth(s * 0.03)
            cg.strokePath()
        }
        return SKTexture(image: image)
    }

    /// Neon tüp bloğu: koyu iç gövde, içeriden ışıyan renk, çift parlak hat
    /// (dış + iç çerçeve) ve etrafa yayılan bloom.
    private func makeNeonBlockTexture(base: SKColor) -> SKTexture {
        let canvas = GameScene.neonCanvas
        let block = GameScene.blockCanvas
        let pad = (canvas - block) / 2
        let body = CGRect(x: pad, y: pad, width: block, height: block)
        let radius = block * 0.13

        let outerPath = UIBezierPath(
            roundedRect: body.insetBy(dx: block * 0.03, dy: block * 0.03),
            cornerRadius: radius
        ).cgPath
        let innerInset = block * 0.15
        let innerPath = UIBezierPath(
            roundedRect: body.insetBy(dx: innerInset, dy: innerInset),
            cornerRadius: max(1, radius * 0.7)
        ).cgPath

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvas, height: canvas))
        let image = renderer.image { context in
            let cg = context.cgContext
            let center = CGPoint(x: body.midX, y: body.midY)

            // 1) Koyu iç gövde
            cg.setFillColor(base.darkened(0.8).cgColor)
            cg.addPath(outerPath)
            cg.fillPath()

            // 2) İçeriden ışıma: merkeze doğru rengin soluk parlaması
            cg.saveGState()
            cg.addPath(outerPath)
            cg.clip()
            cg.setBlendMode(.screen)
            if let inner = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    base.withAlphaComponent(0.34).cgColor,
                    base.withAlphaComponent(0).cgColor
                ] as CFArray,
                locations: [0, 1]
            ) {
                cg.drawRadialGradient(
                    inner,
                    startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: block * 0.62,
                    options: []
                )
            }
            cg.restoreGState()

            // 3) Dışa yayılan bloom: genişleyip soluklaşan hatlar
            cg.setBlendMode(.screen)
            for (width, alpha) in [(0.22, 0.10), (0.14, 0.15), (0.08, 0.22)] {
                cg.addPath(outerPath)
                cg.setLineWidth(block * CGFloat(width))
                cg.setStrokeColor(base.withAlphaComponent(CGFloat(alpha)).cgColor)
                cg.strokePath()
            }
            cg.setBlendMode(.normal)

            // 4) Tüp hatları: dış çerçeve + iç çerçeve, ikisi de ışıklı
            for path in [outerPath, innerPath] {
                cg.saveGState()
                cg.setShadow(offset: .zero, blur: block * 0.1, color: base.cgColor)
                cg.addPath(path)
                cg.setLineWidth(block * 0.032)
                cg.setStrokeColor(base.lightened(0.55).cgColor)
                cg.strokePath()
                cg.restoreGState()
            }

            // 5) Beyaz çekirdek: tüpün en parlak orta damarı
            cg.addPath(outerPath)
            cg.setLineWidth(block * 0.012)
            cg.setStrokeColor(SKColor.white.withAlphaComponent(0.85).cgColor)
            cg.strokePath()

            // 6) Cam üzerinde soluk çapraz yansıma
            cg.saveGState()
            cg.addPath(innerPath)
            cg.clip()
            cg.beginPath()
            cg.addLines(between: [
                CGPoint(x: body.minX, y: body.minY + block * 0.62),
                CGPoint(x: body.minX, y: body.minY + block * 0.42),
                CGPoint(x: body.minX + block * 0.62, y: body.minY),
                CGPoint(x: body.minX + block * 0.42, y: body.minY)
            ])
            cg.closePath()
            cg.setFillColor(SKColor.white.withAlphaComponent(0.14).cgColor)
            cg.fillPath()
            cg.restoreGState()
        }
        return SKTexture(image: image)
    }

    /// Şeker/jelibon bloğu: doygun dış kenar → beyaz iç hat → açık degrade gövde,
    /// üzerinde beyaz organik lekeler ve noktalar.
    private func makeCandyBlockTexture(base: SKColor) -> SKTexture {
        let s = GameScene.blockCanvas
        let radius = s * theme.cornerRadiusFactor

        let rimColor = base.adjusted(saturation: 1.6, brightness: 0.92)
        let bodyTop = base.adjusted(saturation: 0.6, brightness: 1.12)
        let bodyBottom = base.adjusted(saturation: 1.05, brightness: 0.99)

        let rimWidth = s * 0.055        // doygun dış kenar
        let innerLine = s * 0.035       // beyaz iç hat

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        let image = renderer.image { context in
            let cg = context.cgContext

            func fillRounded(inset: CGFloat, radius: CGFloat, color: SKColor) {
                cg.setFillColor(color.cgColor)
                cg.addPath(UIBezierPath(
                    roundedRect: CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2),
                    cornerRadius: max(1, radius)
                ).cgPath)
                cg.fillPath()
            }

            // 1) Doygun dış kenar
            fillRounded(inset: 0.5, radius: radius, color: rimColor)

            // 2) Beyaz iç hat
            fillRounded(
                inset: rimWidth,
                radius: radius - rimWidth,
                color: SKColor.white.withAlphaComponent(0.92)
            )

            // 3) Gövde: yukarıdan aşağıya açıktan doyguna degrade
            let bodyInset = rimWidth + innerLine
            let body = CGRect(
                x: bodyInset, y: bodyInset,
                width: s - bodyInset * 2, height: s - bodyInset * 2
            )
            cg.saveGState()
            cg.addPath(UIBezierPath(
                roundedRect: body,
                cornerRadius: max(1, radius - bodyInset)
            ).cgPath)
            cg.clip()
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [bodyTop.cgColor, bodyBottom.cgColor] as CFArray,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: body.midX, y: body.minY),
                    end: CGPoint(x: body.midX, y: body.maxY),
                    options: []
                )
            }

            // 4) Beyaz organik leke: üst-solda üst üste binen elipsler
            cg.setFillColor(SKColor.white.withAlphaComponent(0.85).cgColor)
            let blobs: [(x: Double, y: Double, w: Double, h: Double)] = [
                (0.08, 0.10, 0.46, 0.24),
                (0.30, 0.05, 0.32, 0.21),
                (0.05, 0.24, 0.26, 0.21),
                (0.46, 0.17, 0.22, 0.17),
                (0.62, 0.09, 0.16, 0.13)
            ]
            for blob in blobs {
                cg.fillEllipse(in: CGRect(
                    x: body.minX + body.width * blob.x,
                    y: body.minY + body.height * blob.y,
                    width: body.width * blob.w,
                    height: body.height * blob.h
                ))
            }

            // 5) Küçük yuvarlak noktalar (alt sıra + serpiştirme)
            cg.setFillColor(SKColor.white.withAlphaComponent(0.9).cgColor)
            let dots: [(x: Double, y: Double, r: Double)] = [
                (0.22, 0.76, 0.058),
                (0.38, 0.80, 0.046),
                (0.53, 0.75, 0.036),
                (0.74, 0.66, 0.05),
                (0.80, 0.36, 0.038),
                (0.13, 0.56, 0.032)
            ]
            for dot in dots {
                let r = body.width * dot.r
                cg.fillEllipse(in: CGRect(
                    x: body.minX + body.width * dot.x - r,
                    y: body.minY + body.height * dot.y - r,
                    width: r * 2,
                    height: r * 2
                ))
            }
            cg.restoreGState()
        }
        return SKTexture(image: image)
    }

    /// Klasik "bevel" blok dokusu: üst/sol yüzler aydınlık, sağ/alt yüzler gölgeli.
    private func makeBevelBlockTexture(base: SKColor) -> SKTexture {
        let s: CGFloat = 128
        let b: CGFloat = 22

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        let image = renderer.image { context in
            let cg = context.cgContext
            cg.addPath(UIBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                cornerRadius: s * theme.cornerRadiusFactor
            ).cgPath)
            cg.clip()

            func fillQuad(_ points: [CGPoint], _ color: SKColor) {
                cg.beginPath()
                cg.addLines(between: points)
                cg.closePath()
                cg.setFillColor(color.cgColor)
                cg.fillPath()
            }

            // üst (en aydınlık), sol (hafif aydınlık), sağ (hafif gölge), alt (en koyu)
            fillQuad([CGPoint(x: 0, y: 0), CGPoint(x: s, y: 0), CGPoint(x: s - b, y: b), CGPoint(x: b, y: b)], base.lightened(0.42))
            fillQuad([CGPoint(x: 0, y: 0), CGPoint(x: b, y: b), CGPoint(x: b, y: s - b), CGPoint(x: 0, y: s)], base.lightened(0.14))
            fillQuad([CGPoint(x: s, y: 0), CGPoint(x: s, y: s), CGPoint(x: s - b, y: s - b), CGPoint(x: s - b, y: b)], base.darkened(0.2))
            fillQuad([CGPoint(x: 0, y: s), CGPoint(x: b, y: s - b), CGPoint(x: s - b, y: s - b), CGPoint(x: s, y: s)], base.darkened(0.4))

            let centerRect = CGRect(x: b, y: b, width: s - 2 * b, height: s - 2 * b)
            cg.setFillColor(base.cgColor)
            cg.fill(centerRect)

            drawPattern(theme.pattern, in: centerRect, context: cg, base: base, fillQuad: fillQuad)
        }

        return SKTexture(image: image)
    }

    /// Blok yüzeyine skin'in desenini çizer (doku üretiminin parçası).
    private func drawPattern(
        _ pattern: BlockPattern,
        in rect: CGRect,
        context cg: CGContext,
        base: SKColor,
        fillQuad: ([CGPoint], SKColor) -> Void
    ) {
        switch pattern {
        case .plain:
            break

        case .stripes:
            cg.saveGState()
            cg.clip(to: rect)
            let stripeColor = base.lightened(0.32).withAlphaComponent(0.65)
            let width: CGFloat = rect.width * 0.18
            var offset = -rect.height
            while offset < rect.width {
                fillQuad([
                    CGPoint(x: rect.minX + offset, y: rect.maxY),
                    CGPoint(x: rect.minX + offset + width, y: rect.maxY),
                    CGPoint(x: rect.minX + offset + width + rect.height, y: rect.minY),
                    CGPoint(x: rect.minX + offset + rect.height, y: rect.minY)
                ], stripeColor)
                offset += width * 2.2
            }
            cg.restoreGState()

        case .candy, .neon, .wood, .dots:
            // Bu stillerin kendi doku üreticileri var
            break

        case .gem:
            cg.saveGState()
            cg.clip(to: rect)
            // İç elmas yüzeyi + parlama
            fillQuad([
                CGPoint(x: rect.midX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.midX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.midY)
            ], base.lightened(0.24))
            cg.setFillColor(SKColor.white.withAlphaComponent(0.45).cgColor)
            cg.fillEllipse(in: CGRect(
                x: rect.minX + rect.width * 0.14,
                y: rect.minY + rect.height * 0.12,
                width: rect.width * 0.3,
                height: rect.height * 0.18
            ))
            cg.restoreGState()
        }
    }

    private func makeBlockNode(colorIndex: Int, side: CGFloat) -> SKSpriteNode {
        let drawn = side * blockSpriteScale
        return SKSpriteNode(
            texture: blockTexture(colorIndex: colorIndex),
            size: CGSize(width: drawn, height: drawn)
        )
    }

    private func renderBoard() {
        blocksLayer.removeAllChildren()
        boardBlockNodes.removeAll()
        previewedPoints.removeAll()
        for (point, colorIndex) in model.engine.board.occupiedCells {
            let block = makeBlockNode(colorIndex: colorIndex, side: cellSize)
            block.position = cellCenter(point)
            blocksLayer.addChild(block)
            boardBlockNodes[point] = block
        }
    }

    /// Parça düğümü: origin'i şeklin sol alt köşesi olacak şekilde bloklar içerir.
    private func makePieceNode(_ piece: Piece) -> SKNode {
        let container = SKNode()
        for cell in piece.shape.cells {
            let block = makeBlockNode(colorIndex: piece.colorIndex, side: cellSize)
            block.position = CGPoint(
                x: (CGFloat(cell.x) + 0.5) * cellSize,
                y: (CGFloat(cell.y) + 0.5) * cellSize
            )
            container.addChild(block)
        }
        return container
    }

    private func renderTray() {
        trayLayer.removeAllChildren()
        trayPieceNodes.removeAll()
        let slotWidth = size.width / 3
        let trayHeight = max(boardOrigin.y, 1)

        for (index, maybePiece) in model.engine.hand.enumerated() {
            guard let piece = maybePiece else { continue }
            let node = makePieceNode(piece)
            let pieceWidth = CGFloat(piece.shape.width) * cellSize
            let pieceHeight = CGFloat(piece.shape.height) * cellSize
            let scale = min(0.5, (slotWidth * 0.8) / pieceWidth, (trayHeight * 0.7) / pieceHeight)
            node.setScale(scale)
            let center = traySlotCenter(index)
            node.position = CGPoint(
                x: center.x - pieceWidth * scale / 2,
                y: center.y - pieceHeight * scale / 2
            )
            trayLayer.addChild(node)
            trayPieceNodes[index] = node
        }
    }

    // MARK: - Dokunma / sürükleme

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard drag == nil, !model.isGameOver, let touch = touches.first else { return }
        let location = touch.location(in: self)

        for (index, node) in trayPieceNodes {
            let hitArea = node.calculateAccumulatedFrame().insetBy(dx: -14, dy: -14)
            guard hitArea.contains(location), let piece = model.engine.hand[index] else { continue }

            let homePosition = node.position
            let homeScale = node.xScale
            let pieceWidth = CGFloat(piece.shape.width) * cellSize
            let delta = CGPoint(x: -pieceWidth / 2, y: cellSize * 1.3)

            node.zPosition = 20
            node.run(.scale(to: 1.0, duration: 0.12))
            node.position = CGPoint(x: location.x + delta.x, y: location.y + delta.y)

            drag = DragState(
                handIndex: index,
                node: node,
                delta: delta,
                homePosition: homePosition,
                homeScale: homeScale
            )
            updateGhost()
            return
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let drag, let touch = touches.first else { return }
        let location = touch.location(in: self)
        drag.node.position = CGPoint(x: location.x + drag.delta.x, y: location.y + drag.delta.y)
        updateGhost()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishDrag()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishDrag()
    }

    private func candidateOrigin(for node: SKNode) -> GridPoint {
        GridPoint(
            x: Int(round((node.position.x - boardOrigin.x) / cellSize)),
            y: Int(round((node.position.y - boardOrigin.y) / cellSize))
        )
    }

    private func updateGhost() {
        guard let drag, let piece = model.engine.hand[drag.handIndex] else { return }
        let origin = candidateOrigin(for: drag.node)
        if origin == lastGhostOrigin { return }
        lastGhostOrigin = origin

        ghostLayer.removeAllChildren()
        clearLinePreview()
        guard model.engine.canPlace(handIndex: drag.handIndex, at: origin) else { return }

        for cell in piece.shape.cells {
            let ghost = SKShapeNode(
                rectOf: CGSize(width: cellSize - 2, height: cellSize - 2),
                cornerRadius: cellCornerRadius
            )
            ghost.fillColor = theme.blockColor(piece.colorIndex)
                .lightened(0.2)
                .withAlphaComponent(0.5)
            ghost.strokeColor = .clear
            ghost.position = cellCenter(GridPoint(x: origin.x + cell.x, y: origin.y + cell.y))
            ghostLayer.addChild(ghost)
        }

        showLinePreview(for: piece, at: origin)
    }

    // MARK: - Patlayacak satır önizlemesi

    /// Parça bu konuma bırakılırsa tamamlanacak satır/sütunlardaki blokları
    /// parçanın renginin açık tonuna boyar (orijinal Block Blast davranışı).
    private func showLinePreview(for piece: Piece, at origin: GridPoint) {
        let lines = model.engine.board.linesCompleted(byPlacing: piece.shape, at: origin)
        guard !lines.rows.isEmpty || !lines.columns.isEmpty else { return }

        let previewTexture = highlightTexture(colorIndex: piece.colorIndex)
        var points = Set<GridPoint>()
        for y in lines.rows {
            for x in 0..<boardSize { points.insert(GridPoint(x: x, y: y)) }
        }
        for x in lines.columns {
            for y in 0..<boardSize { points.insert(GridPoint(x: x, y: y)) }
        }

        for point in points {
            guard let node = boardBlockNodes[point] else { continue }
            // Renk değişimi tek renk skinlerde görünmez; bu yüzden blok kendi
            // renginin açık tonuna geçip nabız gibi atıyor — beyazlamadan belirgin.
            node.texture = previewTexture
            node.zPosition = 1
            node.removeAction(forKey: GameScene.previewPulseKey)
            let pulse = SKAction.sequence([
                .scale(to: 1.12, duration: 0.24),
                .scale(to: 1.0, duration: 0.24)
            ])
            pulse.timingMode = .easeInEaseOut
            node.run(.repeatForever(pulse), withKey: GameScene.previewPulseKey)
            previewedPoints.append(point)
        }
    }

    /// Önizlemede vurgulanan blokları normal haline döndürür.
    private func clearLinePreview() {
        for point in previewedPoints {
            guard let node = boardBlockNodes[point],
                  let colorIndex = model.engine.board[point] else { continue }
            node.removeAction(forKey: GameScene.previewPulseKey)
            node.setScale(1.0)
            node.zPosition = 0
            node.texture = blockTexture(colorIndex: colorIndex)
        }
        previewedPoints.removeAll()
    }

    private func finishDrag() {
        guard let drag else { return }
        self.drag = nil
        lastGhostOrigin = nil
        ghostLayer.removeAllChildren()
        clearLinePreview()

        let origin = candidateOrigin(for: drag.node)
        if let outcome = model.place(handIndex: drag.handIndex, at: origin) {
            drag.node.removeFromParent()
            renderBoard()
            renderTray()
            placeHaptic.impactOccurred()
            animate(outcome: outcome, dropOrigin: origin)
            if model.isGameOver {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } else {
            returnToTray(drag)
        }
    }

    private func returnToTray(_ drag: DragState) {
        drag.node.zPosition = 0
        let back = SKAction.group([
            .move(to: drag.homePosition, duration: 0.2),
            .scale(to: drag.homeScale, duration: 0.2)
        ])
        back.timingMode = .easeOut
        drag.node.run(back)
    }

    // MARK: - Efektler

    private func animate(outcome: PlacementOutcome, dropOrigin: GridPoint) {
        guard outcome.clearedLineCount > 0 else { return }
        clearHaptic.impactOccurred()

        for cleared in outcome.clearedCells {
            // Bırakılan noktadan dışa doğru dalga halinde patlama
            let distance = abs(cleared.point.x - dropOrigin.x) + abs(cleared.point.y - dropOrigin.y)
            explodeCell(cleared, delay: Double(distance) * 0.02)
        }

        let labelPosition = clampedToBoard(cellCenter(dropOrigin))
        showFloatingLabel("+\(outcome.totalPoints)", at: labelPosition, fontSize: cellSize * 0.6)

        if outcome.comboStreak >= 2 {
            let bonus = model.economy.comboBonus(forStreak: outcome.comboStreak)
            showComboEffect(streak: outcome.comboStreak, bonusCoins: bonus)
            shakeBoard(intensity: min(3 + CGFloat(outcome.comboStreak) * 1.5, 10))
        }
    }

    // MARK: - Kombo efekti

    private func shakeBoard(intensity: CGFloat) {
        contentLayer.removeAction(forKey: "shake")
        contentLayer.position = .zero
        var steps: [SKAction] = []
        for _ in 0..<5 {
            let dx = CGFloat.random(in: -intensity...intensity)
            let dy = CGFloat.random(in: -intensity...intensity)
            steps.append(.moveBy(x: dx, y: dy, duration: 0.032))
            steps.append(.moveBy(x: -dx, y: -dy, duration: 0.032))
        }
        contentLayer.run(.sequence(steps), withKey: "shake")
    }

    private func showComboEffect(streak: Int, bonusCoins: Int) {
        let boardSide = cellSize * CGFloat(boardSize)
        let center = CGPoint(x: boardOrigin.x + boardSide / 2, y: boardOrigin.y + boardSide / 2)
        let gold = SKColor(hex: "#FFD700")

        // KOMBO yazısı: gölge + altın, yaylanarak büyür
        let container = SKNode()
        container.position = center
        container.zPosition = 40
        container.setScale(0)
        addChild(container)

        let text = "KOMBO x\(streak)"
        let fontSize = cellSize * 0.85

        let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shadow.text = text
        shadow.fontSize = fontSize
        shadow.fontColor = SKColor.black.withAlphaComponent(0.45)
        shadow.position = CGPoint(x: 3, y: -3)
        container.addChild(shadow)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = gold
        container.addChild(label)

        if bonusCoins > 0 {
            let bonusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
            bonusLabel.text = "+\(bonusCoins) coin"
            bonusLabel.fontSize = cellSize * 0.45
            bonusLabel.fontColor = gold.lightened(0.3)
            bonusLabel.position = CGPoint(x: 0, y: -cellSize * 0.9)
            container.addChild(bonusLabel)
        }

        let pop = SKAction.sequence([
            .scale(to: 1.15, duration: 0.16),
            .scale(to: 1.0, duration: 0.08)
        ])
        pop.timingMode = .easeOut
        let exit = SKAction.group([
            .moveBy(x: 0, y: cellSize * 1.2, duration: 0.35),
            .fadeOut(withDuration: 0.35)
        ])
        container.run(.sequence([pop, .wait(forDuration: 0.55), exit, .removeFromParent()]))

        // Coin rozetine (sağ üste) uçan altınlar
        guard bonusCoins > 0 else { return }
        let target = CGPoint(x: size.width - 44, y: size.height - 16)
        for index in 0..<4 {
            let coin = SKShapeNode(circleOfRadius: cellSize * 0.16)
            coin.fillColor = gold
            coin.strokeColor = SKColor(hex: "#C98A00")
            coin.lineWidth = 2
            coin.position = CGPoint(
                x: center.x + CGFloat.random(in: -cellSize...cellSize),
                y: center.y + CGFloat.random(in: -cellSize * 0.5...cellSize * 0.5)
            )
            coin.zPosition = 41
            coin.setScale(0)
            addChild(coin)

            let appear = SKAction.scale(to: 1.0, duration: 0.12)
            let fly = SKAction.move(to: target, duration: 0.5)
            fly.timingMode = .easeIn
            coin.run(.sequence([
                .wait(forDuration: 0.12 + Double(index) * 0.06),
                appear,
                fly,
                .fadeOut(withDuration: 0.08),
                .removeFromParent()
            ]))
        }
    }

    private func explodeCell(_ cleared: ClearedCell, delay: TimeInterval) {
        let center = cellCenter(cleared.point)

        // Ana blok: kısa parlayıp büyüyerek kaybolur
        let block = makeBlockNode(colorIndex: cleared.colorIndex, side: cellSize)
        block.position = center
        block.zPosition = 12
        effectsLayer.addChild(block)

        let whiten = SKAction.sequence([
            .colorize(with: .white, colorBlendFactor: 0.7, duration: 0.06),
            .colorize(withColorBlendFactor: 0, duration: 0.08)
        ])
        let burst = SKAction.group([
            .scale(to: 1.28, duration: 0.16),
            .sequence([.wait(forDuration: 0.06), .fadeOut(withDuration: 0.16)])
        ])
        block.run(.sequence([.wait(forDuration: delay), whiten, burst, .removeFromParent()]))

        // Kırıntılar: bloğun renginde küçük parçalar dışarı saçılır
        let fragmentColor = theme.blockColor(cleared.colorIndex)
        for _ in 0..<5 {
            let side = cellSize * CGFloat.random(in: 0.14...0.26)
            let fragment = SKSpriteNode(color: fragmentColor, size: CGSize(width: side, height: side))
            fragment.position = CGPoint(
                x: center.x + CGFloat.random(in: -cellSize * 0.2...cellSize * 0.2),
                y: center.y + CGFloat.random(in: -cellSize * 0.2...cellSize * 0.2)
            )
            fragment.zPosition = 14
            fragment.alpha = 0
            effectsLayer.addChild(fragment)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = cellSize * CGFloat.random(in: 0.9...1.9)
            let scatter = SKAction.group([
                .moveBy(x: cos(angle) * distance, y: sin(angle) * distance + cellSize * 0.3, duration: 0.45),
                .rotate(byAngle: CGFloat.random(in: -3...3), duration: 0.45),
                .sequence([.fadeIn(withDuration: 0.05), .wait(forDuration: 0.1), .fadeOut(withDuration: 0.3)]),
                .scale(to: 0.3, duration: 0.45)
            ])
            scatter.timingMode = .easeOut
            fragment.run(.sequence([.wait(forDuration: delay + 0.06), scatter, .removeFromParent()]))
        }
    }

    private func clampedToBoard(_ point: CGPoint) -> CGPoint {
        let side = cellSize * CGFloat(boardSize)
        return CGPoint(
            x: min(max(point.x, boardOrigin.x + cellSize), boardOrigin.x + side - cellSize),
            y: min(max(point.y, boardOrigin.y + cellSize), boardOrigin.y + side - cellSize)
        )
    }

    private func showFloatingLabel(_ text: String, at position: CGPoint, fontSize: CGFloat) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = .white
        label.position = position
        label.zPosition = 30
        effectsLayer.addChild(label)

        let rise = SKAction.moveBy(x: 0, y: cellSize * 1.2, duration: 0.8)
        rise.timingMode = .easeOut
        label.run(.sequence([.group([rise, .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
    }
}
