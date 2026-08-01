import Foundation

/// Blok yüzeyine uygulanan desen. Render katmanı bunu doku üretirken çizer.
public enum BlockPattern: String, Equatable {
    case plain
    case dots
    case stripes
    case gem
    /// Parlak jelibon yüzeyi + renkli serpmeler.
    case candy
    /// Işıldayan neon blok: dışa taşan hale + parlak kenarlar.
    case neon
    /// Mat boyalı ahşap karo: damar dokusu + üstte açık, altta koyu kenar.
    case wood
}

/// Tahta çerçevesinin çizim stili.
public enum FrameStyle: String, Equatable {
    case plain
    /// Şeker kamışı: beyaz zemin üzerine çapraz renkli şeritler.
    case candyStripe
    /// İnce çift altın kenarlık.
    case goldTrim
    /// İki renk arasında degrade yapan, dışa ışıyan neon çerçeve.
    case neonGlow
    /// Oyulmuş kalın ahşap çerçeve: damar dokusu ve eğimli kenarlar.
    case woodCarved
}

/// Tahta içindeki boş hücrelerin çizim stili.
public enum GridStyle: String, Equatable {
    /// Boş hücreler dolu kareler olarak çizilir (klasik).
    case filledCells
    /// Yalnızca ince ızgara çizgileri ve kesişim noktaları çizilir.
    case lines
    /// Hücreler ahşap damarlı, hafif oyulmuş kareler olarak çizilir.
    case woodenCells
}

/// Bir görsel temanın veri tanımı. Render katmanı bu tanımı renklere/görsellere çevirir.
/// Yeni skin eklemek = SkinCatalog listesine bir tanım eklemek; başka kod değişmez.
public struct SkinDefinition: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let price: Int
    /// Tahtanın dışında kalan ekran zemini
    public let outerBackgroundHex: String
    /// Tahta içi zemin (hücre aralarındaki çizgiler bu renkte görünür)
    public let boardBackgroundHex: String
    public let frameHex: String
    public let emptyCellHex: String
    public let blockHexes: [String]
    public let blockPattern: BlockPattern
    public let frameStyle: FrameStyle
    public let gridStyle: GridStyle
    /// Degrade çerçeveler için ikinci renk. Verilmezse `frameHex` kullanılır.
    public let frameAccentHex: String?
    /// Hücre ve blokların köşe yuvarlaklığı (hücre boyutunun oranı).
    /// 0.05 = klasik köşeli görünüm, 0.26 = yumuşak şeker görünümü.
    public let cornerRadiusFactor: Double

    public init(
        id: String,
        name: String,
        price: Int,
        outerBackgroundHex: String,
        boardBackgroundHex: String,
        frameHex: String,
        emptyCellHex: String,
        blockHexes: [String],
        blockPattern: BlockPattern = .plain,
        frameStyle: FrameStyle = .plain,
        gridStyle: GridStyle = .filledCells,
        frameAccentHex: String? = nil,
        cornerRadiusFactor: Double = 0.05
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.outerBackgroundHex = outerBackgroundHex
        self.boardBackgroundHex = boardBackgroundHex
        self.frameHex = frameHex
        self.emptyCellHex = emptyCellHex
        self.blockHexes = blockHexes
        self.blockPattern = blockPattern
        self.frameStyle = frameStyle
        self.gridStyle = gridStyle
        self.frameAccentHex = frameAccentHex
        self.cornerRadiusFactor = cornerRadiusFactor
    }

    /// Tek renk skin üretme kısayolu: tüm bloklar aynı renk.
    static func monochrome(
        id: String,
        name: String,
        price: Int,
        blockHex: String,
        outerBackgroundHex: String,
        boardBackgroundHex: String,
        frameHex: String,
        emptyCellHex: String
    ) -> SkinDefinition {
        SkinDefinition(
            id: id,
            name: name,
            price: price,
            outerBackgroundHex: outerBackgroundHex,
            boardBackgroundHex: boardBackgroundHex,
            frameHex: frameHex,
            emptyCellHex: emptyCellHex,
            blockHexes: Array(repeating: blockHex, count: 6)
        )
    }
}

public enum SkinCatalog {
    public static let defaultSkinID = "classic"

    public static let all: [SkinDefinition] = [
        SkinDefinition(
            id: "classic",
            name: "Klasik",
            price: 0,
            outerBackgroundHex: "#4E6BC8",
            boardBackgroundHex: "#151E4E",
            frameHex: "#101740",
            emptyCellHex: "#1C2758",
            blockHexes: ["#E8393B", "#FF8C1A", "#FFC93C", "#3BC43B", "#3F6BE8", "#9C4FE0"]
        ),
        SkinDefinition(
            id: "candy",
            name: "Şeker",
            price: 150,
            outerBackgroundHex: "#FBD9E6",
            boardBackgroundHex: "#F5B9D0",
            frameHex: "#F06FA3",
            emptyCellHex: "#F9CCDD",
            blockHexes: ["#FF7BAC", "#7FC9F5", "#FFD673", "#8FE3A4", "#C4A0F2", "#FFA277"],
            blockPattern: .candy,
            frameStyle: .candyStripe,
            cornerRadiusFactor: 0.26
        ),
        SkinDefinition(
            id: "neon",
            name: "Neon",
            price: 250,
            outerBackgroundHex: "#04030C",
            boardBackgroundHex: "#08061A",
            frameHex: "#00E0FF",
            emptyCellHex: "#2C2166",
            blockHexes: ["#00E0FF", "#FF2BD6", "#7B5CFF", "#00FF9D", "#FFE93D", "#FF6B4A"],
            blockPattern: .neon,
            frameStyle: .neonGlow,
            gridStyle: .lines,
            frameAccentHex: "#FF2BD6",
            cornerRadiusFactor: 0.1
        ),
        SkinDefinition(
            id: "wood",
            name: "Ahşap",
            price: 400,
            outerBackgroundHex: "#4A2E1B",
            boardBackgroundHex: "#2A1A10",
            frameHex: "#8A5A32",
            emptyCellHex: "#3A2416",
            blockHexes: ["#E3A33C", "#8DC63F", "#E4703A", "#C0453A", "#4FA3A5", "#D8C57C"],
            blockPattern: .wood,
            frameStyle: .woodCarved,
            gridStyle: .woodenCells,
            cornerRadiusFactor: 0.18
        ),
        SkinDefinition(
            id: "midnight",
            name: "Gece Yarısı",
            price: 600,
            outerBackgroundHex: "#0A1128",
            boardBackgroundHex: "#0B1631",
            frameHex: "#C9A44C",
            emptyCellHex: "#101F3D",
            blockHexes: ["#8A5CF0", "#4A7BE8", "#A374F5", "#3F62C8", "#5FD3E0", "#E0699F"],
            blockPattern: .gem,
            frameStyle: .goldTrim,
            cornerRadiusFactor: 0.12
        ),

        // Tek renk skinler — tüm bloklar aynı renk (150 coin)
        .monochrome(
            id: "mono-red", name: "Kırmızı", price: 150,
            blockHex: "#E8393B",
            outerBackgroundHex: "#A94446", boardBackgroundHex: "#331114",
            frameHex: "#230A0D", emptyCellHex: "#411A1E"
        ),
        .monochrome(
            id: "mono-orange", name: "Turuncu", price: 150,
            blockHex: "#FF8C1A",
            outerBackgroundHex: "#C07A3A", boardBackgroundHex: "#37200C",
            frameHex: "#251506", emptyCellHex: "#442B13"
        ),
        .monochrome(
            id: "mono-yellow", name: "Sarı", price: 150,
            blockHex: "#FFC93C",
            outerBackgroundHex: "#BFA23B", boardBackgroundHex: "#352D0C",
            frameHex: "#231E06", emptyCellHex: "#423913"
        ),
        .monochrome(
            id: "mono-green", name: "Yeşil", price: 150,
            blockHex: "#3BC43B",
            outerBackgroundHex: "#4F9C50", boardBackgroundHex: "#12300F",
            frameHex: "#0A2008", emptyCellHex: "#1A3D16"
        ),
        .monochrome(
            id: "mono-blue", name: "Mavi", price: 150,
            blockHex: "#3F6BE8",
            outerBackgroundHex: "#4E6BC8", boardBackgroundHex: "#151E4E",
            frameHex: "#101740", emptyCellHex: "#1C2758"
        ),
        .monochrome(
            id: "mono-purple", name: "Mor", price: 150,
            blockHex: "#9C4FE0",
            outerBackgroundHex: "#8A5BC8", boardBackgroundHex: "#251238",
            frameHex: "#190A28", emptyCellHex: "#301A45"
        ),

        // Desenli premium skinler
        SkinDefinition(
            id: "dots",
            name: "Puantiye",
            price: 750,
            outerBackgroundHex: "#3FA98C",
            boardBackgroundHex: "#0E2C24",
            frameHex: "#081E18",
            emptyCellHex: "#153A30",
            blockHexes: ["#E8393B", "#FF8C1A", "#FFC93C", "#3BC43B", "#3F6BE8", "#9C4FE0"],
            blockPattern: .dots
        ),
        SkinDefinition(
            id: "stripes",
            name: "Çizgili",
            price: 750,
            outerBackgroundHex: "#C8804E",
            boardBackgroundHex: "#33200F",
            frameHex: "#241608",
            emptyCellHex: "#402A16",
            blockHexes: ["#E8393B", "#FF8C1A", "#FFC93C", "#3BC43B", "#3F6BE8", "#9C4FE0"],
            blockPattern: .stripes
        ),
        SkinDefinition(
            id: "gem",
            name: "Mücevher",
            price: 1000,
            outerBackgroundHex: "#43436E",
            boardBackgroundHex: "#131328",
            frameHex: "#0C0C1C",
            emptyCellHex: "#1B1B38",
            blockHexes: ["#E0115F", "#FF7F11", "#FFD700", "#50C878", "#0F52BA", "#9966CC"],
            blockPattern: .gem
        )
    ]

}

public enum PurchaseResult: Equatable {
    case success
    case alreadyOwned
    case insufficientFunds
    case notFound
}

/// Sahip olunan ve aktif skin'i yönetir; satın almalar cüzdandan geçer.
public final class SkinManager {
    private static let ownedKey = "skins.owned"
    private static let activeKey = "skins.active"

    public let catalog: [SkinDefinition]
    private let store: UserDefaults
    private let wallet: Wallet

    public private(set) var ownedIDs: Set<String>
    public private(set) var activeSkinID: String

    public init(store: UserDefaults, wallet: Wallet, catalog: [SkinDefinition] = SkinCatalog.all) {
        self.store = store
        self.wallet = wallet
        self.catalog = catalog

        let owned = Set(store.stringArray(forKey: SkinManager.ownedKey) ?? [])
        self.ownedIDs = owned.union([SkinCatalog.defaultSkinID])

        let active = store.string(forKey: SkinManager.activeKey) ?? SkinCatalog.defaultSkinID
        self.activeSkinID = self.ownedIDs.contains(active) ? active : SkinCatalog.defaultSkinID
    }

    public var activeSkin: SkinDefinition {
        catalog.first { $0.id == activeSkinID }
            ?? catalog.first { $0.id == SkinCatalog.defaultSkinID }
            ?? catalog[0]
    }

    public func isOwned(_ id: String) -> Bool {
        ownedIDs.contains(id)
    }

    @discardableResult
    public func purchase(_ id: String) -> PurchaseResult {
        guard let skin = catalog.first(where: { $0.id == id }) else { return .notFound }
        guard !isOwned(id) else { return .alreadyOwned }
        guard wallet.spend(skin.price) else { return .insufficientFunds }
        ownedIDs.insert(id)
        persist()
        return .success
    }

    /// Yalnızca sahip olunan skin aktifleştirilebilir.
    @discardableResult
    public func activate(_ id: String) -> Bool {
        guard isOwned(id), catalog.contains(where: { $0.id == id }) else { return false }
        activeSkinID = id
        persist()
        return true
    }

    private func persist() {
        store.set(Array(ownedIDs).sorted(), forKey: SkinManager.ownedKey)
        store.set(activeSkinID, forKey: SkinManager.activeKey)
    }
}
