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

    let mediaList: MediaList
    var mediaState: MediaState?
    var nowPlaying: NowPlayingController?

    init(mediaList: MediaList) {
        self.mediaList = mediaList
    }

    func onSelect(media: Media.ID) {
        guard let nowPlaying else { return }
        if nowPlaying.mediaList.id != mediaList.id {
            nowPlaying.mediaList = mediaList
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
}

// private extension MediaDownloadProgressView.State {
//    init(status: MediaDownloadStatus) {
//        let progress = status.totalBytes > 0 ? Double(status.downloadedBytes) / Double(status.totalBytes) : 0
//        switch status.state {
//        case .completed: self = .completed
//        case .scheduled: self = .scheduled
//        case .inProgress: self = .progress(progress.clamped(to: 0.0 ... 1.0))
//        case .paused: self = .paused
//        }
//    }
// }

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
