// Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/YokaiConceptPanel.swift
import MoraCore
import MoraEngines
import SwiftUI

struct YokaiConceptPanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let store: BundledYokaiStore?
    let onContinue: () -> Void

    @State private var silhouettesVisible: Bool = false

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.yokaiIntroConceptTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MoraTheme.Space.xl)

            silhouetteRow
                .frame(height: 200)

            Text(strings.yokaiIntroConceptBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MoraTheme.Space.xl)

            Spacer()

            HeroCTA(title: strings.yokaiIntroNext, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if reduceMotion {
                silhouettesVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    silhouettesVisible = true
                }
            }
        }
    }

    @ViewBuilder
    private var silhouetteRow: some View {
        HStack(spacing: MoraTheme.Space.lg) {
            ForEach(catalog, id: \.id) { yokai in
                VStack(spacing: 4) {
                    Text(yokai.ipa)
                        .font(MoraType.label())
                        .foregroundStyle(MoraTheme.Ink.muted)
                    YokaiPortraitCorner(yokai: yokai, sparkleTrigger: nil)
                        .frame(width: 96, height: 96)
                        .opacity(silhouettesVisible ? 1.0 : 0.0)
                }
            }
        }
    }

    private var catalog: [YokaiDefinition] {
        store?.catalog() ?? []
    }
}

#if DEBUG
#Preview {
    YokaiConceptPanel(store: try? BundledYokaiStore(), onContinue: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
