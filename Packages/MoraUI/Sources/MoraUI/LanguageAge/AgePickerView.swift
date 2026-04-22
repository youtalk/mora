// Packages/MoraUI/Sources/MoraUI/LanguageAge/AgePickerView.swift
import MoraCore
import SwiftUI

struct AgePickerView: View {
    @Environment(\.moraStrings) private var strings
    @Binding var selectedAge: Int?
    let onContinue: () -> Void

    /// 4..12 plus a sentinel `13` that renders as "13+" and maps to the
    /// 13-and-over bucket internally. Under-4 is out of scope in alpha.
    private let ages: [Int] = Array(4...12) + [13]
    private let columns = [
        GridItem(.flexible(), spacing: MoraTheme.Space.md),
        GridItem(.flexible(), spacing: MoraTheme.Space.md),
        GridItem(.flexible(), spacing: MoraTheme.Space.md),
    ]

    var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()
            VStack(spacing: MoraTheme.Space.xl) {
                Text(strings.ageOnboardingPrompt)
                    .font(MoraType.heading())
                    .foregroundStyle(MoraTheme.Ink.primary)
                    .padding(.top, MoraTheme.Space.xxl)

                LazyVGrid(columns: columns, spacing: MoraTheme.Space.md) {
                    ForEach(ages, id: \.self) { age in
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
        let label = age == 13 ? "13+" : "\(age)"
        return Button {
            selectedAge = age
        } label: {
            Text(label)
                .font(MoraType.hero(72))
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
    }
}
