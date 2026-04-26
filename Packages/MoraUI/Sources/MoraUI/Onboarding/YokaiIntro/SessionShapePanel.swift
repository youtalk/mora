// Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/SessionShapePanel.swift
import MoraCore
import SwiftUI

struct SessionShapePanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onContinue: () -> Void

    @State private var stepsVisible: [Bool] = [false, false, false]

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.yokaiIntroSessionTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)

            stepsRow
                .frame(height: 180)
                .padding(.horizontal, MoraTheme.Space.lg)

            Text(strings.yokaiIntroSessionBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            HeroCTA(title: strings.yokaiIntroNext, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await animateSteps()
        }
    }

    private var stepsRow: some View {
        HStack(spacing: MoraTheme.Space.md) {
            stepIcon(emoji: "🎧", label: strings.yokaiIntroSessionStep1, index: 0)
            arrow
            stepIcon(emoji: "🟦", label: strings.yokaiIntroSessionStep2, index: 1)
            arrow
            stepIcon(emoji: "🗣️", label: strings.yokaiIntroSessionStep3, index: 2)
        }
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(MoraTheme.Ink.muted)
    }

    private func stepIcon(emoji: String, label: String, index: Int) -> some View {
        VStack(spacing: MoraTheme.Space.sm) {
            Text(emoji).font(.system(size: 56))
            Text(label)
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.primary)
        }
        .opacity(stepsVisible[index] ? 1.0 : 0.0)
        .scaleEffect(stepsVisible[index] ? 1.0 : 0.85)
    }

    @MainActor
    private func animateSteps() async {
        if reduceMotion {
            stepsVisible = [true, true, true]
            return
        }
        for i in 0..<3 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                stepsVisible[i] = true
            }
            try? await Task.sleep(for: .milliseconds(120))
        }
    }
}

#if DEBUG
#Preview {
    SessionShapePanel(onContinue: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
