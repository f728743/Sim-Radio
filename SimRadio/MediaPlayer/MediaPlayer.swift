//
//  MediaPlayer.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 30.11.2024.
//

import MediaPlayer

enum MediaPlayerState {
    case playing(MediaID)
    case stopped
}

@MainActor
class MediaPlayer {
    var simRadio: SimRadioMediaPlayer?
    private var state: MediaPlayerState = .stopped
    private var audioSession: AudioSession
    private var systemMediaInterface: SystemMediaInterface

    init() {
        audioSession = AudioSession()
        systemMediaInterface = SystemMediaInterface()
        audioSession.delegate = self
        systemMediaInterface.delegate = self
    }

    func play(_ mediaID: MediaID) {
        switch state {
        case .playing: break
        case .stopped:
            switch mediaID {
            case let .simRadio(stationID):
                systemMediaInterface.configureRemoteCommands(
                    isLiveStream: true,
                    isSwitchTrackEnabled: true
                )
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

extension MediaPlayer: AudioSessionDelegate {
    func audioSessionInterruptionBegan() {
        // TODO:
    }

    func audioSessionInterruptionEnded(shouldResume _: Bool) {
        // TODO:
    }
}

extension MediaPlayer: SystemMediaInterfaceDelegate {
    func systemMediaInterface(_: SystemMediaInterface, didReceiveRemoteCommand _: RemoteCommand) {
        // TODO:
    }
}

extension MediaPlayer: SimRadioMediaPlayerDelegate {
    func simRadioMediaPlayer(_: SimRadioMediaPlayer, didUpdateNowPlayingInfo info: NowPlayingInfo) {
        systemMediaInterface.set(nowPlayingInfo: info)
    }
}
