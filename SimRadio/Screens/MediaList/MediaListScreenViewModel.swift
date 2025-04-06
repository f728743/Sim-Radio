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

    func onSwipeActions(media: Media.ID, button: SwipeButton) {
        print(button, media)
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
