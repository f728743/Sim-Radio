//
//  PlaylistBuilder.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 02.05.2025.
//

import AVFoundation

enum PlayerItemLoadingError: Error {
    case playlistError
    case fileNotFound(url: URL)
    case playerItemCreatingError
}

enum PlaylistGenerationError: Error {
    case makeDailyPlaylistError(date: Date)
    case makePlaylistError
    case wrongCondition
    case fragmentNotFound(tag: String)
    case notExhaustiveFragment(tag: String)
    case wrongPositionTag(tag: String)
    case wrongSource
}

class PlaylistBuilder {
    let stationData: SimRadioStationData

    init(stationData: SimRadioStationData) {
        self.stationData = stationData
    }

    // swiftlint:disable cyclomatic_complexity function_body_length

    /// Generates a playlist of the specified duration (`duration`),
    /// starting from the given date/time (`playlistStart`).
    /// Correctly handles trimming and time-shifting of items and their mixes.
    /// Assumes that the startTime of mixes from `makeDailyPlaylist` are absolute within the context of the day.
    /// - Parameters:
    ///   - playlistStart: Exact date and time for the playlist to start.
    ///   - duration: Total desired duration of the playlist in seconds.
    /// - Returns: An array of `PlaylistItem` forming the requested playlist.
    /// - Throws: Errors related to playlist generation.
    func makePlaylist(
        startingOn playlistStartDate: Date,
        at timeOffsetInFirstDay: CMTime,
        duration: CMTime,
        trimLastItem: Bool = false
    ) async throws -> [PlaylistItem] {
        guard duration > .zero else { return [] }
        let fullDayDuration = CMTime(seconds: 24 * 60 * 60)
        var resultPlaylist: [PlaylistItem] = []
        var accumulatedDuration: CMTime = .zero
        var currentDate = playlistStartDate.startOfDay

        var dailyItems = try await makeDailyPlaylist(for: currentDate)

        // Find the index of the first relevant item
        guard let firstRelevantItem = dailyItems.firstIndex(
            where: { $0.track.playing.end > timeOffsetInFirstDay }
        ) else {
            throw PlaylistGenerationError.makeDailyPlaylistError(date: currentDate)
        }

        var index = firstRelevantItem

        while accumulatedDuration < duration {
            // Move to the next day if necessary
            if index >= dailyItems.count {
                guard let nextDay = currentDate.dayAfter else {
                    throw PlaylistGenerationError.makePlaylistError
                }
                currentDate = nextDay
                dailyItems = try await makeDailyPlaylist(for: currentDate)
                index = 0
                guard !dailyItems.isEmpty else {
                    throw PlaylistGenerationError.makeDailyPlaylistError(date: currentDate)
                }
                continue
            }

            let item = dailyItems[index]

            var itemFileTimeRange = item.track.timeRange
            var itemPlayableDuration = item.track.timeRange.duration
            let itemStartTimeInOutput = accumulatedDuration // Start time in the output playlist

            let parentOriginalStartTimeInDay = item.track.startTime
            // Adjustment for start offset (only for the first item)
            if accumulatedDuration == .zero {
                let offsetIntoItem = timeOffsetInFirstDay - parentOriginalStartTimeInDay
                if offsetIntoItem > .zero {
                    let newDuration = item.track.timeRange.duration - offsetIntoItem
                    if newDuration <= .zero {
                        index += 1
                        continue // Item is entirely before the playlist start
                    }
                    itemPlayableDuration = newDuration
                    itemFileTimeRange = CMTimeRange(
                        start: item.track.timeRange.start + offsetIntoItem,
                        duration: itemPlayableDuration
                    )
                }
            }

            let remainingNeededDuration = duration - accumulatedDuration
            let remainingInDayDuration = max(.zero, fullDayDuration - parentOriginalStartTimeInDay)
            let actualDurationToAdd = trimLastItem
                ? min(min(itemPlayableDuration, remainingNeededDuration), remainingInDayDuration)
                : min(itemPlayableDuration, remainingInDayDuration)

            if actualDurationToAdd <= .zero {
                break // Desired duration reached or item has no playable duration
            }

            if actualDurationToAdd < itemPlayableDuration {
                itemFileTimeRange = CMTimeRange(
                    start: itemFileTimeRange.start,
                    duration: actualDurationToAdd
                )
            }

            let parentActualStartTimeInDay = parentOriginalStartTimeInDay +
                (itemFileTimeRange.start - item.track.timeRange.start)

            let parentActualEndTimeInDay = parentActualStartTimeInDay + itemFileTimeRange.duration

            let adjustedMixes: [AudioSegment] = item.mixes.compactMap { originalMix in
                originalMix.adjustedMix(
                    parentActualStartTimeInDay: parentActualStartTimeInDay,
                    parentActualEndTimeInDay: parentActualEndTimeInDay,
                    itemStartTimeInOutput: itemStartTimeInOutput
                )
            }

            let newItem = PlaylistItem(
                track: AudioSegment(
                    url: item.track.url,
                    timeRange: itemFileTimeRange,
                    startTime: itemStartTimeInOutput
                ),
                mixes: adjustedMixes // List of processed and filtered mixes
            )
            resultPlaylist.append(newItem)
            accumulatedDuration += actualDurationToAdd
            index += 1
        }
        return resultPlaylist
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}

private extension PlaylistBuilder {
    var station: SimStation {
        stationData.station
    }

    var fileGroups: [SimFileGroup] {
        stationData.fileGroups
    }

    func makeDailyPlaylist(
        for date: Date,
    ) async throws -> [PlaylistItem] {
        var rnd: any RandomNumberGenerator = SplitMix64(seed: UInt64(date.startOfDay.timeIntervalSince1970))
        let fullDayDuration: TimeInterval = 24 * 60 * 60
        return try await makePlaylist(
            duration: .init(seconds: fullDayDuration),
            rnd: &rnd
        )
    }

    func makePlaylist(
        duration: CMTime,
        rnd: inout RandomNumberGenerator
    ) async throws -> [PlaylistItem] {
        let rules = try PlaylistRules(
            stationID: stationData.station.id,
            model: station.playlistRules,
            fileGroups: Dictionary(uniqueKeysWithValues: fileGroups.map { ($0.id, $0) }),
            rnd: rnd
        )

        var result: [PlaylistItem] = []
        var moment: CMTime = .zero
        var fragmentTag = station.playlistRules.firstFragment.fragmentTag

        var next = try await nextFragmentTag(
            after: fragmentTag,
            rules: rules,
            rnd: &rnd
        )

        while moment < duration {
            let playlistItem = try await makePlaylistItem(
                tag: fragmentTag,
                nextTag: next,
                starts: moment,
                rules: rules,
                rnd: &rnd
            )
            result.append(playlistItem)
            moment += playlistItem.track.playing.duration
            fragmentTag = next
            next = try await nextFragmentTag(
                after: fragmentTag,
                rules: rules,
                rnd: &rnd
            )
        }
        return result
    }

    func nextFragmentTag(
        after fragmentTag: String,
        rules: PlaylistRules,
        rnd: inout RandomNumberGenerator
    ) async throws -> String {
        guard let fragment = rules.fragments[fragmentTag] else {
            throw PlaylistGenerationError.fragmentNotFound(tag: fragmentTag)
        }
        let rnd = Double.random(in: 0 ... 1, using: &rnd)
        var p = 0.0
        for next in fragment.nextFragment {
            p += next.probability ?? 1.0
            if rnd <= p {
                return next.fragmentTag
            }
        }
        throw PlaylistGenerationError.notExhaustiveFragment(tag: fragmentTag)
    }

    func makePlaylistItem(
        tag: String,
        nextTag: String,
        starts sec: CMTime,
        rules: PlaylistRules,
        rnd: inout RandomNumberGenerator
    ) async throws -> PlaylistItem {
        guard let fragment = rules.fragments[tag] else {
            throw PlaylistGenerationError.fragmentNotFound(tag: tag)
        }

        guard let file = fragment.src.next(parentFile: nil, rnd: &rnd) else {
            throw PlaylistGenerationError.wrongSource
        }
        let mixes = try await makeMixesForFragment(
            to: file,
            starts: sec,
            at: fragment.mixPositions,
            mixins: fragment.mixins,
            nextTag: nextTag,
            rnd: &rnd
        )
        return PlaylistItem(
            track: AudioSegment(
                url: file.url(local: stationData.isDownloaded),
                timeRange: .init(
                    start: .zero,
                    duration: .init(seconds: file.file.duration)
                ),
                startTime: sec
            ),
            mixes: mixes
        )
    }

    // swiftlint:disable:next function_parameter_count
    func makeMixesForFragment(
        to file: FileFromGrpup,
        starts sec: CMTime,
        at positions: [String: Double],
        mixins: [PlaylistRules.Mix],
        nextTag: String,
        rnd: inout RandomNumberGenerator
    ) async throws -> [AudioSegment] {
        var usedPositions: Set<String> = []
        var res: [AudioSegment] = []
        for mix in mixins where mix.condition.isSatisfied(
            forNextFragment: nextTag,
            startingFrom: sec,
            rnd: &rnd
        ) == true {
            for posTag in mix.positions {
                if usedPositions.contains(posTag) {
                    continue
                }
                guard let pos = positions[posTag] else {
                    throw PlaylistGenerationError.wrongPositionTag(tag: posTag)
                }
                if let mixFile = mix.src.next(parentFile: file, rnd: &rnd) {
                    let t = file.file.duration - mixFile.file.duration
                    let mixStartsSec = sec + .init(seconds: t * pos)
                    res.append(AudioSegment(
                        url: mixFile.url(local: stationData.isDownloaded),
                        timeRange: .init(start: .zero, duration: .init(seconds: mixFile.file.duration)),
                        startTime: mixStartsSec
                    ))
                    usedPositions.insert(posTag)
                    break
                }
            }
        }
        return res.sorted { $0.playing.start < $1.playing.start }
    }
}

private extension AudioSegment {
    func adjustedMix(
        parentActualStartTimeInDay: CMTime,
        parentActualEndTimeInDay: CMTime,
        itemStartTimeInOutput: CMTime
    ) -> AudioSegment? {
        // Check for overlap: the mix must start before the end of the parent AND end after the start of the parent
        guard startTime < parentActualEndTimeInDay,
              playing.end > parentActualStartTimeInDay else { return nil }

        // Calculate the overlap interval within the day context
        let overlapStartInDay = max(parentActualStartTimeInDay, startTime)
        let overlapEndInDay = min(parentActualEndTimeInDay, playing.end)
        let overlapDuration = overlapEndInDay - overlapStartInDay

        // Only include if overlap has a positive duration
        guard overlapDuration > .zero else { return nil }

        let offsetIntoMixOriginal = max(.zero, overlapStartInDay - startTime)

        let adjustedMix = AudioSegment(
            url: url,
            timeRange: CMTimeRange(
                start: timeRange.start + offsetIntoMixOriginal,
                duration: overlapDuration
            ),
            startTime: itemStartTimeInOutput + (overlapStartInDay - parentActualStartTimeInDay)
        )
        return adjustedMix
    }
}
