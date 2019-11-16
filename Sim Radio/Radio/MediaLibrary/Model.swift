//
//  Model.swift
//  RadioDownloader
//

import Foundation

typealias Tag = String

enum Model {
    static func loadSeries(from url: URL) throws -> Series {
        return try JSONDecoder().decode(Series.self, from: try Data(contentsOf: url))
    }

    static func loadStation(from url: URL) throws -> Station {
        let res = try JSONDecoder().decode(Station.self, from: try Data(contentsOf: url))
        return res
    }

    struct File: Codable {
        let tag: Tag?
        let path: String
        let duration: Double
        let audibleDuration: Double?
        let attaches: Attaches?
    }

    struct Attaches: Codable {
        let files: [File]
    }

    struct FileGroup: Codable {
        let tag: Tag
        let files: [File]
    }

    struct StationInfo: Codable {
        let title: String
        let genre: String
        let logo: String
        let dj: String?
    }

    struct FirstFragment: Codable {
        let tag: Tag
    }

    struct FragmentRef: Codable {
        let fragmentTag: Tag
        let probability: Double?
    }

    struct Source: Codable {
        let type: String
        let groupTag: Tag?
        let fileTag: Tag?
    }

    struct Position: Codable {
        let tag: Tag
        let relativeOffset: Double
    }

    struct PosVariant: Codable {
        let posTag: Tag
    }

    struct Conditon: Codable {
        let type: String
        let fragmentTag: Tag?
        let probability: Double?
        let from: String?
        let to: String?
        let condition: [Conditon]?
    }

    struct Mix: Codable {
        let tag: Tag
        let src: Source
        let condition: Conditon
        let posVariant: [PosVariant]
    }

    struct Mixin: Codable {
        let pos: [Position]
        let mix: [Mix]
    }

    struct Fragment: Codable {
        let tag: Tag
        let src: Source
        let nextFragment: [FragmentRef]
        let mixins: Mixin?
    }

    struct Playlist: Codable {
        let firstFragment: FragmentRef
        let fragments: [Fragment]
    }

    struct Station: Codable {
        let tag: Tag
        let info: StationInfo
        let fileGroups: [FileGroup]
        let playlist: Playlist
    }

    struct SeriesCommon: Codable {
        let fileGroups: [FileGroup]
    }

    struct SeriesInfo: Codable {
        let title: String
        let logo: String
    }

    struct StationReference: Codable {
        let path: String
    }

    struct Series: Codable {
        let info: SeriesInfo
        let common: SeriesCommon
        let stations: [StationReference]
    }
}
