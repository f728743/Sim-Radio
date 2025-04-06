//
//  SimRadioMedia.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 26.03.2025.
//

import Foundation

struct SimRadioMedia {
    let series: [SimSeries.ID: SimSeries]
    let fileGroups: [SimFileGroup.ID: SimFileGroup]
    let stations: [SimStation.ID: SimStation]
}

struct SimSeries {
    struct ID: Hashable { let value: String }
    var id: ID
    let meta: MediaList.Meta
    let stations: [SimStation.ID]
}

struct SimFileGroup {
    struct ID: Hashable { let value: String }
    let id: ID
    let files: [SimFile]
}

struct SimFile: Sendable {
    let url: URL
    let tag: String?
    let duration: Double
    let attaches: [SimFile]
}

struct SimStation {
    struct ID: Hashable { let value: String }
    var id: ID
    let meta: Media.Meta
    let fileGroups: [SimFileGroup.ID]
    let playlistRules: SimRadioDTO.Playlist
}

extension SimRadioMedia {
    static let empty: SimRadioMedia = .init(
        series: [:],
        fileGroups: [:],
        stations: [:]
    )
}

private extension URL {
    var simRadioBaseURL: URL {
        deletingLastPathComponent()
    }

    var nonCryptoHash: UInt64 {
        absoluteString.nonCryptoHash
    }
}

extension SimRadioDTO.Series {
    func simFileGroups(origin: URL) -> [SimFileGroup.ID: SimFileGroup] {
        let common = common.fileGroups.map { SimFileGroup(dto: $0, origin: origin) }
        let stations = stations.flatMap { station in
            station.fileGroups.map { SimFileGroup(dto: $0, origin: origin, pathTag: station.tag) }
        }
        return Dictionary(
            uniqueKeysWithValues: (common + stations).map { ($0.id, $0) }
        )
    }
}

extension SimRadioMedia {
    init(dto: SimRadioDTO.Series, origin: URL) {
        let series = SimSeries(dto: dto, origin: origin)
        let stations = dto.stations.map { SimStation(dto: $0, common: dto.common, origin: origin) }
        self.init(
            series: Dictionary(uniqueKeysWithValues: [(series.id, series)]),
            fileGroups: dto.simFileGroups(origin: origin),
            stations: Dictionary(uniqueKeysWithValues: stations.map { ($0.id, $0) })
        )
    }
}

extension SimSeries {
    init(dto: SimRadioDTO.Series, origin: URL) {
        self.init(
            id: .init(origin: origin),
            meta: .init(
                artwork: origin.simRadioBaseURL.appendingPathComponent(dto.info.logo),
                title: dto.info.title,
                subtitle: nil
            ),
            stations: dto.stations.map { stationID(origin: origin, stationTag: $0.tag) }
        )
    }

    static let defaultFileName: String = "sim_radio_stations.json"
    static let userDefaultsKey: String = "sim_series_ids"
}

extension SimRadioDTO.StationInfo {
    var detailsSubtitle: String {
        dj.map { "Hosted by \($0) – \(genre)" } ?? genre
    }
}

extension SimStation {
    init(dto: SimRadioDTO.Station, common: SimRadioDTO.SeriesCommon, origin: URL) {
        let artwork = origin.simRadioBaseURL
            .appendingPathComponent(dto.tag)
            .appendingPathComponent(dto.info.logo)
        let fullFileGroupSet = Set(dto.playlist.fileGroupTags)
        let commonFileGroupSet = Set(common.fileGroups.map { $0.tag })
        let stationFileGroups = fullFileGroupSet
            .subtracting(commonFileGroupSet)
            .map { fileGroupID(origin: origin, pathTag: dto.tag, groupTag: $0) }
        let usedCommonFileGroupSet = fullFileGroupSet.intersection(commonFileGroupSet)
        let usedCommonFileGroups = usedCommonFileGroupSet.map { fileGroupID(origin: origin, groupTag: $0) }
        self.init(
            id: stationID(origin: origin, stationTag: dto.tag),
            meta: .init(
                artwork: artwork,
                title: dto.info.title,
                listSubtitle: dto.info.genre,
                detailsSubtitle: dto.info.detailsSubtitle,
                online: true
            ),
            fileGroups: stationFileGroups + usedCommonFileGroups,
            playlistRules: dto.playlist
        )
    }
}

extension SimSeries.ID {
    var directoryURL: URL {
        .documentsDirectory.appending(path: value, directoryHint: .isDirectory)
    }

    init(origin: URL) {
        self.init(value: "\(origin.nonCryptoHash)")
    }
}

extension SimRadioDTO.Playlist {
    var fileGroupTags: [String] {
        fragments.flatMap { [$0.src] + ($0.mixins?.mix ?? []).map { $0.src } }
            .filter { $0.type == SimRadioDTO.SrcType.group || $0.type == SimRadioDTO.SrcType.file }
            .compactMap { $0.groupTag }
    }
}

private func stationID(origin: URL, stationTag: String) -> SimStation.ID {
    .init(value: "\(SimSeries.ID(origin: origin).value)/\(stationTag)")
}

private func fileGroupID(origin: URL, pathTag: String? = nil, groupTag: String) -> SimFileGroup.ID {
    let path = pathTag.map { "/\($0)" } ?? ""
    return .init(value: "\(origin.nonCryptoHash)\(path)/\(groupTag)")
}

extension SimFileGroup {
    init(dto: SimRadioDTO.FileGroup, origin: URL, pathTag: String? = nil) {
        self.init(
            id: fileGroupID(origin: origin, pathTag: pathTag, groupTag: dto.tag),
            files: dto.files.map { .init(dto: $0, baseUrl: origin.simRadioBaseURL, pathTag: pathTag) }
        )
    }
}

extension SimFile {
    init(dto: SimRadioDTO.File, baseUrl: URL, pathTag: String?) {
        let url = [pathTag, dto.path].compactMap { $0 }.reduce(baseUrl) { $0.appendingPathComponent($1) }
        self.init(
            url: url,
            tag: dto.tag,
            duration: dto.audibleDuration ?? dto.duration,
            attaches: (dto.attaches?.files ?? []).map { .init(dto: $0, baseUrl: baseUrl, pathTag: pathTag) }
        )
    }
}
