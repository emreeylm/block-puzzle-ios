import SwiftUI
import GameCore

struct MainMenuView: View {
    @Environment(AppModel.self) private var model
    @State private var showLeaderboard = false
    @State private var showGameCenterHint = false

    private var skin: SkinDefinition { model.activeSkin }

    var body: some View {
        ZStack {
            Color(hex: skin.outerBackgroundHex).ignoresSafeArea()

            // Para: sağ üst köşe
            VStack {
                HStack {
                    Spacer()
                    CoinBadge(
                        amount: model.coinBalance,
                        backgroundColor: Color(hex: skin.boardBackgroundHex).opacity(0.75)
                    )
                }
                .padding(.horizontal)
                Spacer()
            }

            VStack(spacing: 28) {
                Spacer()

                // Logo: skin renklerinde blok dizisi + başlık
                HStack(spacing: 8) {
                    ForEach(Array(skin.blockHexes.prefix(4).enumerated()), id: \.offset) { _, hex in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: hex))
                            .frame(width: 34, height: 34)
                    }
                }
                Text("BLOCK PUZZLE")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(skin.textColor)

                statCard(title: "REKOR", value: "\(model.highScore)")

                VStack(spacing: 14) {
                    Button {
                        model.startNewGame()
                    } label: {
                        Text("OYNA")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .frame(maxWidth: 260)
                            .padding(.vertical, 16)
                            .background(Color(hex: skin.blockHexes.first ?? "#E94560"))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    HStack(spacing: 12) {
                        secondaryButton(title: "MAĞAZA", systemImage: "bag.fill") {
                            model.goToStore()
                        }
                        secondaryButton(title: "SIRALAMA", systemImage: "trophy.fill") {
                            if model.gameCenter.isAuthenticated {
                                showLeaderboard = true
                            } else {
                                showGameCenterHint = true
                            }
                        }
                    }
                    .frame(maxWidth: 260)
                }

                Spacer()
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView().ignoresSafeArea()
        }
        .alert("Game Center gerekli", isPresented: $showGameCenterHint) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Sıralamayı görmek için Ayarlar'dan Game Center hesabınla giriş yap.")
        }
    }

    private func secondaryButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(hex: skin.frameHex))
            .foregroundStyle(skin.textColor)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(skin.textColor.opacity(0.6))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(skin.textColor)
        }
        .frame(width: 130)
        .padding(.vertical, 12)
        .background(Color(hex: skin.boardBackgroundHex).opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
