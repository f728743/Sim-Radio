//
//  PlayerItemLoader.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 03.05.2025.
//

@preconcurrency import AVFoundation

@MainActor
class PlayerItemLoader {
    let timescale: CMTimeScale = 1000

    func loadPlayerItem(
        playlist: [PlaylistComponent]
    ) async throws -> AVPlayerItem {        
        let composition = AVMutableComposition()
        let audioMix = AVMutableAudioMix()
        guard let mainTrack = composition.addAudioTrack(),
              let mixTrack = composition.addAudioTrack() else {
            throw LibraryError.compositionCreatingError
        }
        let params = AVMutableAudioMixInputParameters(track: mainTrack)
        for item in playlist {
            try await load(item.track, track: mainTrack)
            for mix in item.mixes {
                try await load(mix, track: mixTrack)
                params.setVolumeDip(
                    range: .init(
                        start: mix.startTime,
                        duration: mix.playing.duration
                    ),
                    timescale: timescale
                )
            }
        }
        audioMix.inputParameters = [params]
        let playerItem = AVPlayerItem(asset: composition)
        playerItem.audioMix = audioMix
        return playerItem
    }
}

private extension PlayerItemLoader {
    func load(
        _ audio: AudioFile,
        track: AVMutableCompositionTrack
    ) async throws {
        let asset = AVURLAsset(url: audio.url)
        guard let assetTrack = try await asset.loadTracks(withMediaType: AVMediaType.audio).first else {
            throw LibraryError.fileNotFound(url: audio.url)
        }
        try track.insertTimeRange(
            .init(range: audio.timeRange, scale: timescale),
            of: assetTrack,
            at: .init(seconds: audio.startTime, preferredTimescale: timescale)
        )
    }
}

extension AVMutableComposition {
    func addAudioTrack() -> AVMutableCompositionTrack? {
        addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    }
}

struct VolumeDipParams {
    let normalVolume: Float
    let lowVolume: Float
    let fadingDuration: TimeInterval
}

extension VolumeDipParams {
    static let `default` = VolumeDipParams(
        normalVolume: 1,
        lowVolume: 0.3,
        fadingDuration: 1
    )
}

extension AVMutableAudioMixInputParameters {
    func setVolumeDip(
        range: TimeRange,
        params: VolumeDipParams = .default,
        timescale: CMTimeScale
    ) {
        let fadeOutEnd = range.start
        let fadeOutStart = fadeOutEnd - params.fadingDuration
        let fadeInStart = range.end
        let fadeInEnd = fadeInStart + params.fadingDuration

        setVolumeRamp(
            fromStartVolume: params.normalVolume,
            toEndVolume: params.lowVolume,
            timeRange: CMTimeRange(
                start: CMTime(seconds: fadeOutStart, preferredTimescale: timescale),
                end: CMTime(seconds: fadeOutEnd, preferredTimescale: timescale)
            )
        )

        setVolumeRamp(
            fromStartVolume: params.lowVolume,
            toEndVolume: params.normalVolume,
            timeRange: CMTimeRange(
                start: CMTime(seconds: fadeInStart, preferredTimescale: timescale),
                end: CMTime(seconds: fadeInEnd, preferredTimescale: timescale)
            )
        )
    }
}

extension CMTimeRange {
    init(range: TimeRange, scale: CMTimeScale) {
        self.init(
            start: CMTime(seconds: range.start, preferredTimescale: scale),
            duration: CMTime(seconds: range.duration, preferredTimescale: scale)
        )
    }
}
