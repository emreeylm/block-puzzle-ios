import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            switch model.screen {
            case .menu:
                MainMenuView()
                    .transition(.opacity)
            case .playing:
                GameView()
                    .id(model.gameID)
                    .transition(.opacity)
            case .store:
                StoreView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.screen)
        .task {
            model.gameCenter.authenticate()
        }
    }
}
