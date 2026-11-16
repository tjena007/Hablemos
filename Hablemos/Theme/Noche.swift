import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Wine = Lucía and primary actions, teal = you and things you got right, amber = misses.
/// Misses stay amber so they never read as the brand pink.
enum Noche {
    static let bg = Color(hex: 0x0E0F13)
    static let navBg = Color(hex: 0x121318)
    static let surface = Color(hex: 0x181A20)
    static let surfaceHi = Color(hex: 0x1B1D24)
    static let surfaceSel = Color(hex: 0x2A2D36)
    static let surfaceMint = Color(hex: 0x12211F)
    static let border = Color(hex: 0x22242C)
    static let borderDashed = Color(hex: 0x4A4D57)

    static let text = Color(hex: 0xF3F1EC)
    static let textMuted = Color(hex: 0x9A9CA6)
    static let textSoft = Color(hex: 0xB9BBC4)

    static let brand = Color(hex: 0x8E2440)
    static let onBrand = Color(hex: 0xFFF4F8)
    static let brandText = Color(hex: 0xCF6E84)
    static let brandSurface = Color(hex: 0x26141A)
    static let brandBorder = Color(hex: 0x4A1C28)
    static let micRing = Color(hex: 0x26141A)
    static let mint = Color(hex: 0x5ED3C3)
    static let onMint = Color(hex: 0x06201D)

    static let missText = Color(hex: 0xFFC266)
    static let missSoft = Color(hex: 0xFFE2B0)
    static let missMuted = Color(hex: 0xE8CFA0)
    static let missAccent = Color(hex: 0xFFB13D)
    static let missSurface = Color(hex: 0x241C10)
    static let missBorder = Color(hex: 0x6B5321)
}

extension Font {
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .title3) -> Font {
        .custom("Bricolage Grotesque", size: size, relativeTo: style).weight(.bold)
    }
}
