//
//  PlaylistBuilder.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 02.05.2025.
//

import Foundation

enum LibraryError: Error {
    case playlistError
    case fileNotFound(url: URL)
    case compositionCreatingError
}

enum PlaylistError: Error {
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
    /// Correctly handles trimming and time-shifting of components and their mixes.
    /// Assumes that the startTime of mixes from `makeDailyPlaylist` are absolute within the context of the day.
    /// - Parameters:
    ///   - playlistStart: Exact date and time for the playlist to start.
    ///   - duration: Total desired duration of the playlist in seconds.
    /// - Returns: An array of `AudioComponent` forming the requested playlist.
    /// - Throws: Errors related to playlist generation.
    func makePlaylist(
        startingAt playlistStart: Date,
        duration: TimeInterval
    ) async throws -> [PlaylistComponent] {
        guard duration > 0 else { return [] }
        let fullDayDuration: TimeInterval = 24 * 60 * 60
        var resultPlaylist: [PlaylistComponent] = []
        var accumulatedDuration: TimeInterval = 0.0
        var currentDate = playlistStart.startOfDay
        let timeOffsetInFirstDay = playlistStart.timeIntervalSince(currentDate)

        var dailyComponents = try await makeDailyPlaylist(for: currentDate)
        var currentDayIndex = 0

        // Find the index of the first relevant component
        while currentDayIndex < dailyComponents.count,
              dailyComponents[currentDayIndex].track.playing.end <= timeOffsetInFirstDay {
            currentDayIndex += 1
        }

        while accumulatedDuration < duration {
            // Move to the next day if necessary
            if currentDayIndex >= dailyComponents.count {
                guard let nextDay = currentDate.dayAfter else {
                    print("Error: failed to calculate next day for \(currentDate)")
                    break
                }
                currentDate = nextDay
                dailyComponents = try await makeDailyPlaylist(for: currentDate)
                currentDayIndex = 0
                if dailyComponents.isEmpty {
                    print("Warning: makeDailyPlaylist returned an empty list for \(currentDate)")
                    break
                }
                continue
            }

            let component = dailyComponents[currentDayIndex]

            var componentFileTimeRange = component.track.timeRange
            var componentPlayableDuration = component.track.timeRange.duration
            let componentStartTimeInOutput = accumulatedDuration // Start time in the output playlist

            let parentOriginalStartTimeInDay = component.track.startTime
            // Adjustment for start offset (only for the first component)
            if accumulatedDuration == 0.0 {
                let offsetIntoComponent = timeOffsetInFirstDay - parentOriginalStartTimeInDay
                if offsetIntoComponent > 0 {
                    let newDuration = component.track.timeRange.duration - offsetIntoComponent
                    if newDuration <= 0 {
                        currentDayIndex += 1
                        continue // Component is entirely before the playlist start
                    }
                    componentPlayableDuration = newDuration
                    componentFileTimeRange = TimeRange(
                        start: component.track.timeRange.start + offsetIntoComponent,
                        duration: componentPlayableDuration
                    )
                }
            }

            let remainingNeededDuration = duration - accumulatedDuration
            let remainingInDayDuration = max(0, fullDayDuration - parentOriginalStartTimeInDay)
            let actualDurationToAdd = min(componentPlayableDuration, remainingNeededDuration, remainingInDayDuration)

            if actualDurationToAdd <= 0 {
                break // Desired duration reached or component has no playable duration
            }

            if actualDurationToAdd < componentPlayableDuration {
                componentFileTimeRange = TimeRange(
                    start: componentFileTimeRange.start,
                    duration: actualDurationToAdd
                )
            }

            let parentActualStartTimeInDay = parentOriginalStartTimeInDay +
                (componentFileTimeRange.start - component.track.timeRange.start)

            let parentActualEndTimeInDay = parentActualStartTimeInDay + componentFileTimeRange.duration

            let adjustedMixes: [AudioFile] = component.mixes.compactMap { originalMix in
                originalMix.adjustedMix(
                    parentActualStartTimeInDay: parentActualStartTimeInDay,
                    parentActualEndTimeInDay: parentActualEndTimeInDay,
                    componentStartTimeInOutput: componentStartTimeInOutput
                )
            }

            let newComponent = PlaylistComponent(
                track: AudioFile(
                    url: component.track.url,
                    timeRange: componentFileTimeRange,
                    startTime: componentStartTimeInOutput
                ),
                mixes: adjustedMixes // List of processed and filtered mixes
            )
            resultPlaylist.append(newComponent)
            accumulatedDuration += actualDurationToAdd
            currentDayIndex += 1
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
    ) async throws -> [PlaylistComponent] {
        var rnd: any RandomNumberGenerator = SplitMix64(seed: UInt64(date.startOfDay.timeIntervalSince1970))
        let fullDayDuration: TimeInterval = 24 * 60 * 60
        return try await makePlaylist(duration: fullDayDuration, rnd: &rnd)
    }

    func makePlaylist(
        duration: TimeInterval,
        rnd: inout RandomNumberGenerator
    ) async throws -> [PlaylistComponent] {
        let rules = try PlaylistRules(
            stationID: stationData.station.id,
            model: station.playlistRules,
            fileGroups: Dictionary(uniqueKeysWithValues: fileGroups.map { ($0.id, $0) }),
            rnd: rnd
        )

        var result: [PlaylistComponent] = []
        var moment: Double = 0
        var fragmentTag = station.playlistRules.firstFragment.fragmentTag

        var next = try await nextFragmentTag(
            after: fragmentTag,
            rules: rules,
            rnd: &rnd
        )

        while moment < duration {
            let playlistComponent = try await makePlaylistComponent(
                tag: fragmentTag,
                nextTag: next,
                starts: moment,
                rules: rules,
                rnd: &rnd
            )
            result.append(playlistComponent)
            moment += playlistComponent.track.playing.duration
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
            throw PlaylistError.fragmentNotFound(tag: fragmentTag)
        }
        let rnd = Double.random(in: 0 ... 1, using: &rnd)
        var p = 0.0
        for next in fragment.nextFragment {
            p += next.probability ?? 1.0
            if rnd <= p {
                return next.fragmentTag
            }
        }
        throw PlaylistError.notExhaustiveFragment(tag: fragmentTag)
    }

    func makePlaylistComponent(
        tag: String,
        nextTag: String,
        starts sec: Double,
        rules: PlaylistRules,
        rnd: inout RandomNumberGenerator
    ) async throws -> PlaylistComponent {
        guard let fragment = rules.fragments[tag] else {
            throw PlaylistError.fragmentNotFound(tag: tag)
        }

        guard let file = fragment.src.next(parentFile: nil, rnd: &rnd) else {
            throw PlaylistError.wrongSource
        }
        let mixes = try await makeMixesForFragment(
            to: file,
            starts: sec,
            at: fragment.mixPositions,
            mixins: fragment.mixins,
            nextTag: nextTag,
            rnd: &rnd
        )
        return  PlaylistComponent(
            track: AudioFile(
                url: file.url(local: stationData.isDownloaded),
                timeRange: .init(start: 0, duration: file.file.duration),
                startTime: sec
            ),
            mixes: mixes
        )
    }

    // swiftlint:disable:next function_parameter_count
    func makeMixesForFragment(
        to file: FileFromGrpup,
        starts sec: Double,
        at positions: [String: Double],
        mixins: [PlaylistRules.Mix],
        nextTag: String,
        rnd: inout RandomNumberGenerator
    ) async throws -> [AudioFile] {
        var usedPositions: Set<String> = []
        var res: [AudioFile] = []
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
                    throw PlaylistError.wrongPositionTag(tag: posTag)
                }
                if let mixFile = mix.src.next(parentFile: file, rnd: &rnd) {
                    let t = file.file.duration - mixFile.file.duration
                    let mixStartsSec = sec + t * pos
                    res.append(AudioFile(
                        url: mixFile.url(local: stationData.isDownloaded),
                        timeRange: .init(start: 0, duration: mixFile.file.duration),
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

private extension AudioFile {
    func adjustedMix(
        parentActualStartTimeInDay: TimeInterval,
        parentActualEndTimeInDay: TimeInterval,
        componentStartTimeInOutput: TimeInterval
    ) -> AudioFile? {
        // Check for overlap: the mix must start before the end of the parent AND end after the start of the parent
        guard startTime < parentActualEndTimeInDay,
              playing.end > parentActualStartTimeInDay else { return nil }

        // Calculate the overlap interval within the day context
        let overlapStartInDay = max(parentActualStartTimeInDay, startTime)
        let overlapEndInDay = min(parentActualEndTimeInDay, playing.end)
        let overlapDuration = overlapEndInDay - overlapStartInDay

        // Only include if overlap has a positive duration
        guard overlapDuration > 0 else { return nil }

        let offsetIntoMixOriginal = max(0, overlapStartInDay - startTime)

        let adjustedMix = AudioFile(
            url: url,
            timeRange: TimeRange(
                start: timeRange.start + offsetIntoMixOriginal,
                duration: overlapDuration
            ),
            startTime: componentStartTimeInOutput + (overlapStartInDay - parentActualStartTimeInDay)
        )
        return adjustedMix
    }
}
