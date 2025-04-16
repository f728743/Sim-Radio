//
//  SimRadioMedia.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 26.03.2025.
//

import Foundation

struct SimRadioMedia {
    let series: [SimGameSeries.ID: SimGameSeries]
    let fileGroups: [SimFileGroup.ID: SimFileGroup]
    let stations: [SimStation.ID: SimStation]
}

struct SimGameSeries {
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

extension SimRadioDTO.GameSeries {
    func simFileGroups(origin: URL) -> [SimFileGroup.ID: SimFileGroup] {
        let shared = gameSeriesShared.fileGroups.map { SimFileGroup(dto: $0, origin: origin) }
        let stations = stations.flatMap { station in
            station.fileGroups.map { SimFileGroup(dto: $0, origin: origin, pathTag: station.tag) }
        }
        return Dictionary(
            uniqueKeysWithValues: (shared + stations).map { ($0.id, $0) }
        )
    }
}

extension SimRadioMedia {
    init(dto: SimRadioDTO.GameSeries, origin: URL) {
        let series = SimGameSeries(dto: dto, origin: origin)
        let stations = dto.stations.map { SimStation(dto: $0, gameSeriesShared: dto.gameSeriesShared, origin: origin) }
        self.init(
            series: Dictionary(uniqueKeysWithValues: [(series.id, series)]),
            fileGroups: dto.simFileGroups(origin: origin),
            stations: Dictionary(uniqueKeysWithValues: stations.map { ($0.id, $0) })
        )
    }

    enum StationLoacalStatus {
        case completed
        case partial(missing: [SimFileGroup.ID: [URL]])
        case missing
    }

    func stationFileGroups(_ id: SimStation.ID) -> [SimFileGroup] {
        return stations[id]?.fileGroups.compactMap { fileGroups[$0] } ?? []
    }

    func calculateStationLoacalStatus(_ id: SimStation.ID) async throws -> StationLoacalStatus {
        var missing: [SimFileGroup.ID: [URL]] = [:]
        var haveAny = false
        for fileGroup in stationFileGroups(id) {
            let missingFiles = fileGroup
                .files
                .map { $0.url }
                .filter { !fileGroup.id.localFileURL(for: $0).isFileExists }
            if fileGroup.files.count > missingFiles.count {
                haveAny = true
            }
            if !missingFiles.isEmpty {
                missing[fileGroup.id] = missingFiles
            }
        }

        if haveAny {
            return missing.isEmpty ? .completed : .partial(missing: missing)
        }
        return .missing
    }
}

extension Collection where Element == URL {}

extension SimGameSeries {
    init(dto: SimRadioDTO.GameSeries, origin: URL) {
        self.init(
            id: .init(origin: origin),
            meta: .init(
                artwork: origin.simRadioBaseURL.appendingPathComponent(dto.info.logo),
                title: dto.info.title,
                subtitle: nil
            ),
            stations: dto.stations.map { .init(origin: origin, stationTag: $0.tag) }
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
    init(dto: SimRadioDTO.Station, gameSeriesShared: SimRadioDTO.GameSeriesShared, origin: URL) {
        let artwork = origin.simRadioBaseURL
            .appendingPathComponent(dto.tag)
            .appendingPathComponent(dto.info.logo)
        let fullFileGroupSet = Set(dto.playlist.fileGroupTags)
        let gameSeriesSharedFileGroupSet = Set(gameSeriesShared.fileGroups.map { $0.tag })
        let stationFileGroups = fullFileGroupSet
            .subtracting(gameSeriesSharedFileGroupSet)
            .map { SimFileGroup.ID(origin: origin, pathTag: dto.tag, groupTag: $0) }
        let usedGameSeriesSharedFileGroupSet = fullFileGroupSet.intersection(gameSeriesSharedFileGroupSet)
        let usedGameSeriesSharedFileGroups = usedGameSeriesSharedFileGroupSet.map {
            SimFileGroup.ID(origin: origin, groupTag: $0)
        }
        self.init(
            id: .init(origin: origin, stationTag: dto.tag),
            meta: .init(
                artwork: artwork,
                title: dto.info.title,
                listSubtitle: dto.info.genre,
                detailsSubtitle: dto.info.detailsSubtitle,
                online: true
            ),
            fileGroups: stationFileGroups + usedGameSeriesSharedFileGroups,
            playlistRules: dto.playlist
        )
    }
}

extension SimGameSeries.ID {
    var directoryURL: URL {
        .documentsDirectory.appending(path: value, directoryHint: .isDirectory)
    }

    var jsonFileURL: URL {
        directoryURL.appending(path: SimGameSeries.defaultFileName)
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

extension SimStation.ID {
    init(origin: URL, stationTag: String) {
        self.init(value: "\(SimGameSeries.ID(origin: origin).value)/\(stationTag)")
    }
}

extension SimFileGroup.ID {
    init(origin: URL, pathTag: String? = nil, groupTag: String) {
        let path = pathTag.map { "/\($0)" } ?? ""
        self.init(value: "\(origin.nonCryptoHash)\(path)/\(groupTag)")
    }

    var directoryURL: URL {
        .documentsDirectory.appending(path: value, directoryHint: .isDirectory)
    }

    func localFileURL(for url: URL) -> URL {
        directoryURL.appending(path: url.lastPathComponent, directoryHint: .notDirectory)
    }
}

extension SimFileGroup {
    init(dto: SimRadioDTO.FileGroup, origin: URL, pathTag: String? = nil) {
        self.init(
            id: .init(origin: origin, pathTag: pathTag, groupTag: dto.tag),
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
