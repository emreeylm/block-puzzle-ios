import SwiftUI
import SpriteKit
import GameCore

struct GameView: View {
    @Environment(AppModel.self) private var model
    @State private var scene: GameScene?

    private var skin: SkinDefinition { model.activeSkin }

    var body: some View {
        ZStack {
            Color(hex: skin.outerBackgroundHex).ignoresSafeArea()

            VStack(spacing: 0) {
                hud
                Group {
                    if let scene {
                        SpriteView(scene: scene)
                    } else {
                        Color.clear
                    }
                }
            }

            if model.isGameOver {
                gameOverOverlay
            }
        }
        .onAppear {
            if scene == nil {
                scene = GameScene(model: model)
            }
        }
    }

    private var hud: some View {
        HStack {
            Button {
                model.goToMenu()
            } label: {
                Image(systemName: "house.fill")
                    .font(.title3)
                    .foregroundStyle(skin.textColor.opacity(0.8))
                    .padding(10)
                    .background(Color(hex: skin.boardBackgroundHex).opacity(0.6))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(model.score)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(skin.textColor)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.score)
                Text("REKOR \(model.highScore)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(skin.textColor.opacity(0.55))
            }

            Spacer()

            CoinBadge(
                amount: model.coinBalance,
                backgroundColor: Color(hex: skin.boardBackgroundHex).opacity(0.6)
            )
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Oyun Bitti!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(skin.textColor)

                if model.isNewHighScore {
                    Text("🏆 Yeni Rekor!")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: skin.blockHexes.count > 2 ? skin.blockHexes[2] : "#FFD460"))
                }

                VStack(spacing: 6) {
                    Text("Skor: \(model.score)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(skin.textColor)
                    HStack(spacing: 6) {
                        Text("+\(model.lastEarnedCoins)")
                        CoinIcon(size: 17)
                        Text("kazandın")
                    }
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(skin.textColor.opacity(0.85))
                }

                VStack(spacing: 12) {
                    Button {
                        model.startNewGame()
                    } label: {
                        Text("Tekrar Oyna")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .frame(maxWidth: 220)
                            .padding(.vertical, 14)
                            .background(Color(hex: skin.blockHexes.first ?? "#E94560"))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        model.goToMenu()
                    } label: {
                        Text("Ana Menü")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .frame(maxWidth: 220)
                            .padding(.vertical, 12)
                            .background(Color(hex: skin.frameHex))
                            .foregroundStyle(skin.textColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.top, 6)
            }
            .padding(28)
            .background(Color(hex: skin.boardBackgroundHex))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(hex: skin.frameHex), lineWidth: 3)
            )
            .padding(.horizontal, 32)
        }
    }
}
