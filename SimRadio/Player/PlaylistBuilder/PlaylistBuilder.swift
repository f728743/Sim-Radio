//
//  PlaylistBuilder.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 28.01.2025.
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

extension Double {
    static var rand48: Double {
        DRand48.drand48()
    }
}

public actor DRand48 {
    private static var state: UInt64 = 0
    static func srand48(_ seed: Int) {
        state = UInt64(seed) & 0xFFFF_FFFF_FFFF
    }

    static func drand48() -> Double {
        state = (25_214_903_917 &* state + 11) & 0xFFFF_FFFF_FFFF
        return Double(state) / Double(1 << 48)
    }
}

class PlaylistBuilder {
    let baseUrl: URL
    let gameSeriesSharedFiles: [SimRadioDTO.FileGroup]
    let station: SimRadioDTO.Station

    init(
        baseUrl: URL,
        gameSeriesSharedFiles: [SimRadioDTO.FileGroup],
        station: SimRadioDTO.Station
    ) {
        self.baseUrl = baseUrl
        self.gameSeriesSharedFiles = gameSeriesSharedFiles
        self.station = station
    }

    func makePlaylist(duration: TimeInterval) async throws -> [AudioComponent] {
        let rules = try await PlaylistRules(model: station.playlist, fileGroups: fileGroups)

        var result: [AudioComponent] = []
        var moment: Double = 0
        var fragmentTag = station.playlist.firstFragment.fragmentTag

        var next = try await nextFragmentTag(after: fragmentTag, rules: rules)

        while moment < duration {
            let fragment = try await makeFragment(
                tag: fragmentTag,
                nextTag: next,
                starts: moment,
                rules: rules
            )
            result.append(fragment)
            moment += fragment.playing.duration
            fragmentTag = next
            next = try await nextFragmentTag(after: fragmentTag, rules: rules)
        }
        return result
    }
}

private extension PlaylistBuilder {
    var fileGroups: AudioFileGroups {
        get async {
            let stationBaseUrl: URL = baseUrl.appendingPathComponent(station.tag)
            let stationFiles = await convert(files: station.fileGroups, baseUrl: stationBaseUrl)
            let gameSeriesSharedFiles = await convert(files: gameSeriesSharedFiles, baseUrl: baseUrl)
            return stationFiles.merging(gameSeriesSharedFiles, uniquingKeysWith: { first, _ in first })
        }
    }

    func convert(files: [SimRadioDTO.FileGroup], baseUrl: URL) async -> AudioFileGroups {
        Dictionary(
            uniqueKeysWithValues: files.map {
                let fileList = $0.files.map {
                    AudioFile(baseUrl: baseUrl, model: $0)
                }
                return ($0.tag, fileList)
            }
        )
    }

    func nextFragmentTag(after fragmentTag: String, rules: PlaylistRules) async throws -> String {
        guard let fragment = rules.fragments[fragmentTag] else {
            throw PlaylistError.fragmentNotFound(tag: fragmentTag)
        }
        let rnd = Double.rand48
        var p = 0.0
        for next in fragment.nextFragment {
            p += next.probability ?? 1.0
            if rnd <= p {
                return next.fragmentTag
            }
        }
        throw PlaylistError.notExhaustiveFragment(tag: fragmentTag)
    }

    func makeFragment(
        tag: String,
        nextTag: String,
        starts sec: Double,
        rules: PlaylistRules
    ) async throws -> AudioComponent {
        guard let fragment = rules.fragments[tag] else {
            throw PlaylistError.fragmentNotFound(tag: tag)
        }

        guard let file = fragment.src.next(parentFile: nil) else {
            throw PlaylistError.wrongSource
        }
        let mixes = try await makeMixesForFragment(
            to: file,
            starts: sec,
            at: fragment.mixPositions,
            mixins: fragment.mixins,
            nextTag: nextTag
        )
        let range = TimeRange(
            start: sec,
            duration: file.duration
        )
        return AudioComponent(url: file.url, playing: range, mixes: mixes)
    }

    func makeMixesForFragment(
        to file: AudioFile,
        starts sec: Double,
        at positions: [String: Double],
        mixins: [PlaylistRules.Mix],
        nextTag: String
    ) async throws -> [AudioComponent] {
        var usedPositions: Set<String> = []
        var res: [AudioComponent] = []
        for mix in mixins where mix.condition.isSatisfied(forNextFragment: nextTag, startingFrom: sec) == true {
            for posTag in mix.positions {
                if usedPositions.contains(posTag) {
                    continue
                }
                guard let pos = positions[posTag] else {
                    throw PlaylistError.wrongPositionTag(tag: posTag)
                }
                if let mixFile = mix.src.next(parentFile: file) {
                    let t = file.duration - mixFile.duration
                    let mixStartsSec = sec + t * pos
                    let range = TimeRange(
                        start: mixStartsSec,
                        duration: mixFile.duration
                    )
                    res.append(AudioComponent(url: mixFile.url, playing: range, mixes: []))
                    usedPositions.insert(posTag)
                    break
                }
            }
        }
        return res.sorted { $0.playing.start < $1.playing.start }
    }
}

extension Double {
    func rounded(places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

struct TimeRange {
    var start: TimeInterval = 0
    var duration: TimeInterval = 0

    var end: TimeInterval {
        start + duration
    }
}

struct AudioComponent: Sendable {
    let url: URL
    let playing: TimeRange
    let mixes: [AudioComponent]
}

extension AudioComponent: CustomStringConvertible {
    func description(nesting: Int) -> String {
        let from = playing.start.rounded(places: 2)
        let to = (playing.start + playing.duration).rounded(places: 2)
        let indent = String(repeating: "  ", count: nesting)
        return [
            "\(indent)(\(from)..\(to)): \(url.pathComponents.suffix(2).joined(separator: "/"))",
            mixes.description(nesting: nesting + 1)
        ].joined(separator: "\n")
    }

    var description: String {
        description(nesting: 0)
    }
}

extension Array where Element == AudioComponent {
    func description(nesting: Int) -> String {
        map { $0.description(nesting: nesting) }.joined(separator: "")
    }

    var description: String {
        map(\.description).joined(separator: "")
    }
}

private class PlaylistRules {
    let fileGroups: AudioFileGroups
    let firstFragmentTag: String
    let fragments: [String: Fragment]

    init(
        model: SimRadioDTO.Playlist,
        fileGroups: AudioFileGroups
    ) throws {
        firstFragmentTag = model.firstFragment.fragmentTag
        fragments = try Dictionary(uniqueKeysWithValues: model.fragments.map {
            try ($0.tag, Fragment(model: $0, fileGroups: fileGroups))
        })
        self.fileGroups = fileGroups
    }

    struct Mix {
        var src: FileSource
        let condition: SimRadioDTO.Condition
        var positions: [String]

        init(
            model: SimRadioDTO.Mix,
            fileGroups: AudioFileGroups
        ) throws {
            guard let src = makeFileSource(model: model.src, fileGroups: fileGroups) else {
                throw PlaylistError.wrongSource
            }
            self.src = src
            condition = model.condition
            positions = model.posVariant.map { $0.posTag }
        }
    }

    struct Fragment {
        let src: FileSource
        let nextFragment: [SimRadioDTO.FragmentRef]
        let mixPositions: [String: Double]
        let mixins: [Mix]

        init(
            model: SimRadioDTO.Fragment,
            fileGroups: AudioFileGroups
        ) throws {
            guard let src = makeFileSource(model: model.src, fileGroups: fileGroups) else {
                throw PlaylistError.wrongSource
            }
            self.src = src
            nextFragment = model.nextFragment
            mixPositions = model.mixins == nil ? [:] :
                Dictionary(uniqueKeysWithValues: model.mixins!.pos.map { ($0.tag, $0.relativeOffset) })
            mixins = model.mixins == nil ? [] : try model.mixins!.mix.map { try Mix(model: $0, fileGroups: fileGroups) }
        }
    }
}
