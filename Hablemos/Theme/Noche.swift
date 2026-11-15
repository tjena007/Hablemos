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

enum Noche {
    static let bg = Color(hex: 0x0F1F1C)
    static let navBg = Color(hex: 0x0B1715)
    static let surface = Color(hex: 0x18302B)
    static let surfaceHi = Color(hex: 0x21403A)
    static let surfaceSel = Color(hex: 0x2E4F48)
    static let surfaceMint = Color(hex: 0x1F3F37)
    static let border = Color(hex: 0x2A4842)
    static let borderDashed = Color(hex: 0x3A5650)

    static let text = Color(hex: 0xF3EFE6)
    static let textMuted = Color(hex: 0xA9BDB6)
    static let textSoft = Color(hex: 0xD9E3DF)

    static let saffron = Color(hex: 0xF2A65A)
    static let onSaffron = Color(hex: 0x1A1208)
    static let micRing = Color(hex: 0x3B3020)
    static let mint = Color(hex: 0x7FD4BE)

    static let coralText = Color(hex: 0xFFB59A)
    static let coralSoft = Color(hex: 0xF3D2C2)
    static let coralMuted = Color(hex: 0xE9C9B8)
    static let coralAccent = Color(hex: 0xFF8A65)
    static let coralSurface = Color(hex: 0x3A2418)
    static let coralBorder = Color(hex: 0x8A4A2A)
}

extension Font {
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .title3) -> Font {
        .custom("Space Grotesk", size: size, relativeTo: style).weight(.semibold)
    }
}
