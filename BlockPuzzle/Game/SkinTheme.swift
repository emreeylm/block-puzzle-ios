import SpriteKit
import SwiftUI
import GameCore

extension SKColor {
    convenience init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    private var rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    /// Beyaza doğru karıştırır (0...1). Bevel'in aydınlık yüzleri için.
    func lightened(_ amount: CGFloat) -> SKColor {
        let c = rgba
        return SKColor(
            red: c.r + (1 - c.r) * amount,
            green: c.g + (1 - c.g) * amount,
            blue: c.b + (1 - c.b) * amount,
            alpha: c.a
        )
    }

    /// HSB uzayında doygunluk ve parlaklığa çarpan uygular.
    /// Şeker bloğunun doygun kenarı ve açık gövdesi bununla üretilir.
    func adjusted(saturation: CGFloat, brightness: CGFloat) -> SKColor {
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        return SKColor(
            hue: hue,
            saturation: min(1, max(0, sat * saturation)),
            brightness: min(1, max(0, bri * brightness)),
            alpha: alpha
        )
    }

    /// İki rengi karıştırır. ratio 0 = bu renk, 1 = diğer renk.
    func blended(with other: SKColor, ratio: CGFloat) -> SKColor {
        let a = rgba
        let b = other.rgba
        let t = min(1, max(0, ratio))
        return SKColor(
            red: a.r + (b.r - a.r) * t,
            green: a.g + (b.g - a.g) * t,
            blue: a.b + (b.b - a.b) * t,
            alpha: a.a + (b.a - a.a) * t
        )
    }

    /// Siyaha doğru karıştırır (0...1). Bevel'in gölgeli yüzleri için.
    func darkened(_ amount: CGFloat) -> SKColor {
        let c = rgba
        return SKColor(
            red: c.r * (1 - amount),
            green: c.g * (1 - amount),
            blue: c.b * (1 - amount),
            alpha: c.a
        )
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: SKColor(hex: hex))
    }
}

/// Aktif SkinDefinition'ın render katmanı için renklere çevrilmiş hali.
struct SkinTheme {
    let outerBackground: SKColor
    let boardFill: SKColor
    let frame: SKColor
    let emptyCell: SKColor
    let blocks: [SKColor]
    let pattern: BlockPattern
    let frameStyle: FrameStyle
    let gridStyle: GridStyle
    /// Degrade çerçevenin ikinci rengi; skin belirtmezse `frame` ile aynı.
    let frameAccent: SKColor
    let cornerRadiusFactor: CGFloat

    init(_ definition: SkinDefinition) {
        outerBackground = SKColor(hex: definition.outerBackgroundHex)
        boardFill = SKColor(hex: definition.boardBackgroundHex)
        frame = SKColor(hex: definition.frameHex)
        emptyCell = SKColor(hex: definition.emptyCellHex)
        blocks = definition.blockHexes.map { SKColor(hex: $0) }
        pattern = definition.blockPattern
        frameStyle = definition.frameStyle
        gridStyle = definition.gridStyle
        frameAccent = SKColor(hex: definition.frameAccentHex ?? definition.frameHex)
        cornerRadiusFactor = CGFloat(definition.cornerRadiusFactor)
    }

    func blockColor(_ index: Int) -> SKColor {
        guard !blocks.isEmpty else { return .white }
        return blocks[((index % blocks.count) + blocks.count) % blocks.count]
    }
}
