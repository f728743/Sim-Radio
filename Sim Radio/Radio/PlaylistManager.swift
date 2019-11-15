//
//  PlaylistManager.swift
//  Sim Radio
//

import AVFoundation

typealias Tag = String
typealias AudioFileGroups = [Tag: [AudioFile]]

class PlaylistManager {
    let timescale: CMTimeScale = 1000

    private let library: MediaLibrary
    private var playlists: [UUID: Playlist] = [:]
    private var commonFileGroups: [UUID: AudioFileGroups] = [:]

    init(library: MediaLibrary) {
        self.library = library
    }

    func getPlaylist(ofStation id: UUID) throws -> Playlist {
        if let playlist = playlists[id] {
            return playlist
        }
        let playlist = try createPlaylist(ofStation: id)
        playlists[id] = playlist
        return playlist
    }

    func getCommonFileGroups(ofSeries id: UUID) throws -> AudioFileGroups {
        if let fileGroups = commonFileGroups[id] {
            return fileGroups
        }
        let fileGroups = try createCommonFileGroups(ofSeries: id)
        commonFileGroups[id] = fileGroups
        return fileGroups
    }

    func createPlaylist(ofStation id: UUID) throws -> Playlist {
        guard let station = library.station(withId: id) else {
            throw LibraryError.invalidStationID(id: id)
        }
        guard let series = library.series(ofStationWithID: id) else {
            throw LibraryError.invalidSeriesID(id: id)
        }
        let commonFiles = try getCommonFileGroups(ofSeries: series.seriesID)
        return try Playlist(commonFiles: commonFiles, station: station, timescale: timescale)
    }

    func createCommonFileGroups(ofSeries id: UUID) throws -> AudioFileGroups {
        guard let series = library.series(id: id) else {
            throw LibraryError.invalidSeriesID(id: id)
        }
        return Dictionary(uniqueKeysWithValues: try series.model.common.fileGroups.map {
            ($0.tag, try $0.files.map { try AudioFile(baseUrl: series.url, model: $0, timescale: timescale) })
        })
    }
}
