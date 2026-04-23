import MoraCore
import SwiftUI

public enum TilePalette {
    public static func fill(for kind: TileKind) -> Color {
        switch kind {
        case .consonant: return Color(red: 0.859, green: 0.922, blue: 0.996)   // #dbeafe
        case .vowel: return Color(red: 0.996, green: 0.843, blue: 0.678)       // #fed7aa
        case .multigrapheme: return Color(red: 0.851, green: 0.976, blue: 0.616) // #d9f99d
        }
    }

    public static func border(for kind: TileKind) -> Color {
        switch kind {
        case .consonant: return Color(red: 0.576, green: 0.773, blue: 0.953)   // #93c5fd
        case .vowel: return Color(red: 0.984, green: 0.620, blue: 0.251)       // #fb923c
        case .multigrapheme: return Color(red: 0.643, green: 0.902, blue: 0.208) // #a3e635
        }
    }

    public static func text(for kind: TileKind) -> Color {
        switch kind {
        case .consonant: return Color(red: 0.118, green: 0.227, blue: 0.541)   // #1e3a8a
        case .vowel: return Color(red: 0.604, green: 0.204, blue: 0.071)       // #9a3412
        case .multigrapheme: return Color(red: 0.247, green: 0.384, blue: 0.071) // #3f6212
        }
    }
}
