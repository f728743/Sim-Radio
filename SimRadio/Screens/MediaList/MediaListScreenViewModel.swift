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
    enum SwipeButton: Hashable {
        case download
        case pauseDownload
        case delete
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

    func swipeButtons(media: Media.ID) -> [SwipeButton] {
        switch downloadStatus(for: media)?.state {
        case .completed: [.delete]
        case .none: [.download]
        case .downloading, .scheduled: [.pauseDownload, .delete]
        case .paused: [.download, .delete]
        case .busy: []
        }
    }

    func onSwipeActions(media: Media.ID, button: SwipeButton) {
        Task {
            switch button {
            case .download:
                await mediaState?.download(media)
            case .delete:
                await mediaState?.removeDownload(media)
            case .pauseDownload:
                await mediaState?.pauseDownload(media)
            }
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
        case .pauseDownload:
            return "pause.fill"
        case .delete:
            return "minus.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .download: "Download"
        case .pauseDownload: "Pause"
        case .delete: "Delete"
        }
    }

    var color: Color {
        switch self {
        case .download: Color(.systemBlue)
        case .pauseDownload: Color(.systemGray)
        case .delete: Color(.systemRed)
        }
    }
}
