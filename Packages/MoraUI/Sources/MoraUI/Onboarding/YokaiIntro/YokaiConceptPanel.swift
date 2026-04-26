// Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/YokaiConceptPanel.swift
import MoraCore
import MoraEngines
import SwiftUI

struct YokaiConceptPanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let store: BundledYokaiStore?
    let onContinue: () -> Void

    @State private var silhouettesVisible: [Bool] = Array(repeating: false, count: 5)

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
            await animateSilhouettes()
        }
    }

    @ViewBuilder
    private var silhouetteRow: some View {
        HStack(spacing: MoraTheme.Space.lg) {
            ForEach(Array(catalog.enumerated()), id: \.element.id) { index, yokai in
                VStack(spacing: 4) {
                    Text(yokai.ipa)
                        .font(MoraType.label())
                        .foregroundStyle(MoraTheme.Ink.muted)
                    YokaiPortraitCorner(yokai: yokai, sparkleTrigger: nil)
                        .frame(width: 96, height: 96)
                        .opacity(isVisible(at: index) ? 1.0 : 0.0)
                }
            }
        }
    }

    private func isVisible(at index: Int) -> Bool {
        guard silhouettesVisible.indices.contains(index) else { return false }
        return silhouettesVisible[index]
    }

    @MainActor
    private func animateSilhouettes() async {
        if reduceMotion {
            silhouettesVisible = Array(repeating: true, count: silhouettesVisible.count)
            return
        }
        for index in silhouettesVisible.indices {
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.4)) {
                silhouettesVisible[index] = true
            }
            do {
                try await Task.sleep(for: .milliseconds(80))
            } catch is CancellationError {
                return
            } catch {
                assertionFailure("Unexpected error while animating silhouettes: \(error)")
                return
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
        .environment(\.moraStrings, MoraStrings.previewDefault)
}
#endif
