import MoraCore
import MoraEngines
import SwiftData
import SwiftUI

public struct BestiaryView: View {
    @Query(sort: \BestiaryEntryEntity.befriendedAt, order: .forward)
    private var entries: [BestiaryEntryEntity]
    @State private var store: BundledYokaiStore?

    public init() {}

    public var body: some View {
        let catalog = store?.catalog() ?? []
        return ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3),
                spacing: 16
            ) {
                ForEach(catalog, id: \.id) { yokai in
                    if let entry = entries.first(where: { $0.yokaiID == yokai.id }) {
                        NavigationLink {
                            BestiaryDetailView(yokai: yokai, entry: entry)
                        } label: {
                            BestiaryCardView(yokai: yokai, state: .befriended)
                        }
                    } else {
                        BestiaryCardView(yokai: yokai, state: .locked)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Sound-Friend Register")
        .onAppear { if store == nil { store = try? BundledYokaiStore() } }
    }
}
