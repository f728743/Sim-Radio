//
//  PlaylistManager.swift
//  Sim Radio
//

import AVFoundation

typealias AudioFileGroups = [Tag: [AudioFile]]

class PlaylistManager {
    let timescale: CMTimeScale = 1000

    private let library: MediaLibrary
    private var playlists: [URL: Playlist] = [:]
    private var commonFileGroups: [URL: AudioFileGroups] = [:]

    init(library: MediaLibrary) {
        self.library = library
    }

    func getPlaylist(of station: Station) throws -> Playlist {
        if let playlist = playlists[station.directoryURL] {
            return playlist
        }
        let playlist = try createPlaylist(of: station)
        playlists[station.directoryURL] = playlist
        return playlist
    }

    func getCommonFileGroups(of series: Series) throws -> AudioFileGroups {
        if let fileGroups = commonFileGroups[series.directoryURL] {
            return fileGroups
        }
        let fileGroups = try createCommonFileGroups(of: series)
        commonFileGroups[series.directoryURL] = fileGroups
        return fileGroups
    }

    func createPlaylist(of station: Station) throws -> Playlist {
        let commonFiles = try getCommonFileGroups(of: station.series)
        return try Playlist(commonFiles: commonFiles, station: station, timescale: timescale)
    }

    func createCommonFileGroups(of series: Series) throws -> AudioFileGroups {
        return Dictionary(uniqueKeysWithValues: try series.model.common.fileGroups.map {
            ($0.tag, try $0.files.map { try AudioFile(baseUrl: series.directoryURL, model: $0, timescale: timescale) })
            })
    }
}
