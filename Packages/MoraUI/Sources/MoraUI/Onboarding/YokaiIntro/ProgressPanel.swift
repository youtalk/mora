// Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/ProgressPanel.swift
import MoraCore
import MoraEngines
import SwiftUI

struct ProgressPanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let store: BundledYokaiStore?
    let mode: OnboardingPlayMode
    let onContinue: () -> Void

    @State private var dotsLit: [Bool] = Array(repeating: false, count: 5)

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.yokaiIntroProgressTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            dotsRow
                .frame(height: 140)
                .padding(.horizontal, MoraTheme.Space.lg)

            Text(strings.yokaiIntroProgressBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MoraTheme.Space.xl)

            Spacer()

            HeroCTA(title: ctaTitle, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await animateDots()
        }
    }

    private var ctaTitle: String {
        switch mode {
        case .firstTime: return strings.yokaiIntroBegin
        case .replay: return strings.yokaiIntroClose
        }
    }

    private var dotsRow: some View {
        HStack(spacing: MoraTheme.Space.md) {
            ForEach(0..<5) { index in
                dotView(index: index)
            }
        }
    }

    @ViewBuilder
    private func dotView(index: Int) -> some View {
        let lit = dotsLit[index]
        let diameter: CGFloat = 72
        ZStack {
            Circle()
                .fill(lit ? MoraTheme.Background.cream : Color.white)
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle().strokeBorder(
                        lit ? MoraTheme.Accent.orange : MoraTheme.Ink.muted.opacity(0.3),
                        lineWidth: 2
                    )
                )
            content(forIndex: index, lit: lit)
        }
        .opacity(lit ? 1.0 : 0.5)
    }

    @ViewBuilder
    private func content(forIndex index: Int, lit: Bool) -> some View {
        if index == 0, let yokai = activeYokai {
            YokaiPortraitCorner(yokai: yokai, sparkleTrigger: nil)
                .frame(width: 56, height: 56)
        } else if index == 4 {
            Text("🤝")
                .font(.system(size: 36))
                .accessibilityHidden(true)
        } else {
            Text("\(index + 1)")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.muted)
        }
    }

    private var activeYokai: YokaiDefinition? {
        YokaiIntroLookup.activeYokai(in: store)
    }

    @MainActor
    private func animateDots() async {
        if reduceMotion {
            dotsLit = Array(repeating: true, count: 5)
            return
        }
        for i in 0..<5 {
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                dotsLit[i] = true
            }
            do {
                try await Task.sleep(for: .milliseconds(120))
            } catch {
                return
            }
        }
    }
}

#if DEBUG
#Preview {
    ProgressPanel(store: try? BundledYokaiStore(), mode: .firstTime, onContinue: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
