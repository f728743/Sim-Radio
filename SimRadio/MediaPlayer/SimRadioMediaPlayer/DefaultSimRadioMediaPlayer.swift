//
//  DefaultSimRadioMediaPlayer.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 01.05.2025.
//

import AVFoundation
import Combine

struct PlayContinuation {
    let stationID: SimStation.ID
    let item: AVPlayerItem
    let playingEndDate: Date
    let playingEndTime: CMTime
}

@MainActor
class DefaultSimRadioMediaPlayer {
    weak var mediaState: SimRadioMediaState?

    private let queuePlayer = AVQueuePlayer()
    private var playContinuation: PlayContinuation?
    private let config: DefaultSimRadioMediaPlayer.Config = .default
    private var observer: NSObjectProtocol?
    private var playToEndTrackingСancellable: AnyCancellable?
}

extension DefaultSimRadioMediaPlayer.Config {
    static let `default` = DefaultSimRadioMediaPlayer.Config(
        staringPlaylistMinDuration: 60,
        continuationPlaylistMinDuration: 10 * 60
    )
}

extension DefaultSimRadioMediaPlayer: SimRadioMediaPlayer {
    func playStation(withID stationID: SimStation.ID) {
        Task {
            do {
                try await doPlayStation(withID: stationID)
            } catch {
                print(error)
            }
        }
    }

    func stop() {
        print("Stop")
        queuePlayer.removeAllItems()
    }
}

private extension DefaultSimRadioMediaPlayer {
    struct Config {
        let staringPlaylistMinDuration: TimeInterval
        let continuationPlaylistMinDuration: TimeInterval
    }

    func doPlayStation(withID stationID: SimStation.ID) async throws {
        print("Play \(stationID)")
        guard let mediaState else { return }

        guard let stationData = mediaState.stationData(for: stationID) else { return }
        let playlistBuilder = PlaylistBuilder(stationData: stationData)
        let startingDate = Date()
        let startingTime = CMTime(seconds: startingDate.currentSecondOfDay)
        let playlist = try await playlistBuilder.makePlaylist(
            startingOn: startingDate,
            at: .init(seconds: startingDate.currentSecondOfDay),
            duration: .init(seconds: config.staringPlaylistMinDuration)
        )
        let loader = PlayerItemLoader()
        let playerItem = try await loader.loadPlayerItem(playlist: playlist)
        queuePlayer.insert(playerItem, after: nil)
        queuePlayer.play()
        addDidPlayToEndObserver(to: playerItem)

        guard let playContinuation = try await makePlayContinuation(
            stationID: stationID,
            date: startingDate + playlist.duration.seconds,
            time: startingTime + playlist.duration
        ) else {
            throw PlayerItemLoadingError.playerItemCreatingError
        }
        self.playContinuation = playContinuation
        queuePlayer.insert(playContinuation.item, after: nil)
    }

    func onPlayerItemDidPlayToEndTime() {
        guard let playContinuation else { return }
        addDidPlayToEndObserver(to: playContinuation.item)
        Task {
            guard let newPlayContinuation = try await makePlayContinuation(
                stationID: playContinuation.stationID,
                date: playContinuation.playingEndDate,
                time: playContinuation.playingEndTime
            ) else { return }
            queuePlayer.insert(newPlayContinuation.item, after: nil)
            self.playContinuation = newPlayContinuation
        }
    }

    func addDidPlayToEndObserver(to item: AVPlayerItem) {
        playToEndTrackingСancellable = NotificationCenter.default.publisher(
            for: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        .sink { [weak self] _ in
            self?.onPlayerItemDidPlayToEndTime()
        }
    }

    func makePlayContinuation(
        stationID: SimStation.ID,
        date: Date,
        time: CMTime
    ) async throws -> PlayContinuation? {
        guard let stationData = mediaState?.stationData(for: stationID) else { return nil }
        let playlistBuilder = PlaylistBuilder(stationData: stationData)
        let playlist = try await playlistBuilder.makePlaylist(
            startingOn: date,
            at: time,
            duration: .init(seconds: config.continuationPlaylistMinDuration)
        )

        let loader = PlayerItemLoader()
        let playerItem = try await loader.loadPlayerItem(playlist: playlist)
        return PlayContinuation(
            stationID: stationID,
            item: playerItem,
            playingEndDate: date + playlist.duration.seconds,
            playingEndTime: time + playlist.duration
        )
    }
}
