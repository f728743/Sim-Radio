//
//  DefaultSimRadioMediaPlayer.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 01.05.2025.
//

import AVFoundation
import Kingfisher
import UIKit

@MainActor
class DefaultSimRadioMediaPlayer {
    weak var mediaState: SimRadioMediaState?
    weak var delegate: SimRadioMediaPlayerDelegate?

    private let queuePlayer = AVQueuePlayer()
    private var nextPlayableItem: NextPlayableItem?
    private var stationNowPlayingInfo: StationNowPlayingInfo?
    private let config: DefaultSimRadioMediaPlayer.Config = .default
    private var observer: NSObjectProtocol?
    private var playToEndTask: Task<Void, Never>?
}

extension DefaultSimRadioMediaPlayer.Config {
    static let `default` = DefaultSimRadioMediaPlayer.Config(
        initialPlaylistMinDuration: 60,
        bufferedPlaylistMinDuration: 10 * 60
    )
}

extension DefaultSimRadioMediaPlayer: SimRadioMediaPlayer {
    func playStation(withID stationID: SimStation.ID) {
        print("Play \(stationID)")
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
        playToEndTask?.cancel()
        playToEndTask = nil
        stationNowPlayingInfo = nil
    }
}

private extension DefaultSimRadioMediaPlayer {
    struct Config {
        /// Minimum duration (in seconds) required for the initial playlist
        /// - Note: This playlist is optimized for fast loading to minimize playback startup latency
        /// - The actual duration might be longer depending on available tracks
        let initialPlaylistMinDuration: TimeInterval
        /// Minimum duration (in seconds) required for subsequent buffered playlists
        /// - Note: These playlists are loaded in the background during playback to ensure seamless continuation
        /// - Typically longer than initial playlists to maintain playback buffer
        let bufferedPlaylistMinDuration: TimeInterval
    }

    /// Represents the next media item to be queued for playback
    struct NextPlayableItem {
        let stationID: SimStation.ID
        let item: AVPlayerItem
        /// Reference date used to calculate the day boundary for playback scheduling
        /// - Important: Calendar operations should use this date's startOfDay
        let day: Date
        /// Precise time offset within the day for playback scheduling
        /// - Note: Uses CMTime for frame-accurate scheduling and AVFoundation compatibility
        /// - Value represents seconds since start of day (00:00)
        let startTimeInDay: CMTime
    }

    struct StationNowPlayingInfo {
        let title: String
        let artwork: UIImage
        let artist: String?
        let genre: String?
        let index: Int
        let count: Int
    }

    func doPlayStation(withID stationID: SimStation.ID) async throws {
        guard let mediaState else { return }

        guard let stationData = mediaState.stationData(for: stationID) else { return }
        let playlistBuilder = PlaylistBuilder(stationData: stationData)
        let startingDate = Date()
        let startingTime = CMTime(seconds: startingDate.currentSecondOfDay)
        let playlist = try await playlistBuilder.makePlaylist(
            startingOn: startingDate,
            at: .init(seconds: startingDate.currentSecondOfDay),
            duration: .init(seconds: config.initialPlaylistMinDuration)
        )
        let loader = PlayerItemLoader()
        let playerItem = try await loader.loadPlayerItem(playlist: playlist)
        queuePlayer.insert(playerItem, after: nil)
        queuePlayer.play()
        addDidPlayToEndObserver(to: playerItem)

        guard let nextPlayableItem = try await makeNextPlayableItem(
            stationID: stationID,
            date: startingDate + playlist.duration.seconds,
            time: startingTime + playlist.duration
        ) else {
            throw PlayerItemLoadingError.playerItemCreatingError
        }
        self.nextPlayableItem = nextPlayableItem
        queuePlayer.insert(nextPlayableItem.item, after: nil)
        stationNowPlayingInfo = await makeStationNowPlayingInfo(
            meta: stationData.station.meta,
            index: 0, // TODO:
            count: 10 // TODO:
        )
        updateNowPlayingInfo()
    }

    func onPlayerItemDidPlayToEndTime() {
        guard let nextPlayableItem else { return }
        addDidPlayToEndObserver(to: nextPlayableItem.item)
        Task {
            guard let newNextPlayableItem = try await makeNextPlayableItem(
                stationID: nextPlayableItem.stationID,
                date: nextPlayableItem.day,
                time: nextPlayableItem.startTimeInDay
            ) else { return }
            queuePlayer.insert(newNextPlayableItem.item, after: nil)
            self.nextPlayableItem = newNextPlayableItem
        }
    }

    func addDidPlayToEndObserver(to item: AVPlayerItem) {
        playToEndTask?.cancel()
        playToEndTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .AVPlayerItemDidPlayToEndTime,
                object: item
            )

            for await _ in notifications {
                guard !Task.isCancelled else { break }
                self?.onPlayerItemDidPlayToEndTime()
            }
        }
    }

    func makeNextPlayableItem(
        stationID: SimStation.ID,
        date: Date,
        time: CMTime
    ) async throws -> NextPlayableItem? {
        guard let stationData = mediaState?.stationData(for: stationID) else { return nil }
        let playlistBuilder = PlaylistBuilder(stationData: stationData)
        let playlist = try await playlistBuilder.makePlaylist(
            startingOn: date,
            at: time,
            duration: .init(seconds: config.bufferedPlaylistMinDuration)
        )

        let loader = PlayerItemLoader()
        let playerItem = try await loader.loadPlayerItem(playlist: playlist)
        return NextPlayableItem(
            stationID: stationID,
            item: playerItem,
            day: date + playlist.duration.seconds,
            startTimeInDay: time + playlist.duration
        )
    }

    func updateNowPlayingInfo() {
        guard let info = stationNowPlayingInfo else { return }
        delegate?.simRadioMediaPlayer(
            self,
            didUpdateNowPlayingInfo: .init(
                isLiveStream: true,
                title: info.title,
                artwork: info.artwork,
                artist: info.artist,
                genre: info.genre,
                queue: .init(index: info.index, count: info.count),
            )
        )
    }

    func makeStationNowPlayingInfo(
        meta: SimStationMeta,
        index: Int,
        count: Int
    ) async -> StationNowPlayingInfo {
        let image: UIImage = if let artworkURL = meta.artwork,
                                let artwork = try? await KingfisherManager.shared.retrieveImage(with: artworkURL).image
        {
            artwork
        } else {
            UIImage()
        }

        return .init(
            title: meta.title,
            artwork: image,
            artist: meta.host,
            genre: meta.genre,
            index: index,
            count: count
        )
    }
}
