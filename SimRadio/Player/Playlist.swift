//
//  Playlist.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 29.01.2025.
//

@preconcurrency import AVFoundation

struct PlayingTime {
    let range: TimeRange
    let positionInComposition: TimeInterval
}

@MainActor
class Playlist {
    let baseUrl: URL
    let commonFiles: [SimRadio.FileGroup]
    let station: SimRadio.Station
    let timescale: CMTimeScale = 1000
    var nextPlayerItem: AVPlayerItem?
    var lastPlaying: (range: TimeRange, day: Date)?

    init(
        baseUrl: URL,
        commonFiles: [SimRadio.FileGroup],
        station: SimRadio.Station
    ) throws {
        self.baseUrl = baseUrl
        self.commonFiles = commonFiles
        self.station = station
    }

    func getPlayerItem(
        for day: Date,
        from: TimeInterval,
        minDuraton: TimeInterval
    ) async throws -> AVPlayerItem {
        let dayLength: TimeInterval = 24 * 60 * 60
        let to = from + minDuraton
        let playlistBuilder = PlaylistBuilder(
            baseUrl: baseUrl,
            commonFiles: commonFiles,
            station: station
        )
        srand48(Int(day.timeIntervalSince1970))
        let todaysPlaylist = try playlistBuilder.makePlaylist(duration: dayLength)
        let itemLoader = try PlayerItemLoaderInternal()

        let firstPlaylist = try await itemLoader.load(playlist: todaysPlaylist, from: from, to: to, withOffset: .zero)

        lastPlaying = (range: firstPlaylist.lastRange, day: day)

        if firstPlaylist.depleted {
            let nextDayFrom = firstPlaylist.lastRange.end - dayLength
            let tomorrowsTo = to - dayLength
            let tomorrow = day.dayAfter.startOfDay
            srand48(Int(tomorrow.timeIntervalSince1970))
            let playlistBuilder = PlaylistBuilder(
                baseUrl: baseUrl,
                commonFiles: commonFiles,
                station: station
            )
            let tomorrowsPlaylist = try playlistBuilder.makePlaylist(duration: dayLength)
            let lastPlayingTime = calcPlayingTime(range: firstPlaylist.lastRange, starting: from, withOffset: .zero)
            let offset = lastPlayingTime.range.duration + lastPlayingTime.positionInComposition
            let insertResult = try await itemLoader.load(
                playlist: tomorrowsPlaylist,
                from: nextDayFrom,
                to: tomorrowsTo,
                withOffset: offset
            )
            lastPlaying = (range: insertResult.lastRange, day: tomorrow)
        }
        return itemLoader.playerItem
    }

    func prepareNextPlayerItem(minDuraton: TimeInterval) async throws {
        guard let lastPlayingEnd = lastPlaying?.range.end, let lastPlayingDay = lastPlaying?.day else {
            throw LibraryError.playlistError
        }
        nextPlayerItem = try await getPlayerItem(for: lastPlayingDay, from: lastPlayingEnd, minDuraton: minDuraton)
    }
}

private func calcPlayingTime(
    range: TimeRange,
    starting from: TimeInterval,
    withOffset offset: TimeInterval
) -> PlayingTime {
    var itemStart: TimeInterval = 0
    if range.start < from {
        itemStart = from - range.start
    }
    let playingRange = TimeRange(start: itemStart, duration: range.duration - itemStart)
    let position = range.start - from + itemStart + offset

    return PlayingTime(range: playingRange, positionInComposition: position)
}

@MainActor
private class PlayerItemLoaderInternal {
    enum Destination: String {
        case main
        case mix
    }

    private let fadingDuration: Double = 1.0
    private let normalVolume: Float = 1.0
    private let lowVolume: Float = 0.3

    private var start: CMTime?
    private let composition: AVMutableComposition
    private let audioMix: AVMutableAudioMix
    private let mainTrack: AVMutableCompositionTrack
    private let mixTrack: AVMutableCompositionTrack
    private let params: AVMutableAudioMixInputParameters

    let timescale: CMTimeScale = 1000

    var playerItem: AVPlayerItem {
        audioMix.inputParameters = [params]
        let playerItem = AVPlayerItem(asset: composition)
        playerItem.audioMix = audioMix
        return playerItem
    }

    init() throws {
        composition = AVMutableComposition()
        audioMix = AVMutableAudioMix()
        guard let mainTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw LibraryError.compositionCreatingError
        }
        self.mainTrack = mainTrack
        guard let mixTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw LibraryError.compositionCreatingError
        }
        self.mixTrack = mixTrack
        params = AVMutableAudioMixInputParameters(track: mainTrack)
    }

    func load(
        _ item: AudioComponent,
        starting from: TimeInterval,
        to destination: Destination,
        withOffset offset: TimeInterval
    ) async throws {
        if item.playing.end <= from {
            return
        }
        let playingTime = calcPlayingTime(range: item.playing, starting: from, withOffset: offset)

        let destTrack = destination == .main ? mainTrack : mixTrack
        let asset = AVURLAsset(url: item.url)
                
        guard let assetTrack = try await asset.loadTracks(withMediaType: AVMediaType.audio).first else {
            throw LibraryError.fileNotFound(url: item.url)
        }
        
        try destTrack.insertTimeRange(
            .init(range: playingTime.range, scale: timescale),
            of: assetTrack,
            at: .init(seconds: playingTime.positionInComposition, preferredTimescale: timescale)
        )

        if destination == .mix {
            setVolumeRampParams(
                duration: playingTime.range.duration,
                at: playingTime.positionInComposition
            )
        }
    }

    func load(
        playlist: [AudioComponent],
        from: TimeInterval,
        to: TimeInterval,
        withOffset offset: TimeInterval
    ) async throws -> (depleted: Bool, lastRange: TimeRange) {
        var depleted = true
        var lastRange = TimeRange()
        for item in playlist {
            //            print("item \(urlTail(item.url)) \(item.playing.start.seconds.rounded(toPlaces: 2))-" +
            //                "\(item.playing.end.seconds.rounded(toPlaces: 2))")
            if item.playing.start > to {
                depleted = false
                break
            }
            lastRange = item.playing

            try await load(item, starting: from, to: .main, withOffset: offset)
            for mix in item.mixes {
                try await load(mix, starting: from, to: .mix, withOffset: offset)
            }
        }
        return (depleted: depleted, lastRange: lastRange)
    }

    private func setVolumeRampParams(duration: TimeInterval, at insertPosition: TimeInterval) {
        let fadeOutEnd = insertPosition
        let fadeOutStart = fadeOutEnd - fadingDuration
        let fadeInStart = insertPosition + duration
        let fadeInEnd = fadeInStart + fadingDuration

        params.setVolumeRamp(
            fromStartVolume: normalVolume,
            toEndVolume: lowVolume,
            timeRange: CMTimeRange(
                start: CMTime(seconds: fadeOutStart, preferredTimescale: timescale),
                end: CMTime(seconds: fadeOutEnd, preferredTimescale: timescale)
            )
        )

        params.setVolumeRamp(
            fromStartVolume: lowVolume,
            toEndVolume: normalVolume,
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
