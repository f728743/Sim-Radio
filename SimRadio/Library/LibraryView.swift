import Kingfisher
import SwiftUI

struct LibraryView: View {
    @Environment(\.nowPlayingExpandProgress) var expandProgress
    @EnvironmentObject var library: MediaLibrary

    var body: some View {
        NavigationStack {
            List {
                // Library sections
                Group {
                    navigationLink(title: "Downloaded", icon: "arrow.down.circle")
                }

                // Recently Added Section
                Section(header: Text("Recently Added")
                    .font(.appFont.mediaListHeaderTitle)
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .padding(.top, 24)
                ) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(library.list.prefix(4), id: \.title) { item in
                            RecentlyAddedItem(item: item)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        print("Profile")
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(.palette.brand))
                    }
                }
            }
        }
    }

    private func navigationLink(title: String, icon: String) -> some View {
        NavigationLink {
            Text(title)
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color(.palette.brand))
                    .frame(width: 32)

                Text(title)
                    .font(.appFont.mediaListHeaderTitle)
            }
        }
    }
}

struct RecentlyAddedItem: View {
    let item: MediaList

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            KFImage.url(item.artwork)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .background(Color(.palette.artworkBackground))
                .clipShape(.rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.palette.artworkBorder), lineWidth: UIScreen.hairlineWidth)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.appFont.mediaListItemTitle)
                    .lineLimit(1)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.appFont.mediaListItemSubtitle)
                        .foregroundStyle(Color(.palette.textSecondary))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        LibraryView()
    }
}
