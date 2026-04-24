import MoraCore
import MoraEngines
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct YokaiPortraitCorner: View {
    let yokai: YokaiDefinition
    @State private var pulse: Bool = false

    public init(yokai: YokaiDefinition) { self.yokai = yokai }

    public var body: some View {
        #if canImport(UIKit)
        if let store = try? BundledYokaiStore(),
            let url = store.portraitURL(for: yokai.id),
            let uiImage = UIImage(contentsOfFile: url.path)
        {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(Circle())
                .scaleEffect(pulse ? 1.02 : 1.0)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulse
                )
                .onAppear { pulse = true }
                .accessibilityLabel(Text("\(yokai.grapheme) yokai"))
        } else {
            fallback
        }
        #else
        fallback
        #endif
    }

    private var fallback: some View {
        Circle()
            .fill(Color(white: 0.85))
            .overlay(Text(yokai.grapheme).font(.title2).fontWeight(.bold))
            .accessibilityLabel(Text("\(yokai.grapheme) yokai"))
    }
}
