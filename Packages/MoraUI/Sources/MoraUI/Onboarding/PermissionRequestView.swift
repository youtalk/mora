import AVFoundation
import Speech
import SwiftUI

struct PermissionRequestView: View {
    @Environment(\.moraStrings) private var strings
    let onContinue: () -> Void

    @State private var requesting = false

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            Image(systemName: "mic.fill")
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(MoraTheme.Accent.orange)
            Text(strings.permissionTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MoraTheme.Space.xl)
            Text(strings.permissionBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.muted)
            Spacer()

            HeroCTA(title: requesting ? "Requesting…" : strings.permissionAllow) {
                Task { await requestBoth() }
            }
            .disabled(requesting)

            Button(strings.permissionNotNow, action: onContinue)
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
