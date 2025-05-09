//
//  NowPlayingInfo.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 08.05.2025.
//

import UIKit

struct NowPlayingInfo {
    let isLiveStream: Bool
    let title: String
    let artwork: UIImage
    let artist: String?
    let genre: String?
    let queue: Queue?
    let playback: Playback?

    init(
        isLiveStream: Bool,
        title: String,
        artwork: UIImage,
        artist: String? = nil,
        genre: String? = nil,
        queue: Queue? = nil,
        playback: Playback? = nil
    ) {
        self.isLiveStream = isLiveStream
        self.title = title
        self.artwork = artwork
        self.artist = artist
        self.genre = genre
        self.queue = queue
        self.playback = playback
    }

    struct Queue {
        let index: Int
        let count: Int
    }

    struct Playback {
        let duration: TimeInterval
        let elapsedTime: TimeInterval
    }
}
