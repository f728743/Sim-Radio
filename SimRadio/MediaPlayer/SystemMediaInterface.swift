//
//  SystemMediaInterface.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 08.05.2025.
//

import MediaPlayer

@MainActor
protocol SystemMediaInterfaceDelegate: AnyObject {
    func systemMediaInterface(_ interface: SystemMediaInterface, didReceiveRemoteCommand command: RemoteCommand)
}

@MainActor
class SystemMediaInterface {
    weak var delegate: SystemMediaInterfaceDelegate?

    func configureRemoteCommands(isLiveStream: Bool, isSwitchTrackEnabled: Bool) {
        let commands: [RemoteCommand] = isLiveStream ? [
            .play, .stop, .nextTrack, .previousTrack
        ] : [
            .play, .pause, .stop, .togglePausePlay, .nextTrack, .previousTrack
        ]
        configureRemoteCommands(
            commands,
            disabledCommands: isSwitchTrackEnabled ? [] : [.nextTrack, .previousTrack]
        )
    }

    func set(nowPlayingInfo: NowPlayingInfo) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo.mpNowPlayingInfo
    }
}

private extension SystemMediaInterface {
    func configureRemoteCommands(_ commands: [RemoteCommand], disabledCommands: [RemoteCommand]) {
        for command in RemoteCommand.allCases {
            command.removeHandler()
            if commands.contains(command) {
                command.addHandler { [weak self] remoteCommand, _ in
                    guard let self else { return .commandFailed }
                    delegate?.systemMediaInterface(self, didReceiveRemoteCommand: remoteCommand)
                    return .success
                }
            }
            command.setDisabled(disabledCommands.contains(command))
        }
    }
}

extension RemoteCommand {
    var mpRemoteCommand: MPRemoteCommand {
        let commandCenter = MPRemoteCommandCenter.shared()

        switch self {
        case .pause:
            return commandCenter.pauseCommand
        case .play:
            return commandCenter.playCommand
        case .stop:
            return commandCenter.stopCommand
        case .togglePausePlay:
            return commandCenter.togglePlayPauseCommand
        case .nextTrack:
            return commandCenter.nextTrackCommand
        case .previousTrack:
            return commandCenter.previousTrackCommand
        }
    }

    func removeHandler() {
        mpRemoteCommand.removeTarget(nil)
    }

    func addHandler(_ handler: @escaping (RemoteCommand, MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus) {
        mpRemoteCommand.addTarget { handler(self, $0) }
    }

    func setDisabled(_ isDisabled: Bool) {
        mpRemoteCommand.isEnabled = !isDisabled
    }
}

extension NowPlayingInfo {
    var mpNowPlayingInfo: [String: Any] {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = isLiveStream
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        if let queue {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = queue.index
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = queue.count
        }
        if let playback {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = CMTime(seconds: playback.duration)
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTime(seconds: playback.elapsedTime)
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0
        }
        return nowPlayingInfo
    }
}
