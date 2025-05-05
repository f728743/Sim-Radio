//
//  DefaultSimRadioMediaPlayer.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 01.05.2025.
//

import AVFoundation
import Foundation

struct PlayContinuation {
    let stationID: SimStation.ID
    let item: AVPlayerItem
    let playingEndDate: Date
    let playingEndTime: CMTime
}

@MainActor
class DefaultSimRadioMediaPlayer {
    struct Config {
        let staringPlaylistDuration: TimeInterval
        let continuationPlaylistMinDuration: TimeInterval
    }

    let queuePlayer = AVQueuePlayer()
    var playContinuation: PlayContinuation?
    let config: DefaultSimRadioMediaPlayer.Config = .default
    weak var mediaState: SimRadioMediaState?
}

extension DefaultSimRadioMediaPlayer.Config {
    static let `default` = DefaultSimRadioMediaPlayer.Config(
        staringPlaylistDuration: 60,
        continuationPlaylistMinDuration: 10 * 60
    )
}

private extension DefaultSimRadioMediaPlayer {
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
            duration: .init(seconds: config.staringPlaylistDuration),
            trimLastItem: false
        )
        let loader = PlayerItemLoader()
        let playerItem = try await loader.loadPlayerItem(playlist: playlist)
        queuePlayer.insert(playerItem, after: nil)
        queuePlayer.play()

        NotificationCenter.default.addObserver(
            self, selector: #selector(playerItemDidPlayToEndTime),
            name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
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

    @objc func playerItemDidPlayToEndTime() {
        guard let oldContinuation = playContinuation else { return }
        NotificationCenter.default.addObserver(
            self, selector: #selector(playerItemDidPlayToEndTime),
            name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
            object: oldContinuation.item
        )
        Task {
            guard let playContinuation = try await makePlayContinuation(
                stationID: oldContinuation.stationID,
                date: oldContinuation.playingEndDate,
                time: oldContinuation.playingEndTime

            ) else { return }
            queuePlayer.insert(playContinuation.item, after: nil)
            self.playContinuation = playContinuation
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
            duration: .init(seconds: config.continuationPlaylistMinDuration),
            trimLastItem: false
        )

        let loader = PlayerItemLoader()
        let playerItem = try await loader.loadPlayerItem(playlist: playlist)
        return PlayContinuation(
            stationID: stationID,
            item: playerItem,
            playingEndDate: date + playlist.duration.seconds,
            playingEndTime: playlist.duration
        )
    }
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
