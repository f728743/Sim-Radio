//
//  PlaylistBuilder.swift
//  Sim Radio
//

import AVFoundation

struct AudioFile {
    let tag: String?
    let url: URL
    let duration: CMTime
    let attaches: [AudioFile]

    init(baseUrl: URL, model: Model.File, timescale: CMTimeScale) throws {
        tag = model.tag
        var fileUrl = baseUrl
        fileUrl.appendPathComponent(model.path)
        url = fileUrl
        duration = CMTime(seconds: model.audibleDuration ?? model.duration,
                          preferredTimescale: timescale)
        attaches = try model.attaches?.files.map {
            try AudioFile(baseUrl: baseUrl, model: $0, timescale: timescale)
        } ?? []
    }
}

struct AudioComponent: CustomStringConvertible {
    let url: URL
    let playing: CMTimeRange
    let mixes: [AudioComponent]

    public var description: String {
        return "\(urlTail(url)), [\(playing.start.seconds.rounded(toPlaces: 2))-" +
        "\((playing.start.seconds + playing.duration.seconds).rounded(toPlaces: 2))]"
    }
}

protocol FileSource {
    func next(parentFile: AudioFile?) -> AudioFile?
}

enum SrcType: String {
    case group
    case attach
    case file
}

class ParticularFileSource: FileSource {
    let file: AudioFile

    init(file: AudioFile) {
        self.file = file
    }

    func next(parentFile _: AudioFile?) -> AudioFile? {
        return file
    }
}

class AttachedFileSource: FileSource {
    func next(parentFile: AudioFile?) -> AudioFile? {
        if let file = parentFile, file.attaches.count > 0 {
            return file.attaches[Int(drand48() * Double(file.attaches.count))]
        }
        return nil
    }
}

class GroupFileSource: FileSource {
    let randomfiles: RandomFilePick

    init(files: [AudioFile]) throws {
        randomfiles = try RandomFilePick(from: files, withDontRepeatRatio: 3.0 / 7.0)
    }

    func next(parentFile _: AudioFile?) -> AudioFile? {
        return randomfiles.next()
    }
}

class RandomFilePick {
    private var discardPile: [AudioFile] = []
    private var draw: [AudioFile] = []
    private let maxDiscardPileCount: Int

    init(from: [AudioFile], withDontRepeatRatio: Double) throws {
        maxDiscardPileCount = max(1, Int(withDontRepeatRatio * Double(from.count)))
        if from.count < 2 {
            throw LibraryError.wrongSource
        }
        draw = from
    }

    func next() -> AudioFile {
        let index = Int(drand48() * Double(draw.count))
        let res = draw[index]

        discardPile.append(res)
        draw.remove(at: index)
        if discardPile.count > maxDiscardPileCount {
            let putBack = discardPile[0]
            discardPile.remove(at: 0)
            draw.append(putBack)
        }
        return res
    }
}

func createFileSource(model: Model.Source, fileGroups: AudioFileGroups) throws -> FileSource {
    switch SrcType(rawValue: model.type) {
    case .file:
        guard let fileTag = model.fileTag, let groupTag = model.groupTag, let files = fileGroups[groupTag],
            let file = files.first(where: { $0.tag == fileTag }) else { throw LibraryError.wrongSource }
        return ParticularFileSource(file: file)
    case .group:
        guard let groupTag = model.groupTag, let files = fileGroups[groupTag] else { throw LibraryError.wrongSource }
        return try GroupFileSource(files: files)
    case .attach:
        return AttachedFileSource()
    default:
        throw LibraryError.wrongSource
    }
}

protocol MixPlayngCondition {
    func isAccepted(nextFragment tag: Tag, starts sec: TimeInterval) -> Bool
}

class ConditionGroupAnd: MixPlayngCondition {
    let group: [MixPlayngCondition]

    init(group: [Model.Conditon]?) throws {
        guard let group = group, group.count > 1 else {
            throw LibraryError.wrongCondition
        }
        self.group = try group.map { try createCondition(model: $0) }
    }

    func isAccepted(nextFragment tag: Tag, starts sec: TimeInterval) -> Bool {
        return !group.isEmpty && group.firstIndex(where: {
            $0.isAccepted(nextFragment: tag, starts: sec) == false
        }) == nil
    }
}

class ConditionGroupOr: MixPlayngCondition {
    let group: [MixPlayngCondition]

    init(group: [Model.Conditon]?) throws {
        guard let group = group, group.count > 1 else {
            throw LibraryError.wrongCondition
        }
        self.group = try group.map { try createCondition(model: $0) }
    }

    func isAccepted(nextFragment tag: Tag, starts sec: TimeInterval) -> Bool {
        return group.firstIndex(where: { $0.isAccepted(nextFragment: tag, starts: sec) }) != nil
    }
}

class MixConditionRandom: MixPlayngCondition {
    let threshold: Double
    init(threshold: Double) {
        self.threshold = threshold
    }

    func isAccepted(nextFragment tag: Tag, starts sec: TimeInterval) -> Bool {
        let rnd = drand48()
        return rnd <= threshold
    }
}

class MixConditionNext: MixPlayngCondition {
    let next: String
    init(next: String) {
        self.next = next
    }

    func isAccepted(nextFragment tag: Tag, starts sec: TimeInterval) -> Bool {
        return next == tag
    }
}

func secOfDay(hhmm: String) -> Double? {
    let time = hhmm.split { $0 == ":" }.map(String.init)
    guard time.count > 1 else {
        return nil
    }

    guard let h = Double(time[0]), let m = Double(time[1]) else {
        return nil
    }
    return (h * 60 * 60) + (m * 60)
}

class MixConditionTime: MixPlayngCondition {
    let from: TimeInterval
    let to: TimeInterval
    init(from: String?, to: String?) throws {
        guard let fromStr = from, let toStr = to,
            let from = secOfDay(hhmm: fromStr), let to = secOfDay(hhmm: toStr) else {
            throw LibraryError.wrongCondition
        }
        self.from = from
        self.to = to
    }

    func isAccepted(nextFragment tag: Tag, starts sec: TimeInterval) -> Bool {
        return from <= sec && sec <= to
    }
}

enum ConditionType: String {
    case nextFragment
    case random
    case groupAnd
    case groupOr
    case timeInterval
}

func createCondition(model: Model.Conditon) throws -> MixPlayngCondition {
    switch ConditionType(rawValue: model.type) {
    case .nextFragment:
        guard let next = model.fragmentTag else {
            throw LibraryError.wrongCondition
        }
        return MixConditionNext(next: next)
    case .random:
        guard let probability = model.probability else {
            throw LibraryError.wrongCondition
        }
        return MixConditionRandom(threshold: probability)
    case .groupAnd:
        return try ConditionGroupAnd(group: model.condition)
    case .groupOr:
        return try ConditionGroupOr(group: model.condition)
    case .timeInterval:
        return try MixConditionTime(from: model.from, to: model.to)
    default:
        throw LibraryError.wrongSource
    }
}

class PlaylistScheme {
    class RandomFilePick {
        private var discardPile: [AudioFile] = []
        private var draw: [AudioFile] = []
        private let maxDiscardPileCount: Int

        init?(from: [AudioFile], withDontRepeatRatio: Double) {
            maxDiscardPileCount = max(1, Int(withDontRepeatRatio * Double(from.count)))
            if from.count < 2 {
                return nil
            }
            draw = from
        }

        func next() -> AudioFile {
            let index = Int(drand48() * Double(draw.count))
            let res = draw[index]

            discardPile.append(res)
            draw.remove(at: index)
            if discardPile.count > maxDiscardPileCount {
                let putBack = discardPile[0]
                discardPile.remove(at: 0)
                draw.append(putBack)
            }
            return res
        }
    }

    struct Mix {
        var src: FileSource
        var condition: MixPlayngCondition
        var positions: [Tag]
        init(model: Model.Mix, fileGroups: AudioFileGroups) throws {
            src = try createFileSource(model: model.src, fileGroups: fileGroups)
            condition = try createCondition(model: model.condition)
            positions = model.posVariant.map { $0.posTag }
        }
    }

    struct Fragment {
        let src: FileSource
        let nextFragment: [Model.FragmentRef]
        let mixPositions: [Tag: Double] // TODO: get rid
        let mixins: [Mix]

        init(model: Model.Fragment, fileGroups: AudioFileGroups) throws {
            src = try createFileSource(model: model.src, fileGroups: fileGroups)
            nextFragment = model.nextFragment
            mixPositions = model.mixins == nil ? [:] :
                Dictionary(uniqueKeysWithValues: model.mixins!.pos.map { ($0.tag, $0.relativeOffset) })
            mixins = model.mixins == nil ? [] : try model.mixins!.mix.map { try Mix(model: $0, fileGroups: fileGroups) }
        }
    }

    let fileGroups: AudioFileGroups
    let firstFragmentTag: Tag
    let fragments: [Tag: Fragment]

    init(model: Model.Playlist, fileGroups: AudioFileGroups) throws {
        firstFragmentTag = model.firstFragment.fragmentTag
        fragments = Dictionary(uniqueKeysWithValues: try model.fragments.map {
            ($0.tag, try Fragment(model: $0, fileGroups: fileGroups))
        })
        self.fileGroups = fileGroups
    }
}

class PlaylistBuilder {
    let station: Station
    let timescale: CMTimeScale
    let stationFiles: AudioFileGroups
    let scheme: PlaylistScheme

    init(commonFiles: AudioFileGroups, station: Station, timescale: CMTimeScale) throws {
        self.station = station
        self.timescale = timescale
        stationFiles = Dictionary(uniqueKeysWithValues: try station.model.fileGroups.map {
            ($0.tag, try $0.files.map { try AudioFile(baseUrl: station.directoryURL, model: $0, timescale: timescale) })
        })
        scheme = try PlaylistScheme(
            model: station.model.playlist,
            fileGroups: stationFiles.merging(commonFiles, uniquingKeysWith: { first, _ in first })
        )
    }

    func createPlaylist(duration: TimeInterval) throws -> [AudioComponent] {
        var result: [AudioComponent] = []
        var moment: CMTime = CMTime.zero
        let playlistModel = station.model.playlist
        var fragmentTag = playlistModel.firstFragment.fragmentTag

        let dayLength = CMTime(seconds: duration, preferredTimescale: timescale)
        var nextFragmentTag = try getNextFragmentTag(after: fragmentTag)

        while moment < dayLength {
            let fragment = try makeFragment(tag: fragmentTag, nextTag: nextFragmentTag, starts: moment)
            result.append(fragment)
            // swiftlint:disable shorthand_operator
            moment = moment + fragment.playing.duration
            // swiftlint:enable shorthand_operator
            fragmentTag = nextFragmentTag
            nextFragmentTag = try getNextFragmentTag(after: fragmentTag)
        }
        return result
    }

    private func getNextFragmentTag(after fragmentTag: Tag) throws -> Tag {
        guard let fragment = scheme.fragments[fragmentTag] else {
            throw LibraryError.fragmentNotFound(tag: fragmentTag)
        }
        let rnd = drand48()
        var p = 0.0
        for next in fragment.nextFragment {
            p += next.probability ?? 1.0
            if rnd <= p {
                return next.fragmentTag
            }
        }
        throw LibraryError.notExhaustiveFragment(tag: fragmentTag)
    }

    private func makeFragment(tag: Tag, nextTag: Tag, starts sec: CMTime) throws -> AudioComponent {
        guard let fragment = scheme.fragments[tag] else {
            throw LibraryError.fragmentNotFound(tag: tag)
        }

        guard let file = fragment.src.next(parentFile: nil) else {
            throw LibraryError.wrongSource
        }
        let mixes = try makeFragmentMixin(to: file,
                                          starts: sec,
                                          at: fragment.mixPositions,
                                          mixins: fragment.mixins,
                                          nextTag: nextTag)
        let range = CMTimeRange(start: sec, duration: file.duration)
        return AudioComponent(url: file.url, playing: range, mixes: mixes)
    }

    private func makeFragmentMixin(to file: AudioFile,
                                   starts sec: CMTime,
                                   at positions: [Tag: Double],
                                   mixins: [PlaylistScheme.Mix],
                                   nextTag: Tag) throws -> [AudioComponent] {
        var usedPositions: Set<Tag> = []
        var res: [AudioComponent] = []
        for mix in mixins {
            if mix.condition.isAccepted(nextFragment: nextTag, starts: sec.seconds) {
                for posTag in mix.positions {
                    if usedPositions.contains(posTag) {
                        continue
                    }
                    guard let pos = positions[posTag] else {
                        throw LibraryError.wrongPositionTag(tag: posTag)
                    }
                    if let mixFile = mix.src.next(parentFile: file) {
                        let t = file.duration - mixFile.duration
                        let mixStartsSec = sec + CMTime(seconds: t.seconds * pos, preferredTimescale: timescale)
                        let range = CMTimeRange(start: mixStartsSec, duration: mixFile.duration)
                        res.append(AudioComponent(url: mixFile.url, playing: range, mixes: []))
                        usedPositions.insert(posTag)
                        break
                    }
                }
            }
        }
        return res.sorted { $0.playing.start < $1.playing.start }
    }
}
