import MoraCore
import XCTest

@testable import MoraEngines

final class PronunciationTypesTests: XCTestCase {
    func testAudioClipRoundTripsThroughCodable() throws {
        let clip = AudioClip(samples: [0.1, -0.2, 0.3], sampleRate: 16_000)
        let data = try JSONEncoder().encode(clip)
        let decoded = try JSONDecoder().decode(AudioClip.self, from: data)
        XCTAssertEqual(decoded, clip)
    }

    func testAudioClipDurationSeconds() {
        let clip = AudioClip(samples: Array(repeating: 0, count: 16_000), sampleRate: 16_000)
        XCTAssertEqual(clip.durationSeconds, 1.0, accuracy: 0.001)
    }

    func testPhonemeAssessmentLabelCodable() throws {
        let cases: [PhonemeAssessmentLabel] = [
            .matched,
            .substitutedBy(Phoneme(ipa: "s")),
            .driftedWithin,
            .unclear,
        ]
        for label in cases {
            let data = try JSONEncoder().encode(label)
            let decoded = try JSONDecoder().decode(PhonemeAssessmentLabel.self, from: data)
            XCTAssertEqual(decoded, label)
        }
    }

    func testPhonemeTrialAssessmentCarriesFeatures() {
        let assessment = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: .substitutedBy(Phoneme(ipa: "s")),
            score: 30,
            coachingKey: "coaching.sh_sub_s.ja",
            features: ["spectralCentroidHz": 6100.0],
            isReliable: true
        )
        XCTAssertEqual(assessment.features["spectralCentroidHz"], 6100.0)
        XCTAssertEqual(assessment.coachingKey, "coaching.sh_sub_s.ja")
    }

    func testTrialRecordingCarriesASRAndAudio() {
        let asr = ASRResult(transcript: "ship", confidence: 0.85)
        let audio = AudioClip(samples: [0.0, 0.1], sampleRate: 16_000)
        let recording = TrialRecording(asr: asr, audio: audio)
        XCTAssertEqual(recording.asr.transcript, "ship")
        XCTAssertEqual(recording.audio.samples, [0.0, 0.1])
    }
}
