import MoraFixtures
import SwiftUI

struct CatalogListView: View {

    @Bindable var store: RecorderStore

    var body: some View {
        List {
            Section {
                Picker("Speaker", selection: $store.speakerTag) {
                    Text("Adult").tag(SpeakerTag.adult)
                    Text("Child").tag(SpeakerTag.child)
                }
                .pickerStyle(.segmented)
            }

            Section("Patterns") {
                ForEach(FixtureCatalog.v1Patterns) { pattern in
                    NavigationLink {
                        PatternDetailView(store: store, pattern: pattern)
                    } label: {
                        HStack {
                            Text(pattern.displayLabel)
                            Spacer()
                            Text("\(store.takeCount(for: pattern)) takes")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BulkShareButton(store: store)
            }
        }
        .navigationTitle("Fixture Recorder")
    }
}
