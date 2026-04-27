// Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguagePickerView.swift
import MoraCore
import SwiftUI

struct LanguagePickerView: View {
    @Binding var selectedLanguageID: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()
            VStack(spacing: MoraTheme.Space.xl) {
                LanguagePicker(selection: $selectedLanguageID)

                Spacer()

                Button(action: onContinue) {
                    Text("▶")
                        .font(MoraType.cta())
                        .foregroundStyle(.white)
                        .padding(.horizontal, MoraTheme.Space.xl)
                        .padding(.vertical, MoraTheme.Space.md)
                        .frame(minWidth: 120, minHeight: 88)
                        .background(
                            selectedLanguageID.isEmpty
                                ? MoraTheme.Ink.muted.opacity(0.3)
                                : MoraTheme.Accent.orange,
                            in: .capsule
                        )
                        .shadow(
                            color: selectedLanguageID.isEmpty
                                ? .clear : MoraTheme.Accent.orangeShadow,
                            radius: 0, x: 0, y: 5
                        )
                }
                .buttonStyle(.plain)
                .disabled(selectedLanguageID.isEmpty)
                .accessibilityLabel("Continue")
                .accessibilityHint("Go to the age picker")
                .padding(.bottom, MoraTheme.Space.xxl)
            }
        }
    }
}
