import SwiftUI

/// Altın para ikonu: degrade dolgu + koyu altın kenar + iç halka.
struct CoinIcon: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FFE066"), Color(hex: "#F2A916")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(Color(hex: "#C98A00"), lineWidth: size * 0.09)
            Circle()
                .strokeBorder(Color(hex: "#FFF3B0").opacity(0.9), lineWidth: size * 0.06)
                .padding(size * 0.18)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
    }
}

/// Para ikonu + miktar rozeti (HUD ve mağaza başlıkları için).
struct CoinBadge: View {
    let amount: Int
    var backgroundColor: Color

    var body: some View {
        HStack(spacing: 5) {
            CoinIcon(size: 18)
            Text("\(amount)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.snappy, value: amount)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .clipShape(Capsule())
    }
}
