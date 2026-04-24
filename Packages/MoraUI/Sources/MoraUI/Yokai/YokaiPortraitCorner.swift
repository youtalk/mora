import MoraCore
import MoraEngines
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct YokaiPortraitCorner: View {
    let yokai: YokaiDefinition
    let sparkleTrigger: AnyHashable?
    let sparkleEnabled: Bool
    @State private var pulse: Bool = false
    @State private var store: BundledYokaiStore?
    #if canImport(UIKit)
    @State private var image: UIImage?
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(yokai: YokaiDefinition) {
        self.yokai = yokai
        self.sparkleTrigger = nil
        self.sparkleEnabled = false
    }

    public init(yokai: YokaiDefinition, sparkleTrigger: AnyHashable?) {
        self.yokai = yokai
        self.sparkleTrigger = sparkleTrigger
        self.sparkleEnabled = true
    }

    public var body: some View {
        content
            .overlay {
                if sparkleEnabled {
                    SparkleOverlay(trigger: sparkleTrigger).allowsHitTesting(false)
                }
            }
            .onAppear {
                if store == nil { store = try? BundledYokaiStore() }
                #if canImport(UIKit)
                if image == nil,
                    let url = store?.portraitURL(for: yokai.id)
                {
                    image = UIImage(contentsOfFile: url.path)
                }
                #endif
            }
    }

    @ViewBuilder
    private var content: some View {
        #if canImport(UIKit)
        if let uiImage = image {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(Circle())
                .scaleEffect(reduceMotion ? 1.0 : (pulse ? 1.02 : 1.0))
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: pulse
                )
                .onAppear { if !reduceMotion { pulse = true } }
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
