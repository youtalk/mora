// Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageSwitchSheet.swift
import MoraCore
import SwiftUI

/// Sheet that lets the user re-pick the L1 from Home, without re-running
/// onboarding. Reuses `LanguagePicker`. Writes only `LearnerProfile.l1Identifier`;
/// age / level / interests / font are not touched. See spec §7.3.
@MainActor
public final class LanguageSwitchSheet: ObservableObject {
    public let currentIdentifier: String
    private let onCommit: (String) -> Void
    private let onCancel: () -> Void

    @Published public var pickedID: String

    public init(
        currentIdentifier: String,
        onCommit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.currentIdentifier = currentIdentifier
        self.onCommit = onCommit
        self.onCancel = onCancel
        self.pickedID = currentIdentifier
    }

    public var isConfirmDisabled: Bool {
        pickedID == currentIdentifier
    }

    public func simulateSelect(identifier: String) {
        pickedID = identifier
    }

    public func simulateConfirm() {
        guard !isConfirmDisabled else { return }
        onCommit(pickedID)
    }

    public func simulateCancel() {
        onCancel()
    }
}

extension LanguageSwitchSheet: Identifiable {
    public var id: String { currentIdentifier }
}

/// SwiftUI rendering of the sheet model. Hosted as a `.sheet` from `HomeView`.
public struct LanguageSwitchSheetView: View {
    @ObservedObject var model: LanguageSwitchSheet
    @Environment(\.moraStrings) private var strings

    public init(model: LanguageSwitchSheet) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            LanguagePicker(selection: $model.pickedID)
                .padding()
                .navigationTitle(strings.languageSwitchSheetTitle)
                #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(strings.languageSwitchSheetCancel) {
                            model.simulateCancel()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(strings.languageSwitchSheetConfirm) {
                            model.simulateConfirm()
                        }
                        .disabled(model.isConfirmDisabled)
                    }
                }
        }
    }
}
