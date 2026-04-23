import MoraFixtures
import SwiftUI

struct BulkShareButton: View {

    @Bindable var store: RecorderStore

    @State private var archiveURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let url = archiveURL {
                ShareLink(item: url) {
                    Label(
                        "Share \(store.speakerTag.rawValue) takes (\(store.totalTakesInCurrentSpeaker))",
                        systemImage: "square.and.arrow.up")
                }
                .disabled(store.totalTakesInCurrentSpeaker == 0)
            } else {
                Button {
                    prepare()
                } label: {
                    Label(
                        "Share \(store.speakerTag.rawValue) takes (\(store.totalTakesInCurrentSpeaker))",
                        systemImage: "square.and.arrow.up")
                }
                .disabled(store.totalTakesInCurrentSpeaker == 0)
            }
        }
        .alert(
            "Archive failed",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: store.speakerTag) { _, _ in
            // Speaker changed — any cached zip now points at the wrong
            // archive. Force-rebuild on next tap.
            archiveURL = nil
        }
    }

    private func prepare() {
        do {
            archiveURL = try store.prepareSpeakerArchive()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
