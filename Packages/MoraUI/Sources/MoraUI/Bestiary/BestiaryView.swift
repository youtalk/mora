import MoraCore
import MoraEngines
import SwiftData
import SwiftUI

public struct BestiaryView: View {
    @Query(sort: \BestiaryEntryEntity.befriendedAt, order: .forward)
    private var entries: [BestiaryEntryEntity]
    @State private var store: BundledYokaiStore?
    @Environment(\.moraStrings) private var strings

    public init() {}

    public var body: some View {
        let catalog = store?.catalog() ?? []
        return ScrollView {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: MoraTheme.Space.lg),
                    count: 3
                ),
                spacing: MoraTheme.Space.lg
            ) {
                ForEach(catalog, id: \.id) { yokai in
                    if let entry = entries.first(where: { $0.yokaiID == yokai.id }) {
                        NavigationLink {
                            BestiaryDetailView(yokai: yokai, entry: entry)
                        } label: {
                            BestiaryCardView(yokai: yokai, state: .befriended)
                        }
                        .buttonStyle(.plain)
                    } else {
                        BestiaryCardView(yokai: yokai, state: .locked)
                    }
                }
            }
            .padding(MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MoraTheme.Background.page.ignoresSafeArea())
        .navigationTitle(strings.bestiaryLinkLabel)
        .onAppear { if store == nil { store = try? BundledYokaiStore() } }
    }
}
