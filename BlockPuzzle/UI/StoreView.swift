import SwiftUI
import GameCore

struct StoreView: View {
    @Environment(AppModel.self) private var model

    private var skin: SkinDefinition { model.activeSkin }

    var body: some View {
        ZStack {
            Color(hex: skin.outerBackgroundHex).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        section(title: "TEMALAR", skins: themedSkins)
                        section(title: "TEK RENK", skins: monochromeSkins)
                        section(title: "DESENLİ", skins: patternedSkins)
                    }
                    .padding()
                }
            }
        }
    }

    private var monochromeSkins: [SkinDefinition] {
        model.skins.catalog.filter { Set($0.blockHexes).count == 1 }
    }

    private var patternedSkins: [SkinDefinition] {
        model.skins.catalog.filter { $0.blockPattern != .plain }
    }

    private var themedSkins: [SkinDefinition] {
        model.skins.catalog.filter { Set($0.blockHexes).count > 1 && $0.blockPattern == .plain }
    }

    @ViewBuilder
    private func section(title: String, skins: [SkinDefinition]) -> some View {
        if !skins.isEmpty {
            Text(title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 6)
            ForEach(skins) { item in
                SkinRow(skin: item)
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                model.goToMenu()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(10)
                    .background(Color(hex: skin.boardBackgroundHex).opacity(0.6))
                    .clipShape(Circle())
            }

            Spacer()

            Text("MAĞAZA")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            CoinBadge(
                amount: model.coinBalance,
                backgroundColor: Color(hex: skin.boardBackgroundHex).opacity(0.6)
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct SkinRow: View {
    @Environment(AppModel.self) private var model
    let skin: SkinDefinition

    private var isOwned: Bool { model.ownedSkinIDs.contains(skin.id) }
    private var isActive: Bool { model.activeSkinID == skin.id }
    private var canAfford: Bool { model.coinBalance >= skin.price }

    var body: some View {
        HStack(spacing: 14) {
            // Skin önizlemesi: çerçeve rengi içinde blok paleti
            HStack(spacing: 3) {
                ForEach(Array(skin.blockHexes.prefix(6).enumerated()), id: \.offset) { _, hex in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: hex))
                        .frame(width: 14, height: 14)
                }
            }
            .padding(10)
            .background(Color(hex: skin.boardBackgroundHex))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: skin.frameHex), lineWidth: 2.5)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(skin.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if !isOwned {
                    HStack(spacing: 4) {
                        CoinIcon(size: 13)
                        Text("\(skin.price)")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()

            actionButton
        }
        .padding(14)
        .background(Color(hex: model.activeSkin.boardBackgroundHex).opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var actionButton: some View {
        if isActive {
            Text("Seçili")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
        } else if isOwned {
            Button {
                model.selectSkin(skin.id)
            } label: {
                Text("Kullan")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color(hex: model.activeSkin.frameHex))
                    .clipShape(Capsule())
            }
        } else {
            Button {
                model.buySkin(skin.id)
            } label: {
                Text("Satın Al")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        canAfford
                            ? Color(hex: model.activeSkin.blockHexes.first ?? "#E94560")
                            : Color.gray.opacity(0.4)
                    )
                    .clipShape(Capsule())
            }
            .disabled(!canAfford)
        }
    }
}
