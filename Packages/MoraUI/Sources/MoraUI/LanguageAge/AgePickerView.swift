// Packages/MoraUI/Sources/MoraUI/LanguageAge/AgePickerView.swift
import MoraCore
import SwiftUI

struct AgePickerView: View {
    @Environment(\.moraStrings) private var strings
    @Binding var selectedAge: Int?
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()
            VStack(spacing: MoraTheme.Space.xl) {
                Text(strings.ageOnboardingPrompt)
                    .font(MoraType.heading())
                    .foregroundStyle(MoraTheme.Ink.primary)
                    .padding(.top, MoraTheme.Space.xxl)

                HStack(spacing: MoraTheme.Space.md) {
                    ForEach(LanguageAgeFlow.ageOptions, id: \.self) { age in
                        tile(age)
                    }
                }
                .padding(.horizontal, MoraTheme.Space.xxl)

                Spacer()

                Button(action: onContinue) {
                    Text(strings.ageOnboardingCTA)
                        .font(MoraType.cta())
                        .foregroundStyle(.white)
                        .padding(.horizontal, MoraTheme.Space.xl)
                        .padding(.vertical, MoraTheme.Space.md)
                        .frame(minHeight: 88)
                        .background(
                            selectedAge == nil
                                ? MoraTheme.Ink.muted.opacity(0.3)
                                : MoraTheme.Accent.orange,
                            in: .capsule
                        )
                        .shadow(
                            color: selectedAge == nil
                                ? .clear : MoraTheme.Accent.orangeShadow,
                            radius: 0, x: 0, y: 5
                        )
                }
                .buttonStyle(.plain)
                .disabled(selectedAge == nil)
                .padding(.bottom, MoraTheme.Space.xxl)
            }
        }
    }

    private func tile(_ age: Int) -> some View {
        let selected = selectedAge == age
        return Button {
            selectedAge = age
        } label: {
            Text("\(age)")
                .font(MoraType.hero(120))
                .foregroundStyle(MoraTheme.Ink.primary)
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(
                    selected ? MoraTheme.Background.peach : MoraTheme.Background.cream,
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
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
