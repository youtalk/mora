import SwiftUI

public enum MoraTheme {
    public enum Background {
        public static let pageHex: UInt32 = 0xFFFBF5
        public static let creamHex: UInt32 = 0xFFE8D6
        public static let peachHex: UInt32 = 0xFFCFA5
        public static let mintHex:  UInt32 = 0xD5F0EA

        public static let page = Color(hex: pageHex)
        public static let cream = Color(hex: creamHex)
        public static let peach = Color(hex: peachHex)
        public static let mint = Color(hex: mintHex)
    }
    public enum Accent {
        public static let orangeHex: UInt32 = 0xFF7A00
        public static let orangeShadowHex: UInt32 = 0xC85800
        public static let tealHex: UInt32 = 0x00A896
        public static let tealShadowHex: UInt32 = 0x007F73

        public static let orange = Color(hex: orangeHex)
        public static let orangeShadow = Color(hex: orangeShadowHex)
        public static let teal = Color(hex: tealHex)
        public static let tealShadow = Color(hex: tealShadowHex)
    }
    public enum Ink {
        public static let primaryHex: UInt32 = 0x2A1E13
        public static let secondaryHex: UInt32 = 0x8A7453
        public static let mutedHex: UInt32 = 0x888888

        public static let primary = Color(hex: primaryHex)
        public static let secondary = Color(hex: secondaryHex)
        public static let muted = Color(hex: mutedHex)
    }
    public enum Feedback {
        public static let correct = Color(hex: 0x00A896)
        public static let wrong   = Color(hex: 0xFF7A00)
    }
    public enum Space {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }
    public enum Radius {
        public static let button: CGFloat = 999
        public static let card: CGFloat = 22
        public static let chip: CGFloat = 999
        public static let tile: CGFloat = 14
    }
}

public extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
