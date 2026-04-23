import AVFoundation
import MoraFixtures
import SwiftUI

struct TakeRow: View {

    let wavURL: URL
    @Bindable var store: RecorderStore
    let pattern: FixturePattern

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            ShareLink(items: store.takeArtifacts(for: wavURL)) {
                Image(systemName: "square.and.arrow.up")
            }
            Button {
                store.deleteTake(url: wavURL)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
    }

    private var label: String {
        let basename = wavURL.deletingPathExtension().lastPathComponent
        let takeSuffix =
            basename
            .split(separator: "-take")
            .last.map(String.init) ?? "?"
        return "take \(takeSuffix)"
    }
}
