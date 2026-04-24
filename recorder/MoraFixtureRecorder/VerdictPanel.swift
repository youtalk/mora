import MoraCore
import MoraEngines
import MoraFixtures
import SwiftUI

struct VerdictPanel: View {
    let pattern: FixturePattern
    let pending: PendingVerdict

    var body: some View {
        switch pending {
        case .idle:
            EmptyView()
        case .evaluating:
            HStack {
                ProgressView().controlSize(.small)
                Text("evaluating…").foregroundStyle(.secondary)
            }
        case .ready(let assessment):
            VerdictSummary(pattern: pattern, assessment: assessment)
        }
    }
}

struct VerdictSummary: View {
    let pattern: FixturePattern
    let assessment: PhonemeTrialAssessment
    @State private var expanded = false

    var body: some View {
        let headline = PronunciationVerdictHeadline.make(
            pattern: pattern, assessment: assessment
        )
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 4) {
                if let score = assessment.score {
                    LabeledContent("score", value: "\(score)/100")
                }
                ForEach(
                    assessment.features.sorted(by: { $0.key < $1.key }),
                    id: \.key
                ) { k, v in
                    LabeledContent(k) {
                        Text(String(format: "%.1f", v)).monospacedDigit()
                    }
                }
                LabeledContent("reliable", value: "\(assessment.isReliable)")
                if let key = assessment.coachingKey {
                    LabeledContent("coaching", value: key)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        } label: {
            VerdictHeadlineView(content: headline)
        }
    }
}

struct VerdictHeadlineView: View {
    let content: PronunciationVerdictHeadlineContent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title).font(.headline)
                if let subtitle = content.subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconName: String {
        switch content.tone {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch content.tone {
        case .pass: return .green
        case .fail: return .red
        case .warn: return .orange
        }
    }

    private var accessibilityLabel: String {
        let toneWord: String
        switch content.tone {
        case .pass: toneWord = "pass"
        case .fail: toneWord = "fail"
        case .warn: toneWord = "warning"
        }
        return [toneWord, content.title, content.subtitle ?? ""]
            .joined(separator: ". ")
    }
}
