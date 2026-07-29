# Block Puzzle

8×8 ızgara üzerinde oynanan blok bulmaca oyunu. iOS için Swift ile yazıldı: oyun sahnesi SpriteKit, arayüz SwiftUI.

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B-000000?style=flat-square" alt="iOS 17+">
  <img src="https://img.shields.io/badge/Swift-5.10-F05138?style=flat-square" alt="Swift 5.10">
  <img src="https://img.shields.io/badge/tests-53%20passing-2EA043?style=flat-square" alt="53 test">
  <img src="https://img.shields.io/badge/dependencies-0-0969DA?style=flat-square" alt="Sıfır bağımlılık">
</p>

---

## Oyun

Her turda elinize üç parça gelir; bunları ızgaraya yerleştirirsiniz. Bir satır veya sütun tamamen dolduğunda patlar ve puan kazandırır. Tetris'ten farkı: parçalar düşmez, yerçekimi yoktur, döndürme yoktur — yalnızca konumlandırma vardır. Elinizdeki parçaların hiçbiri tahtaya sığmadığında oyun biter.

**Puanlama**

| Olay | Puan |
|---|---|
| Parça yerleştirme | hücre başına 1 |
| Satır/sütun temizleme | `10 × satırSayısı² × komboSerisi` |

Aynı hamlede iki çizgi patlatmak 40 puan (10 × 2²), üst üste patlatmak ise seriyi katlar. Kombo zinciri, temizleme yapmayan bir hamlede sıfırlanır.

**Ekonomi**

- Oyun sonunda her 50 puan → 1 coin
- Her kombo patlatması (üst üste 2. temizlemeden itibaren) → anında +5 coin
- Coinler mağazadaki 14 skin'i açmak için kullanılır

## Zorluk eğrisi

Oyun ilk dakikalarda cömerttir, skor yükseldikçe sertleşir. Dört mekanik skorla birlikte kayar (`DifficultyCurve`, 0 → 6000 puan aralığında):

| Mekanik | Başlangıç | Tavan |
|---|---|---|
| Ele patlatmaya hazır parça ekleme | %85 | %6 |
| Büyük parçanın geometrik eşini verme | %100 | %35 |
| Zor (5+ hücreli) parça ağırlığı | 0.10× | 1.6× |
| El garantisi | 3 parça da sığar | 1 parça sığar |

Ölçülen parça dağılımı: açılışta parçaların **%81'i orta boy** (3–4 hücre) ve yalnızca %6'sı dev; sonda dev parça oranı **%50'ye** çıkar.

İki mekanik oyuncuya görünmez şekilde yardım eder:

- **Kombo yardımcısı** — elde çizgi tamamlayabilecek parça yoksa, şans tutarsa bir tane eklenir
- **Uyum** — ele büyük bir parça düştüğünde geometrik eşi de gelir (büyük L + 2×2 = tam 3×3; 5'li çizgi + 3'lü çizgi = tam satır). Eş parça tahtaya sığmıyorsa mekanik devreye girmez, aksi halde oynanabilir bir parçanın üzerine yazıp oyunu haksız yere bitirebilir.

Ayrıca her el yenilendiğinde motor **en az bir parçanın sığdığını garanti eder**; sıkışık tahtada gerekirse ele sığabilen en küçük parça konur. Oyun ancak gerçekten hamle kalmadığında biter.

## Mimari

Oyun mantığı arayüzden tamamen ayrıdır. `GameCore` saf bir Swift paketidir — SpriteKit, SwiftUI veya UIKit içermez, dolayısıyla tamamı birim testiyle kaplanabilir.

```
┌──────────────────────────────────────────────────────┐
│  SwiftUI            ana menü · mağaza · oyun sonu    │
│                     HUD · liderlik tablosu           │
├──────────────────────────────────────────────────────┤
│  SpriteKit          ızgara · sürükle-bırak · patlama │
│  (GameScene)        efektleri · kombo animasyonu     │
├──────────────────────────────────────────────────────┤
│  AppModel           @Observable köprü: çekirdeğin    │
│                     durumunu SwiftUI'a aynalar       │
├══════════════════════════════════════════════════════┤
│  GameCore  (saf Swift, arayüzden bağımsız)           │
│                                                      │
│    GameEngine      oturum: el, skor, kombo, bitiş    │
│    GameBoard       ızgara, yerleştirme, temizleme    │
│    PieceGenerator  ağırlıklı parça üretimi           │
│    DifficultyCurve zorluk ilerlemesi                 │
│    Wallet          coin bakiyesi                     │
│    SkinManager     sahiplik, satın alma, aktif skin  │
└──────────────────────────────────────────────────────┘
```

**Tasarım kararları**

- **Çekirdek arayüz bilmez.** `GameBoard` bir değer tipidir, `GameEngine` yalnızca saf fonksiyonlarla çalışır. Kombo mantığındaki bir hata elle oynanarak değil testle yakalanır.
- **Skinler veridir, kod değil.** Her skin bir `SkinDefinition`: renkler, blok deseni, çerçeve stili, ızgara stili, köşe yuvarlaklığı ve fiyat. Yeni skin eklemek kataloğa bir kayıt eklemektir; render katmanı değişmez.
- **Blok görselleri çalışma anında üretilir.** Bevel, şeker, neon ve mücevher stilleri Core Graphics ile çizilip renk başına bir kez önbelleğe alınır — projede tek bir blok görseli (PNG) yoktur.
- **Sıfır üçüncü parti bağımlılık.**
- **Zorluk dengesi tek dosyada.** Oyunu kolaylaştırmak veya sertleştirmek `DifficultyCurve` içindeki sekiz sayıyı değiştirmektir.

## Skinler

Mağazada 14 skin var; üç kategoriye ayrılır.

| Kategori | Skinler | Fiyat |
|---|---|---|
| Temalar | Klasik · Şeker · Neon · Ahşap · Gece Yarısı | 0 – 600 |
| Tek renk | Kırmızı · Turuncu · Sarı · Yeşil · Mavi · Mor | 150 |
| Desenli | Puantiye · Çizgili · Mücevher | 750 – 1000 |

Skin yalnızca blok renklerini değil, tahtanın tamamını değiştirir: Şeker skini şeker kamışı çizgili çerçeve ve serpmeli jelibon bloklar kullanır; Neon skini camgöbeğinden magentaya degrade yapan ışıyan çerçeve, ince ızgara çizgileri ve içi boş neon tüp bloklar; Gece Yarısı ise altın kenarlık ve fasetli mücevher bloklar.

## Kurulum

**Gereksinimler:** Xcode 16+, iOS 17+ hedefi, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

Xcode projesi sürüm kontrolünde tutulmaz; `project.yml`den üretilir. Bu, `.xcodeproj` birleştirme çakışmalarını ortadan kaldırır.

```bash
brew install xcodegen
git clone https://github.com/emreeylm/block-puzzle-ios.git
cd block-puzzle-ios
xcodegen generate
open BlockPuzzle.xcodeproj
```

Dosya ekleyip çıkardıktan sonra `xcodegen generate` komutunu yeniden çalıştırın.

### Testler

```bash
cd GameCore && swift test
```

53 test; tahta mantığı, puanlama, kombo, ekonomi, skin sahipliği, parça dağılımı ve zorluk eğrisini kapsar. Testler Xcode gerektirmez — komut satırında saniyeler içinde çalışır.

### Geliştirme kısayolları

Uygulama DEBUG derlemesinde şu başlatma argümanlarını tanır:

| Argüman | Etki |
|---|---|
| `-autostart` | Menüyü atlayıp doğrudan oyunu başlatır |
| `-store` | Mağaza ekranını açar |
| `-coins 5000` | Cüzdana coin ekler |

Xcode'da `Product → Scheme → Edit Scheme → Run → Arguments` altından eklenir. Yalnızca DEBUG derlemesinde derlenir, yayın sürümüne girmez.

## Proje yapısı

```
├── project.yml               XcodeGen tanımı
├── GameCore/                 Saf Swift paketi (oyun mantığı)
│   ├── Sources/GameCore/
│   │   ├── GameBoard.swift     ızgara, yerleştirme, çizgi temizleme
│   │   ├── GameEngine.swift    oturum durumu, skor, kombo, oyun sonu
│   │   ├── Piece.swift         25 parça şekli ve tamamlayıcı eşleşmeleri
│   │   ├── Random.swift        tohumlanabilir RNG + ağırlıklı üretim
│   │   ├── Difficulty.swift    zorluk eğrisi
│   │   ├── Economy.swift       coin dönüşümü ve cüzdan
│   │   └── Skins.swift         skin kataloğu ve satın alma
│   └── Tests/GameCoreTests/
└── BlockPuzzle/              iOS uygulaması
    ├── App/                    giriş noktası, AppModel
    ├── Game/                   GameScene, SkinTheme
    ├── UI/                     SwiftUI ekranları
    └── Services/               Game Center
```

## Liderlik tablosu

Liderlik tablosu **Game Center** üzerinden çalışır; sunucu gerektirmez. Skorlar oyun sonunda otomatik gönderilir. Game Center oturumu yoksa gönderim sessizce atlanır — oyun akışı buna bağımlı değildir.

Yayına almadan önce iki adım gerekir:

1. App Store Connect → Game Center → liderlik tablosu oluştur, kimliği `GameCenterManager.highScoreLeaderboardID` ile birebir aynı olmalı
2. Game Center yetkilendirmesi ücretli Apple Developer hesabı gerektirir. Ücretsiz provizyonla cihaza kurmak için `project.yml` içindeki `CODE_SIGN_ENTITLEMENTS` satırı geçici olarak kaldırılabilir; oyun çalışır, yalnızca Game Center devre dışı kalır.

## Yol haritası

- [ ] Özgün isim ve marka — mevcut isim geçicidir
- [ ] App icon
- [ ] Ses efektleri
- [ ] iCloud ile ilerleme senkronizasyonu (`NSUbiquitousKeyValueStore`)
- [ ] Ödüllü reklamla coin kazanma
- [ ] TestFlight ve App Store yayını
