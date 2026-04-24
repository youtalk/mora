import MoraCore
import MoraEngines
import MoraFixtures
import SwiftUI

struct VerdictBadge: View {
    let cached: PhonemeTrialAssessment?
    let failed: Bool
    let pattern: FixturePattern

    var body: some View {
        if let assessment = cached {
            let h = PronunciationVerdictHeadline.make(
                pattern: pattern, assessment: assessment
            )
            HStack(spacing: 4) {
                Image(systemName: iconName(h.tone))
                    .foregroundStyle(tint(h.tone))
                Text(h.title).font(.footnote).foregroundStyle(.secondary)
            }
            .accessibilityLabel(h.title)
        } else if failed {
            HStack(spacing: 4) {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
                Text("unavailable").font(.footnote).foregroundStyle(.secondary)
            }
            .accessibilityLabel("verdict unavailable")
        } else {
            ProgressView().controlSize(.mini)
        }
    }

    private func iconName(_ tone: PronunciationVerdictHeadlineContent.Tone) -> String {
        switch tone {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        }
    }

    private func tint(_ tone: PronunciationVerdictHeadlineContent.Tone) -> Color {
        switch tone {
        case .pass: return .green
        case .fail: return .red
        case .warn: return .orange
        }
    }
}
