import SwiftUI

/// Shakes the content along the x-axis, driven by an animatable `CGFloat`.
/// Drive by animating `animatableData` 0 → 1; the view offsets follow a
/// sine curve so a single animation cycle produces `count` shakes.
struct Shake: ViewModifier, Animatable {
    var animatableData: CGFloat = 0
    var amplitude: CGFloat = 12
    var count: CGFloat = 3

    func body(content: Content) -> some View {
        content.offset(
            x: animatableData == 0
                ? 0
                : amplitude * sin(animatableData * .pi * count * 2)
        )
    }
}

extension View {
    func shake(amount: CGFloat) -> some View {
        modifier(Shake(animatableData: amount))
    }
}
