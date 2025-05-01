//
//  MediaPlayer.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 30.11.2024.
//

enum MediaPlayerState {
    case playing(MediaID)
    case stopped
}

@MainActor
class MediaPlayer {
    var simRadio: SimRadioMediaPlayer?
    private var state: MediaPlayerState = .stopped

    func play(_ mediaID: MediaID) {
        switch state {
        case .playing: break
        case .stopped:
            switch mediaID {
            case let .simRadio(stationID):
                simRadio?.playStation(withID: stationID)
            default: break
            }
            state = .playing(mediaID)
        }
    }

    func stop() {
        switch state {
        case let .playing(mediaID):
            switch mediaID {
            case .simRadio: simRadio?.stop()
            default: break
            }
            state = .stopped
        case .stopped:
            break
        }
    }
}
