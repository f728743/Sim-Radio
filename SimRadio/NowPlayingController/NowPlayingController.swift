//
//  NowPlayingController.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 27.11.2024.
//

import Kingfisher
import UIKit

@MainActor
class NowPlayingController: ObservableObject {
    enum State {
        case playing
        case paused
    }
    @Published var colors: [ColorFrequency] = []
    @Published var state: State = .paused
    @Published var currentIndex: Int? = 1
    @Published var mediaList: MediaList = .empty {
        didSet { onMediaListChanged(oldValue: oldValue) }
    }
    private let player: Player
    
    init(player: Player) {
        self.player = player
    }

    var currentMedia: Media? {
        guard let currentIndex else { return nil }
        return mediaList.items[safe: currentIndex]
    }

    var display: Media {
        currentMedia ?? .placeholder
    }

    var title: String {
        display.title
    }

    var subtitle: String? {
        display.subtitle
    }

    var playPauseButton: ButtonType {
        switch state {
        case .playing: currentMedia.map(\.online) ?? false ? .stop : .pause
        case .paused: .play
        }
    }

    var backwardButton: ButtonType { .backward }
    var forwardButton: ButtonType { .forward }

    func onAppear() {
        updateColors()
    }

    func onPlay(itemId: UUID) {
        let index = mediaList.items.firstIndex { $0.id == itemId }
        guard let index else { return }
        stopPlaying()
        currentIndex = index
        onPlayPause()
    }
    
    func onPlayPause() {
        enshureMediaAvailable()
        guard let currentMedia else { return }
        state.toggle()
        if state == .playing {
            player.play(currentMedia)
        } else {
            player.stop()
        }
    }

    func onForward() {
        enshureMediaAvailable()
        guard currentMedia != nil else { return }

        guard let currentIndex else {
            self.currentIndex = 0
            return
        }

        var next = currentIndex + 1
        if next >= mediaList.items.count {
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
        enshureMediaAvailable()
        guard currentMedia != nil else { return }

        let lastIndex = mediaList.items.count - 1
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
    func enshureMediaAvailable() {
        if mediaList.items.isEmpty {
            selectFirstAvailableMedia()
        }
    }

    func selectFirstAvailableMedia() {
        stopPlaying()
        currentIndex = mediaList.items.isEmpty ? nil : 0
    }

    func stopPlaying() {
        guard state != .paused else { return }
        state = .paused
        player.stop()
    }
    
    func onMediaListChanged(oldValue: MediaList) {
        stopPlaying()
        let currentItemId = currentIndex.map { oldValue.items[safe: $0]?.id } ?? nil
        if let currentItemId {
            currentIndex = mediaList.items.firstIndex { $0.id == currentItemId }
        }
    }

    func updateColors() {
        Task {
            guard let url = display.artwork else { return }
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
            artwork: nil,
            title: "---",
            subtitle: "---",
            online: false
        )
    }
}

extension MediaList {
    static var empty: Self {
        MediaList(
            artwork: nil,
            title: "---",
            subtitle: nil,
            items: []
        )
    }
}

