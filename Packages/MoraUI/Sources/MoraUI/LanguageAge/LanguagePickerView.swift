// Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguagePickerView.swift
import MoraCore
import SwiftUI

struct LanguagePickerView: View {
    @Binding var selectedLanguageID: String
    let onContinue: () -> Void

    private struct Option: Identifiable {
        let id: String
        let label: String
        let enabled: Bool
    }

    // Only `.ja` is enabled in alpha. See spec §6.1.
    private let options: [Option] = [
        Option(id: "ja", label: "にほんご", enabled: true),
        Option(id: "ko", label: "한국어", enabled: false),
        Option(id: "zh", label: "中文", enabled: false),
        Option(id: "en", label: "English", enabled: false),
    ]

    var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()
            VStack(spacing: MoraTheme.Space.xl) {
                Text("Language / 言語 / 语言 / 언어")
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.muted)
                    .padding(.top, MoraTheme.Space.xxl)

                VStack(spacing: MoraTheme.Space.sm) {
                    ForEach(options) { option in
                        row(option)
                    }
                }
                .padding(.horizontal, MoraTheme.Space.xxl)

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
                .padding(.bottom, MoraTheme.Space.xxl)
            }
        }
    }

    private func row(_ option: Option) -> some View {
        let selected = option.id == selectedLanguageID
        return Button {
            guard option.enabled else { return }
            selectedLanguageID = option.id
        } label: {
            HStack {
                Text(option.label)
                    .font(MoraType.heading())
                    .foregroundStyle(
                        option.enabled
                            ? MoraTheme.Ink.primary
                            : MoraTheme.Ink.muted
                    )
                if !option.enabled {
                    Spacer()
                    Text("Coming soon")
                        .font(MoraType.pill())
                        .foregroundStyle(MoraTheme.Ink.muted)
                } else if selected {
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundStyle(MoraTheme.Accent.orange)
                } else {
                    Spacer()
                }
            }
            .padding(MoraTheme.Space.md)
            .background(
                selected
                    ? MoraTheme.Background.peach
                    : MoraTheme.Background.cream,
                in: RoundedRectangle(cornerRadius: MoraTheme.Radius.tile)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MoraTheme.Radius.tile)
                    .stroke(
                        selected ? MoraTheme.Accent.orange : .clear,
                        lineWidth: 3
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!option.enabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
