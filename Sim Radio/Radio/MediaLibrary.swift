//
//  Library.swift
//  Sim Radio
//

import AVFoundation
import UIKit

//typealias StationID = Int
//typealias SeriesID = Int

struct Series {
    let seriesID: UUID
    let model: Model.Series
    let url: URL
    let logo: UIImage
    let stations: [UUID: Station]
}

struct Station {
    let stationID: UUID
    let model: Model.Station
    let url: URL
    let logo: UIImage
}

class Autoincrement {
    private var last: Int = 0
    func next() -> Int {
        last += 1
        return last
    }
}

class MediaLibrary {
    enum Source {
        case bundle, documents
    }

    let seriesJson = "series.json"
    let stationJson = "station.json"
    private(set) var series: [UUID: Series] = [:]
    private var seriesOfStation: [UUID: UUID] = [:]

    init() {
        load(from: .bundle)
    }

    func series(ofStationWithID id: UUID) -> Series? {
        guard let seriesId = seriesOfStation[id] else { return nil }
        return series[seriesId]
    }

    func series(id: UUID) -> Series? {
        return series[id]
    }

    func station(withId id: UUID) -> Station? {
        guard let series = series(ofStationWithID: id) else { return nil }
        return series.stations[id]
    }

    func load(from source: Source) {
        series.removeAll()
        seriesOfStation.removeAll()
        let urls = seriesUrls(fromDirectory: sourceUrl(source))
        for url in urls {
            if let series = try? loadSeries(from: url) {
                self.series[series.seriesID] = series
            }
        }
    }
    
    func sourceUrl(_ source: Source) -> URL {
        switch source {
        case .bundle:
            return Bundle.main.url(forResource: "Media Library", withExtension: "")!
        case .documents:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
    }

    func seriesUrls(fromDirectory directory: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let directoryContent = try?
            fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        let directories = directoryContent.filter { $0.hasDirectoryPath }
        return directories.filter {
            var url = $0
            url.appendPathComponent(seriesJson)
            return fileManager.fileExists(atPath: url.path)
        }
    }

    func loadSeries(from url: URL) throws -> Series {
        let seriesID = UUID()
        var seriesJsonUrl = url
        seriesJsonUrl.appendPathComponent(seriesJson)
        let model = try Model.loadSeries(from: seriesJsonUrl)
        let info = model.info
        var logoUrl = url
        logoUrl.appendPathComponent(info.logo)
        let logoImage = UIImage(data: try Data(contentsOf: logoUrl)) ?? UIImage(named: "Cover Artwork") ?? UIImage()
        var stations: [UUID: Station] = [:]
        for stationReference in model.stations {
            var stationUrl = url
            stationUrl.appendPathComponent(stationReference.path)
            var stationJsonUrl = stationUrl
            stationJsonUrl.appendPathComponent(stationJson)
            if FileManager.default.fileExists(atPath: stationJsonUrl.path) {
                if let station = try? loadStainion(from: stationUrl) {
                    stations[station.stationID] = station
                    seriesOfStation[station.stationID] = seriesID
                }
            }
        }
        return Series(seriesID: seriesID, model: model, url: url, logo: logoImage, stations: stations)
    }

    func loadStainion(from url: URL) throws -> Station {
        var stationJsonUrl = url
        stationJsonUrl.appendPathComponent(stationJson)
        do {
        let model = try Model.loadStation(from: stationJsonUrl)
        var logoUrl = url
        logoUrl.appendPathComponent(model.info.logo)
        let logoImage = UIImage(data: try Data(contentsOf: logoUrl)) ?? UIImage(named: "Cover Artwork") ?? UIImage()
        return Station(stationID: UUID(), model: model, url: url, logo: logoImage)
            } catch {
                print(error)
            }
        throw LibraryError.playlistError
            
    }
}
