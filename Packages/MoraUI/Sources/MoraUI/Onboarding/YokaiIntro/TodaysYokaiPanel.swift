// Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/TodaysYokaiPanel.swift
import MoraCore
import MoraEngines
import SwiftUI

struct TodaysYokaiPanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let store: BundledYokaiStore?
    let player: any YokaiClipPlayer
    let onContinue: () -> Void

    @State private var portraitScale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.yokaiIntroTodayTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            if let yokai = activeYokai {
                portraitColumn(yokai: yokai)
            } else {
                Color.clear.frame(height: 240)
            }

            Text(strings.yokaiIntroTodayBody)
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
            playGreetClip()
            if reduceMotion {
                portraitScale = 1.0
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    portraitScale = 1.0
                }
            }
        }
        .onDisappear {
            player.stop()
        }
    }

    @ViewBuilder
    private func portraitColumn(yokai: YokaiDefinition) -> some View {
        VStack(spacing: MoraTheme.Space.sm) {
            YokaiPortraitCorner(yokai: yokai, sparkleTrigger: nil)
                .frame(width: 200, height: 200)
                .scaleEffect(portraitScale)
            Text(yokai.grapheme)
                .font(MoraType.heroWord(72))
                .foregroundStyle(MoraTheme.Ink.primary)
            Text(yokai.ipa)
                .font(MoraType.subtitle())
                .foregroundStyle(MoraTheme.Ink.secondary)
        }
    }

    private var activeYokai: YokaiDefinition? {
        guard let store else { return nil }
        let firstYokaiID = CurriculumEngine.sharedV1.skills.first?.yokaiID
        return store.catalog().first { $0.id == firstYokaiID }
    }

    private func playGreetClip() {
        guard let yokai = activeYokai,
            let url = store?.voiceClipURL(for: yokai.id, clip: .greet)
        else { return }
        _ = player.play(url: url)
    }
}

#if DEBUG
#Preview {
    TodaysYokaiPanel(
        store: try? BundledYokaiStore(),
        player: AVFoundationYokaiClipPlayer(),
        onContinue: {}
    )
    .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
