//
//  NowPlayingController.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 27.11.2024.
//

import Kingfisher
import UIKit

@Observable @MainActor
class NowPlayingController {
    enum State {
        case playing
        case paused
    }

    var colors: [ColorFrequency] = []
    var state: State = .paused
    var currentIndex: Int? = 1
    var items: [Media] = [] {
        didSet { onMediaListChanged(oldValue: oldValue) }
    }

    private let player: MediaPlayer

    init(player: MediaPlayer) {
        self.player = player
    }

    var currentMedia: Media? {
        guard let currentIndex else { return nil }
        return items[safe: currentIndex]
    }

    var display: Media {
        currentMedia ?? .placeholder
    }

    var title: String {
        display.meta.title
    }

    var subtitle: String? {
        display.meta.detailsSubtitle
    }

    var playPauseButton: ButtonType {
        switch state {
        case .playing: currentMedia.map(\.meta.online) ?? false ? .stop : .pause
        case .paused: .play
        }
    }

    var backwardButton: ButtonType { .backward }
    var forwardButton: ButtonType { .forward }

    func onAppear() {
        updateColors()
    }

    func onPlay(itemId: MediaID) {
        let index = items.firstIndex { $0.id == itemId }
        guard let index else { return }
        stopPlaying()
        currentIndex = index
        onPlayPause()
        updateColors()
    }

    func onPlayPause() {
        ensureMediaAvailable()
        guard let currentMedia else { return }
        state.toggle()
        if state == .playing {
            player.play(currentMedia)
        } else {
            player.stop()
        }
    }

    func onForward() {
        ensureMediaAvailable()
        guard currentMedia != nil else { return }

        guard let currentIndex else {
            self.currentIndex = 0
            return
        }

        var next = currentIndex + 1
        if next >= items.count {
            next = 0
        }
        self.currentIndex = next
        if state == .playing {
            stopPlaying()
            onPlayPause()
        }
        updateColors()
    }

    func onBackward() {
        ensureMediaAvailable()
        guard currentMedia != nil else { return }

        let lastIndex = items.count - 1
        guard let currentIndex else {
            self.currentIndex = lastIndex
            return
        }

        var prev = currentIndex - 1
        if prev < 0 {
            prev = lastIndex
        }
        if state == .playing {
            stopPlaying()
            onPlayPause()
        }
        self.currentIndex = prev
        updateColors()
    }
}

private extension NowPlayingController {
    func ensureMediaAvailable() {
        if items.isEmpty {
            selectFirstAvailableMedia()
        }
    }

    func selectFirstAvailableMedia() {
        stopPlaying()
        currentIndex = items.isEmpty ? nil : 0
    }

    func stopPlaying() {
        guard state != .paused else { return }
        state = .paused
        player.stop()
    }

    func onMediaListChanged(oldValue: [Media]) {
        stopPlaying()
        let currentItemId = currentIndex.map { oldValue[safe: $0]?.id } ?? nil
        if let currentItemId {
            currentIndex = items.firstIndex { $0.id == currentItemId }
        }
    }

    func updateColors() {
        Task {
            guard let url = display.meta.artwork else { return }
            let imageResult = try await KingfisherManager.shared.retrieveImage(
                with: url,
                options: nil,
                progressBlock: nil
            )
            colors = imageResult.image.dominantColorFrequencies(with: .high) ?? []
        }
    }
}

private extension NowPlayingController.State {
    mutating func toggle() {
        switch self {
        case .playing: self = .paused
        case .paused: self = .playing
        }
    }
}

extension Media {
    static var placeholder: Self {
        Media(
            id: .emptyMediaID,
            meta: .init(
                artwork: nil,
                title: "---",
                listSubtitle: "---",
                detailsSubtitle: "---",
                online: false
            )
        )
    }
}
