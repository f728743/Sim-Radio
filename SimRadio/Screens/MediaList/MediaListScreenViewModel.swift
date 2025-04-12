//
//  MediaListScreenViewModel.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 09.04.2025.
//

import Observation
import SwiftUI

@Observable @MainActor
class MediaListScreenViewModel {
    enum SwipeButton {
        case download
    }

    var mediaState: MediaState?
    var nowPlaying: NowPlayingController?
    let items: [Media]
    let listMeta: MediaList.Meta?

    init(items: [Media], listMeta: MediaList.Meta?) {
        self.items = items
        self.listMeta = listMeta
    }

    func onSelect(media: Media.ID) {
        guard let nowPlaying else { return }
        if nowPlaying.items != items {
            nowPlaying.items = items
        }
        nowPlaying.onPlay(itemId: media)
    }

    func swipeButton(media _: Media.ID) -> SwipeButton {
        .download
    }

    func onSwipeActions(media: Media.ID, button _: SwipeButton) {
        Task {
            await mediaState?.download(media)
        }
    }

    func downloadStatus(for itemID: MediaID) -> MediaDownloadStatus? {
        mediaState?.downloadStatus[itemID]
    }

    var footer: LocalizedStringKey {
        "^[\(items.count) station](inflect: true)"
    }
}

extension MediaListScreenViewModel.SwipeButton {
    var systemImage: String {
        switch self {
        case .download:
            return "arrow.down"
        }
    }

    var label: String {
        switch self {
        case .download:
            return "Download"
        }
    }

    var color: Color {
        switch self {
        case .download:
            return .init(.systemBlue)
        }
    }
}
