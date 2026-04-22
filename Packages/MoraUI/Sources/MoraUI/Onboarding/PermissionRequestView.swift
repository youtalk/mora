import AVFoundation
import Speech
import SwiftUI

struct PermissionRequestView: View {
    let onContinue: () -> Void

    @State private var requesting = false

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            Image(systemName: "mic.fill")
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(MoraTheme.Accent.orange)
            Text("We'll listen when you read.")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MoraTheme.Space.xl)
            Text("Your voice stays on this iPad.")
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.muted)
            Spacer()

            HeroCTA(title: requesting ? "Requesting…" : "Allow") {
                Task { await requestBoth() }
            }
            .disabled(requesting)

            Button("Not now", action: onContinue)
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)
                .padding(.vertical, MoraTheme.Space.md)
                .padding(.bottom, MoraTheme.Space.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func requestBoth() async {
        requesting = true
        #if os(iOS)
        _ = await AVAudioApplication.requestRecordPermission()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { _ in cont.resume() }
        }
        #endif
        requesting = false
        onContinue()
    }
}
