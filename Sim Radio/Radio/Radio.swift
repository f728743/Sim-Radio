//
//  Radio.swift
//  Sim Radio
//

import MediaPlayer
import UIKit

struct RadioDisplay {
    let logo: UIImage
    let title: String
    let genre: String?
    let dj: String?
}

protocol RadioControl {
    func play(station: Station)
    func togglePausePlay()
    func nextStation()
    func previousStation()
    func turnOff()
}

class Radio {
    private var isInterrupted: Bool = false
    private var player: AVPlayer?
    private var playerNum = 0
    private var playerCounter = 0
    private let playlistManager: PlaylistManager

    private let nowPlayableBehavior = NowPlayableBehavior()

    var display: RadioDisplay {
        if let station = currentStation {
            let info = station.model.info
            return RadioDisplay(logo: station.logo, title: info.title, genre: info.genre, dj: info.dj)
        }
        return RadioDisplay(logo: UIImage(named: "Cover Artwork")!, title: "Not Playing", genre: nil, dj: nil)
    }

    let library = MediaLibrary()

    var playPauseButtonState: PlayPauseButtonState {
        if case .playing = state {
            return .pause
        }
        return .play
    }

    var switchStarionEnabled: Bool {
        return currentSeries?.stations.count ?? 0 > 1
    }

    private(set) var state = State.idle {
        didSet {
            stateDidChange()
        }
    }

    private var currentStation: Station? {
        switch state {
        case .idle:
            return nil
        case let .playing(station), let .paused(station):
            return station
        }
    }

    private var currentSeries: Series? {
        switch state {
        case .idle:
            return nil
        case let .playing(station), let .paused(station):
            return station.series
        }
    }

    private var observations = [ObjectIdentifier: Observation]()

    init() {
        playlistManager = PlaylistManager(library: library)
        let registeredCommands: [NowPlayableCommand] =
            [.togglePausePlay,
             .play,
             .pause,
             .stop,
             .nextTrack,
             .previousTrack]

        let disabledCommands = [NowPlayableCommand]()

        do {
            try nowPlayableBehavior.handleNowPlayableConfiguration(
                commands: registeredCommands, disabledCommands: disabledCommands,
                commandHandler: handleCommand(command:event:),
                interruptionHandler: handleInterrupt(with:)
            )

            try nowPlayableBehavior.startSession()
        } catch {
            print("Failed to handleNowPlayableConfiguration, error: \(error)")
        }
    }

    func stateDidChange() {
        for (id, observation) in observations {
            // If the observer is no longer in memory, we
            // can clean up the observation for its ID
            guard let observer = observation.observer else {
                observations.removeValue(forKey: id)
                continue
            }

            switch state {
            case .idle:
                observer.radioDidStop(self)

            case let .playing(station):
                updateNowPlayableMetadata(station)
                observer.radio(self, didStartPlaying: station)

            case let .paused(station):
                updateNowPlayableMetadata(station)
                observer.radio(self, didPausePlaybackOf: station)
            }
        }
    }

    func nextStation(after station: Station) -> Station {
        let stations = station.series.stations
        guard let index = stations.firstIndex(where: { $0 === station }) else {
            return station
        }
        let nextStationIndex = index + 1 >= stations.count ? 0 : index + 1
        return stations[nextStationIndex]
    }

    func previousStation(before station: Station) -> Station {
        let stations = station.series.stations
        guard let index = stations.firstIndex(where: { $0 === station }) else {
            return station
        }
        let previousStationIndex = index == 0 ? stations.count - 1 : index - 1
        return stations[previousStationIndex]
    }
}

extension Radio {
    private func handleCommand(command: NowPlayableCommand,
                               event _: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        switch command {
        case .pause:
            switch state {
            case .playing:
                togglePausePlay()
            default:
                break
            }

        case .play:
            switch state {
            case .paused, .idle:
                togglePausePlay()
            default:
                break
            }

        case .stop:
            switch state {
            case .playing:
                togglePausePlay()
            default:
                break
            }

        case .togglePausePlay:
            togglePausePlay()

        case .nextTrack:
            nextStation()

        case .previousTrack:
            previousStation()
        }

        return .success
    }

    private func handleInterrupt(with interruption: NowPlayableInterruption) {
        switch interruption {
        case .began:
            print("interrupted began")
            isInterrupted = true

        case let .ended(shouldPlay):
            print("interrupted ended, shouldPlay = ", shouldPlay)

            isInterrupted = false
            if case .playing(let station) = state {
                if shouldPlay {
                    startPlayback(station: station)
                } else {
                    pause()
                }
            }
        case let .failed(error):
            print(error.localizedDescription)
        }
    }

    func updateNowPlayableMetadata(_ station: Station) {
        let img = display.logo

        var trackNumber = 0
        var trackCount = 0

        let stations = station.series.stations
        if let mumber = stations.firstIndex(where: { $0 === station }) {
            trackCount = stations.count
            trackNumber = mumber
        }

        var artist = display.dj
        if let a = artist {
            artist = "Hosted by \(a)"
        }

        let meta = NowPlayableStaticMetadata(
            mediaType: .audio,
            isLiveStream: true,
            title: display.title,
            artist: artist,
            artwork: MPMediaItemArtwork(boundsSize: img.size) { _ in img },
            albumTitle: display.genre,
            trackNumber: trackNumber,
            trackCount: trackCount
        )
        nowPlayableBehavior.setNowPlayingMetadata(meta)
    }
}

// MARK: RadioControl extension

extension Radio: RadioControl {
    func play(station: Station) {
        if case let .playing(currentStation) = state {
            if currentStation === station {
                return
            }
        }
        state = .playing(station: station)
        startPlayback(station: station)
    }

    func togglePausePlay() {
        switch state {
        case .idle:
            let nonEmptySeries = library.series.filter { $0.stations.count > 0 }
            guard !nonEmptySeries.isEmpty else { return }
            let series = nonEmptySeries[Int(drand48() * Double(nonEmptySeries.count))]
            let stations = series.stations
            guard !stations.isEmpty else { return }
            let station = stations[Int(drand48() * Double(stations.count))]
            state = .playing(station: station)
            startPlayback(station: station)

        case let .playing(station):
            state = .paused(station: station)
            stopPlayback()

        case let .paused(station):
            state = .playing(station: station)
            startPlayback(station: station)
        }
    }

    func nextStation() {
        switch state {
        case let .playing(station):
            play(station: nextStation(after: station))
        case let .paused(station):
            state = .paused(station: nextStation(after: station))
        default:
            break
        }
    }

    func previousStation() {
        switch state {
        case let .playing(station):
            play(station: previousStation(before: station))
        case let .paused(station):
            state = .paused(station: previousStation(before: station))
        default:
            break
        }
    }

    func turnOff() {
        state = .idle
        player = nil
        nowPlayableBehavior.endSession()
    }
}

func currentSecondOfDay() -> Double {
    let now = Date()
    let calendar = Calendar.current

    let h = calendar.component(.hour, from: now)
    let m = calendar.component(.minute, from: now)
    let s = calendar.component(.second, from: now)
    return Double(h * 60 * 60 + m * 60 + s)
}

private extension Radio {
    enum PlayingMode {
        case playingFirst
        case playingNext
    }

    func startPlayback(station: Station) {
        player = nil
        play(station: station, mode: .playingFirst)
    }

    func stopPlayback() {
        player = nil
    }

    func play(station: Station, mode: PlayingMode) {
        guard let playlist = try? playlistManager.getPlaylist(of: station) else {
            return
        }

        let nowSec = currentSecondOfDay()
        guard let playerItem = mode == .playingFirst ? try? playlist.getFirstPlayerItem(
            fromSecond: nowSec, minDuraton: 1 * 60) : playlist.nextPlayerItem else {
                return
        }

        let player = AVPlayer(playerItem: playerItem)
        player.play()
        self.player = player
        playerNum = playerCounter
        playerCounter += 1
        // in order to prevent the frequent creating of a long playlist in cases of
        // quick button presses before creating playlist we waiting a couple of seconds
        Timer.scheduledTimer(timeInterval: 2.0,
                             target: self,
                             selector: #selector(scheduleKeepPlaying),
                             userInfo: (playerNum: playerNum,
                                        playlist: playlist,
                                        playerItem: playerItem,
                                        station: station),
                             repeats: false)
    }

    @objc func scheduleKeepPlaying(timer: Timer) {
        if let userInfo = timer.userInfo as? (playerNum: Int,
            playlist: Playlist,
            playerItem: AVPlayerItem,
            station: Station) {
            if userInfo.playerNum == self.playerNum {
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: userInfo.playerItem,
                    queue: .main
                ) { [weak self] _ in
                    self?.play(station: userInfo.station, mode: .playingNext)
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    try? userInfo.playlist.prepareNextPlayerItem(minDuraton: 1 * 60 * 60)
                }
            }
        }
    }
}

extension Radio {
    enum PlayPauseButtonState {
        case play
        case pause
    }
}

extension Radio {
    enum State {
        case idle
        case playing(station: Station)
        case paused(station: Station)
    }
}

protocol RadioObserver: class {
    func radio(_ radio: Radio, didStartPlaying station: Station)
    func radio(_ radio: Radio, didPausePlaybackOf station: Station)
    func radioDidStop(_ radio: Radio)
}

extension RadioObserver {
    func radio(_ radio: Radio, didStartPlaying station: Station) {}
    func radio(_ radio: Radio, didPausePlaybackOf station: Station) {}
    func radioDidStop(_ radio: Radio) {}
}

private extension Radio {
    struct Observation {
        weak var observer: RadioObserver?
    }
}

extension Radio {
    func addObserver(_ observer: RadioObserver) {
        let id = ObjectIdentifier(observer)
        observations[id] = Observation(observer: observer)
    }

    func removeObserver(_ observer: RadioObserver) {
        let id = ObjectIdentifier(observer)
        observations.removeValue(forKey: id)
    }
}
