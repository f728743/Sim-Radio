//
//  Series.swift
//  Sim Radio
//

import UIKit
import CoreData

// MARK: Series
class Series {
    var commonFilesDownloaded: Bool?
    var downloadProgress: Double?
    var origin: URL {
        return managedObject.origin
    }
    var directory: String {
        return managedObject.directory
    }
    var directoryURL: URL {
        return FileManager.documents.appendingPathComponent(directory)
    }
    var title: String {
        return model.info.title
    }
    let model: Model.Series
    let logo: UIImage
    var readyToPlayStations: [Station] {
        return stations.filter { $0.readyToPlay }
    }
    private(set) var stations: [Station] = []
    private(set) var managedObject: SeriesPersistence

    init?(managedObject: SeriesPersistence) {
        do {
            self.managedObject = managedObject
            if managedObject.downloadTask != nil {
                downloadProgress = 0
                commonFilesDownloaded = false
            }
            let modelURL = FileManager.documents
                .appendingPathComponent(managedObject.directory)
                .appendingPathComponent(LibraryConstants.seriesJson)
            model = try Model.loadSeries(from: modelURL)
            let logoURL = FileManager.documents
                .appendingPathComponent(managedObject.directory)
                .appendingPathComponent(model.info.logo)
            logo = Series.loadLogo(contentsOfFile: logoURL)

            stations = managedObject.stations.allObjects.compactMap { stationsManagedObject in
                guard let stationsManagedObject = stationsManagedObject as? StationPersistence else { return nil }
                return Station(series: self, managedObject: stationsManagedObject)
            }
        } catch {
            print("Series.init():", error)
            return nil
        }
    }

    static private func loadLogo(contentsOfFile url: URL) -> UIImage {
        return UIImage(contentsOfFile: url.path) ?? UIImage(named: "Cover Artwork") ?? UIImage()
    }
}

// MARK: adopt LibraryItem protocol for Series
extension Series: LibraryItem {
    struct Appearance: LibraryItemAppearance {
        let series: Series
        var downloadProgress: Double? {
            return series.downloadProgress
        }
        var title: String {
            return series.title
        }
        var logo: UIImage {
            return series.logo
        }
    }
    var appearance: LibraryItemAppearance? {
        return Appearance(series: self)
    }
}

// MARK: Station
class Station {
    unowned let series: Series
    var downloadProgress: Double?
    let model: Model.Station
    var origin: URL {
        return managedObject.origin
    }
    var directory: String {
        return managedObject.directory
    }
    var directoryURL: URL {
        return FileManager.documents.appendingPathComponent(directory)
    }
    var title: String {
        return model.info.title
    }
    var dj: String? {
        return model.info.dj
    }
    var genre: String {
        return model.info.genre
    }
    let logo: UIImage
    var isDependsOnCommonFiles: Bool {
        let playlistFileGroups = model.playlist.fragments.compactMap {
            $0.src.type == "group" ? $0.src.groupTag : nil
        }
        let commonFileGroups = series.model.common.fileGroups.map { $0.tag }
        // convert array to Set if fileGroups.count > ~100 (actually we have 2 elements only)
        return !playlistFileGroups.filter(commonFileGroups.contains).isEmpty
    }
    var readyToPlay: Bool {
        let isStationFilesDownloaded = downloadProgress == nil || downloadProgress == 1.0
        if !isStationFilesDownloaded { return false }
        if isDependsOnCommonFiles {
            return series.commonFilesDownloaded == nil || series.commonFilesDownloaded == true
        }
        return true
    }
    private(set) var managedObject: StationPersistence

    init?(series: Series, managedObject: StationPersistence) {
        do {
            self.series = series
            self.managedObject = managedObject
            let modelURL = FileManager.documents
                .appendingPathComponent(managedObject.directory)
                .appendingPathComponent(LibraryConstants.stationJson)
            model = try Model.loadStation(from: modelURL)
            let logoURL = FileManager.documents
                .appendingPathComponent(managedObject.directory)
                .appendingPathComponent(model.info.logo)
            logo = Station.loadLogo(contentsOfFile: logoURL)
            if managedObject.downloadTask != nil {
                downloadProgress = 0
            }
        } catch {
            print("Station.init():", error)
            return nil
        }
    }

    static private func loadLogo(contentsOfFile url: URL) -> UIImage {
        return UIImage(contentsOfFile: url.path) ?? UIImage(named: "Cover Artwork") ?? UIImage()
    }
}
