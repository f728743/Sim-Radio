//
//  DefaultSimRadioMediaPlayer.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 01.05.2025.
//

import AVFoundation

@MainActor
class DefaultSimRadioMediaPlayer {
    weak var mediaState: SimRadioMediaState?

    private let queuePlayer = AVQueuePlayer()
    private let audioTapProcessor: AudioTapProcessor
    private var nextPlayableItem: NextPlayableItem?
    private let config: DefaultSimRadioMediaPlayer.Config = .default
    private var observer: NSObjectProtocol?
    private var playToEndTask: Task<Void, Never>?
    var tracksObserver: NSKeyValueObservation?

    init() {
        audioTapProcessor = AudioTapProcessor()
        audioTapProcessor.delegate = self
    }
}

extension DefaultSimRadioMediaPlayer.Config {
    static let `default` = DefaultSimRadioMediaPlayer.Config(
        initialPlaylistMinDuration: 60,
        bufferedPlaylistMinDuration: 10 * 60
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
        queuePlayer.removeAllItems()
        playToEndTask?.cancel()
        playToEndTask = nil
    }
}

extension DefaultSimRadioMediaPlayer: AudioTapProcessorDelegate {
    nonisolated func audioTapProcessor(_: AudioTapProcessor, didUpdateSpectrum spectrum: [[Float]]) {
        print("didUpdateSpectrum", spectrum.first?.count ?? 0)
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
        let playerItem = try await loader.loadPlayerItem(
            playlist: playlist,
            tapProcessor: audioTapProcessor
        )
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
        let playerItem = try await loader.loadPlayerItem(
            playlist: playlist,
            tapProcessor: audioTapProcessor
        )
        return NextPlayableItem(
            stationID: stationID,
            item: playerItem,
            day: date + playlist.duration.seconds,
            startTimeInDay: time + playlist.duration
        )
    }
}
