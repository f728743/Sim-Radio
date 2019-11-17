//
//  Playlist.swift
//  Sim Radio
//

import AVFoundation

func urlTail(_ url: URL) -> String {
    let pattern = #".+\/(.+\/.+)"#
    let urlString = url.absoluteString
    let regex = try? NSRegularExpression(pattern: pattern)
    if let match = regex?.firstMatch(in: urlString,
                                     options: [],
                                     range: NSRange(location: 0, length: urlString.utf16.count)) {
        if let tailRange = Range(match.range(at: 1), in: urlString) {
            return String(urlString[tailRange])
        }
    }
    return urlString
}

struct PlayingTime {
    let range: CMTimeRange
    let positionInComposition: CMTime
}

func calcPlayingTime(range: CMTimeRange, starting from: CMTime, withOffset offset: CMTime) -> PlayingTime {
    var itemStart = CMTime.zero
    if range.start < from {
        itemStart = from - range.start
    }
    let playingRange = CMTimeRange(start: itemStart, duration: range.duration - itemStart)
    let position = range.start - from + itemStart + offset

    return PlayingTime(range: playingRange, positionInComposition: position)
}

class Compositor {
    enum Destination: String {
        case main
        case mix
    }

    let fadingDuration: Double = 1.0
    let normalVolume: Float = 1.0
    let lowVolume: Float = 0.3

    var start: CMTime?
    let composition: AVMutableComposition
    let audioMix: AVMutableAudioMix
    let mainTrack: AVMutableCompositionTrack
    let mixTrack: AVMutableCompositionTrack
    let params: AVMutableAudioMixInputParameters

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
            preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw LibraryError.compositionCreatingError
        }
        self.mainTrack = mainTrack
        guard let mixTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw LibraryError.compositionCreatingError
        }
        self.mixTrack = mixTrack
        params = AVMutableAudioMixInputParameters(track: mainTrack)
    }

    func insert(_ item: AudioComponent,
                starting from: CMTime,
                to destination: Destination,
                withOffset offset: CMTime) throws {
        if item.playing.end <= from {
            return
        }
        let playingTime = calcPlayingTime(range: item.playing, starting: from, withOffset: offset)

        //        print("  \(urlTail(item.url)), \(item.playing.start.seconds.rounded(toPlaces: 2))" +
        //            "-\(item.playing.end.seconds.rounded(toPlaces: 2)) range " +
        //            "\(playingTime.range.start.seconds.rounded(toPlaces: 2))-" +
        //            "\(playingTime.range.end.seconds.rounded(toPlaces: 2)), at" +
        //            " \(playingTime.positionInComposition.seconds.rounded(toPlaces: 2))")

        let compositionTrack = destination == .main ? mainTrack : mixTrack
        let asset = AVURLAsset(url: item.url)
        guard let assetTrack = asset.tracks(withMediaType: AVMediaType.audio).first else {
            throw LibraryError.fileNotFound(url: item.url) // TODO: replace by tuning sounds
        }
        try compositionTrack.insertTimeRange(playingTime.range, of: assetTrack, at: playingTime.positionInComposition)
        if destination == .mix {
            setVolumeRampParams(duration: playingTime.range.duration, at: playingTime.positionInComposition)
        }
    }

    func insert(playlist: [AudioComponent],
                from: CMTime,
                to: CMTime,
                withOffset offset: CMTime) throws -> (depleted: Bool, lastRange: CMTimeRange) {
        var depleted = true
        var lastRange = CMTimeRange()
        for item in playlist {
//            print("item \(urlTail(item.url)) \(item.playing.start.seconds.rounded(toPlaces: 2))-" +
//                "\(item.playing.end.seconds.rounded(toPlaces: 2))")
            if item.playing.start > to {
                depleted = false
                break
            }
            lastRange = item.playing

            try insert(item, starting: from, to: .main, withOffset: offset)
            for mix in item.mixes {
                try insert(mix, starting: from, to: .mix, withOffset: offset)
            }
        }
        return (depleted: depleted, lastRange: lastRange)
    }

    func setVolumeRampParams(duration: CMTime, at insertPosition: CMTime) {
        let fadingDuration = CMTime(seconds: self.fadingDuration, preferredTimescale: insertPosition.timescale)
        let fadeOutEnd = insertPosition
        let fadeOutStart = fadeOutEnd - fadingDuration
        let fadeInStart = insertPosition + duration
        let fadeInEnd = fadeInStart + fadingDuration
        params.setVolumeRamp(fromStartVolume: normalVolume, toEndVolume: lowVolume,
                             timeRange: CMTimeRange(start: fadeOutStart, end: fadeOutEnd))
        params.setVolumeRamp(fromStartVolume: lowVolume, toEndVolume: normalVolume,
                             timeRange: CMTimeRange(start: fadeInStart, end: fadeInEnd))
    }
}

class Playlist {
    let commonFiles: AudioFileGroups
    let station: Station
    let timescale: CMTimeScale
    var nextPlayerItem: AVPlayerItem?
    var lastPlaying: (range: CMTimeRange, day: Date)?

    init(commonFiles: AudioFileGroups, station: Station, timescale: CMTimeScale) throws {
        self.commonFiles = commonFiles
        self.station = station
        self.timescale = timescale
    }

    func getFirstPlayerItem(fromSecond: TimeInterval, minDuraton: TimeInterval) throws -> AVPlayerItem {
        let second = CMTime(seconds: fromSecond, preferredTimescale: timescale)
        return try getPlayerItem(for: Date().startOfDay, from: second, minDuraton: minDuraton)
    }

    func getPlayerItem(for day: Date, from: CMTime, minDuraton: TimeInterval) throws -> AVPlayerItem {
        let dayLength: TimeInterval = 24 * 60 * 60
        let cmDayLength = CMTime(seconds: dayLength, preferredTimescale: timescale)
        let to = from + CMTime(seconds: minDuraton, preferredTimescale: timescale)
        let playlistBuilder = try PlaylistBuilder(commonFiles: commonFiles, station: station, timescale: timescale)
        srand48(Int(day.timeIntervalSince1970))
        let todaysPlaylist = try playlistBuilder.createPlaylist(duration: dayLength)
        let compositor = try Compositor()
        let firstPlaylist = try compositor.insert(playlist: todaysPlaylist, from: from, to: to, withOffset: .zero)
        lastPlaying = (range: firstPlaylist.lastRange, day: day)
        if firstPlaylist.depleted {
            let nextDayFrom = firstPlaylist.lastRange.end - cmDayLength
            let tomorrowsTo = to - cmDayLength
            let tomorrow = day.dayAfter.startOfDay
            srand48(Int(tomorrow.timeIntervalSince1970))
            let playlistBuilder = try PlaylistBuilder(commonFiles: commonFiles, station: station, timescale: timescale)
            let tomorrowsPlaylist = try playlistBuilder.createPlaylist(duration: dayLength)
            let lastPlayingTime = calcPlayingTime(range: firstPlaylist.lastRange, starting: from, withOffset: .zero)
            let offset = lastPlayingTime.range.duration + lastPlayingTime.positionInComposition
            let insertResult = try compositor.insert(
                playlist: tomorrowsPlaylist,
                from: nextDayFrom,
                to: tomorrowsTo,
                withOffset: offset)
            lastPlaying = (range: insertResult.lastRange, day: tomorrow)
        }
        return compositor.playerItem
    }

    func prepareNextPlayerItem(minDuraton: TimeInterval) throws {
        guard let lastPlayingEnd = lastPlaying?.range.end, let lastPlayingDay = lastPlaying?.day else {
            throw LibraryError.playlistError
        }
        nextPlayerItem = try getPlayerItem(for: lastPlayingDay, from: lastPlayingEnd, minDuraton: minDuraton)
    }
}
