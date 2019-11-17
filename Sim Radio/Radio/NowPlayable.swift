//
//  NowPlayable.swift
//  Sim Radio
//

import Foundation
import MediaPlayer

struct NowPlayableStaticMetadata {
    let mediaType: MPNowPlayingInfoMediaType
    let isLiveStream: Bool
    let title: String
    let artist: String?
    let artwork: MPMediaItemArtwork?
    let albumTitle: String?
    let trackNumber: Int
    let trackCount: Int
}

enum NowPlayableInterruption {
    case began, ended(Bool), failed(Error)
}

enum NowPlayableCommand: CaseIterable {
    case pause, play, stop, togglePausePlay, nextTrack, previousTrack

    var remoteCommand: MPRemoteCommand {
        let remoteCommandCenter = MPRemoteCommandCenter.shared()

        switch self {
        case .pause:
            return remoteCommandCenter.pauseCommand
        case .play:
            return remoteCommandCenter.playCommand
        case .stop:
            return remoteCommandCenter.stopCommand
        case .togglePausePlay:
            return remoteCommandCenter.togglePlayPauseCommand
        case .nextTrack:
            return remoteCommandCenter.nextTrackCommand
        case .previousTrack:
            return remoteCommandCenter.previousTrackCommand
        }
    }

    func removeHandler() {
        remoteCommand.removeTarget(nil)
    }

    func addHandler(_ handler: @escaping (NowPlayableCommand, MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus) {
        remoteCommand.addTarget { handler(self, $0) }
    }

    func setDisabled(_ isDisabled: Bool) {
        remoteCommand.isEnabled = !isDisabled
    }
}

class NowPlayableBehavior {
    private var interruptionObserver: NSObjectProtocol!
    private var interruptionHandler: (NowPlayableInterruption) -> Void = { _ in }

    func handleNowPlayableConfiguration(
        commands: [NowPlayableCommand],
        disabledCommands: [NowPlayableCommand],
        commandHandler: @escaping (NowPlayableCommand, MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus,
        interruptionHandler: @escaping (NowPlayableInterruption) -> Void
    ) throws {
        self.interruptionHandler = interruptionHandler
        try configureRemoteCommands(commands, disabledCommands: disabledCommands, commandHandler: commandHandler)
    }

    func startSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [unowned self] notification in
            self.handleAudioSessionInterruption(notification: notification)
        }
        try audioSession.setCategory(.playback, mode: .default)
        //        try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])

        try audioSession.setActive(true)
    }

    func endSession() {
        interruptionObserver = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session, error: \(error)")
        }
    }

    private func handleAudioSessionInterruption(notification: Notification) {
        print(notification)
        guard let userInfo = notification.userInfo,
            let interruptionTypeUInt = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeUInt) else { return }

        switch interruptionType {
        case .began:
            interruptionHandler(.began)

        case .ended:
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                var shouldResume = false
                if let optionsUInt = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
                    AVAudioSession.InterruptionOptions(rawValue: optionsUInt).contains(.shouldResume) {
                    shouldResume = true
                }
                interruptionHandler(.ended(shouldResume))
            } catch {
                interruptionHandler(.failed(error))
            }

        @unknown default:
            break
        }
    }
}

extension NowPlayableBehavior {
    func configureRemoteCommands(_ commands: [NowPlayableCommand],
                                 disabledCommands: [NowPlayableCommand],
                                 commandHandler: @escaping (NowPlayableCommand, MPRemoteCommandEvent
        ) -> MPRemoteCommandHandlerStatus) throws {
        for cmd in NowPlayableCommand.allCases {
            cmd.removeHandler()
            if commands.contains(cmd) {
                cmd.addHandler(commandHandler)
            }
            cmd.setDisabled(disabledCommands.contains(cmd))
        }
    }

    func setNowPlayingMetadata(_ metadata: NowPlayableStaticMetadata) {
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        var nowPlayingInfo = [String: Any]()

        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = metadata.mediaType.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = metadata.isLiveStream
        nowPlayingInfo[MPMediaItemPropertyTitle] = metadata.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = metadata.artist
        nowPlayingInfo[MPMediaItemPropertyArtwork] = metadata.artwork
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = metadata.albumTitle
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = metadata.trackNumber + 1
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackCount] = metadata.trackCount
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = metadata.trackNumber
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = metadata.trackCount
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 24 * 60 * 60
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentSecondOfDay()

        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
}
