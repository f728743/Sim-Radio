//
//  Library.swift
//  Sim Radio
//

import UIKit
import CoreData

struct LibraryConstants {
    static let seriesJson = "series.json"
    static let stationJson = "station.json"
}

public protocol LibraryItemAppearance {
    var downloadProgress: Double? { get }
    var title: String { get }
    var logo: UIImage { get }
}

protocol LibraryItem: AnyObject {
    var appearance: LibraryItemAppearance? { get }
}

class LibraryPlaceholder: LibraryItem {
    var appearance: LibraryItemAppearance? { return nil }
}

class MediaLibrary {
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SimRadio")
        container.loadPersistentStores(completionHandler: { storeDescription, error in
            print(storeDescription)
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    private var observations = [ObjectIdentifier: Observation]()
    private(set) var items: [LibraryItem] = []

    init() {
        let series = fetchSeries()
        series.forEach {
            $0.downloadDelegate = self
            $0.startFilesDownload()
        }
        items = series
    }
}

// MARK: Persistence extension
extension MediaLibrary {
    private func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let error = error as NSError
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }

    private func fetchSeries() -> [Series] {
        let context = persistentContainer.viewContext
        do {
            let series = try context.fetch(SeriesPersistence.fetchRequest())
            return series.compactMap { seriesManagedObject in
                guard let seriesManagedObject = seriesManagedObject as? SeriesPersistence else { return nil }
                return Series(persistentContainer: persistentContainer,
                              managedObject: seriesManagedObject)
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return []
    }

    private func addDownloadFiles(from groups: [Model.FileGroup],
                                  to managedObject: DownloadTaskPersistence,
                                  baseURL: URL) {
        let context = persistentContainer.viewContext
        let files = groups.flatMap { $0.files }
        let attachedFiles = files.compactMap { $0.attaches }.flatMap {$0.files}
        let allFiles = files + attachedFiles
        allFiles.forEach { file in
            let downloadFile = DownloadFilePersistence(
                entity: DownloadFilePersistence.entity(),
                insertInto: context)
            downloadFile.destination = file.path
            downloadFile.source = baseURL.appendingPathComponent(file.path)
            downloadFile.units = Int64(file.duration)
            downloadFile.task = managedObject
        }
    }

    private func addSeries(downloadedSeries: DownloadedSeriesModel,
                           downloadedStations: [DownloadedStationModel],
                           to placeholder: LibraryPlaceholder) {


        // TODO let taskContext = persistentContainer.newBackgroundContext()
        let context = persistentContainer.viewContext
        let series = SeriesPersistence(entity: SeriesPersistence.entity(), insertInto: context)
        series.origin = downloadedSeries.origin
        series.directory = downloadedSeries.directory
        let seriesDownload = DownloadTaskPersistence(
            entity: DownloadTaskPersistence.entity(),
            insertInto: context)
        addDownloadFiles(from: downloadedSeries.model.common.fileGroups,
                         to: seriesDownload,
                         baseURL: downloadedSeries.origin.deletingLastPathComponent())
        seriesDownload.series = series

        downloadedStations.forEach { downloadedStation in
            let station = StationPersistence(entity: StationPersistence.entity(), insertInto: context)
            station.origin = downloadedStation.origin
            station.directory = downloadedStation.directory
            station.series = series
            let stationDownload = DownloadTaskPersistence(
                entity: DownloadTaskPersistence.entity(),
                insertInto: context)
            addDownloadFiles(from: downloadedStation.model.fileGroups,
                             to: stationDownload,
                             baseURL: downloadedStation.origin.deletingLastPathComponent())
            stationDownload.station = station
        }
        guard let newSeries = Series(persistentContainer: persistentContainer, managedObject: series) else {
            DispatchQueue.main.async {
                self.items.removeAll { $0 === placeholder }
                self.notifyLibraryUpdate()
            }
            return
        }
        newSeries.downloadDelegate = self
        newSeries.startFilesDownload()
        saveContext()
        DispatchQueue.main.async {
            if let index = self.items.firstIndex(where: { $0 === placeholder }) {
                self.items[index] = newSeries
            } else {
                self.items.append(newSeries)
            }
            self.notifyLibraryUpdate()
        }
    }
}

// MARK: Download extension
extension MediaLibrary {

    func download(url: URL) {
        var downloadedSeries: DownloadedSeriesModel?
        let downloadedStations = SynchronizedArray<DownloadedStationModel>()
        let placeholder = LibraryPlaceholder()
        items.append(placeholder)
        notifyLibraryUpdate()
        let completion = BlockOperation {
            guard let series = downloadedSeries else {
                DispatchQueue.main.async {
                    self.items.removeAll { $0 === placeholder }
                    self.notifyLibraryUpdate()
                }
                return
            }
            let stations = downloadedStations.elements
            self.download(series: series, stations: stations, to: placeholder)
        }
        let seriesDirectory = UUID().uuidString
        let seriesLoad = SeriesModelDownloadOperation(from: url, to: seriesDirectory) { series in
            downloadedSeries = series
            var stationLoadOperatios: [Operation] = []
            for station in series.model.stations {
                let stationURL = series.origin
                    .deletingLastPathComponent()
                    .appendingPathComponent(station.path)
                    .appendingPathComponent(LibraryConstants.stationJson)
                let stationDirectory = seriesDirectory
                    .appendingPathComponent(station.path)
                let stationLoad = StationModelDownloadOperation(
                    from: stationURL,
                    to: stationDirectory) { downloadStation in
                        downloadedStations.append(newElement: downloadStation)
                }
                stationLoadOperatios.append(stationLoad)
                completion.addDependency(stationLoad)
            }
            self.operationQueue.addOperations(stationLoadOperatios, waitUntilFinished: false)
            self.operationQueue.addOperation(completion)
        }
        operationQueue.addOperation(seriesLoad)
    }

    private func download(series: DownloadedSeriesModel,
                          stations: [DownloadedStationModel],
                          to placeholder: LibraryPlaceholder) {
        let completion = BlockOperation {
            self.addSeries(downloadedSeries: series,
                           downloadedStations: stations,
                           to: placeholder)
        }
        var logoLoadOperatios = stations.map {
            FileDownloadOperation(
                from: $0.origin
                    .deletingLastPathComponent()
                    .appendingPathComponent($0.model.info.logo),
                to: $0.directory)
        }
        logoLoadOperatios.append(
            FileDownloadOperation(
                from: series.origin
                    .deletingLastPathComponent()
                    .appendingPathComponent(series.model.info.logo),
                to: series.directory))
        logoLoadOperatios.forEach { completion.addDependency($0) }
        operationQueue.addOperations(logoLoadOperatios, waitUntilFinished: false)
        operationQueue.addOperation(completion)
    }
}

extension MediaLibrary: SeriesDownloadDelegate {
    func series(didCompleteDownloadCommonFilesOf series: Series) {
        series.commonFilesDownloaded = true
    }

    func series(didCompleteDownloadOf series: Series) {
        DispatchQueue.main.async {
            series.downloadProgress = nil
            self.notifyCompleteDownload(of: series)
        }
    }

    func series(series: Series, didCompleteDownloadOf station: Station) {
        DispatchQueue.main.async {
            station.downloadProgress = nil
            self.notifyCompleteDownload(of: station, of: series)
        }
    }

    func series(series: Series, didUpdateTotalProgress fractionCompleted: Double) {
        DispatchQueue.main.async {
            if series.downloadProgress == 0 {
                self.notifyStartDownload(of: series)
            }
            series.downloadProgress = fractionCompleted
            self.notifyUpdate(totalProgress: fractionCompleted, of: series)
        }
    }

    func series(series: Series, didUpdateProgress fractionCompleted: Double, of station: Station) {
        DispatchQueue.main.async {
            if station.downloadProgress == 0 {
                self.notifyStartDownload(of: station, of: series)
            }
            station.downloadProgress = fractionCompleted
            self.notifyUpdate(progress: fractionCompleted, of: station, of: series)
        }
    }
}

// MARK: Notification extension

protocol MediaLibraryObserver: AnyObject {
    func mediaLibrary(didUpdateItemsOfMediaLibrary: MediaLibrary)
    func mediaLibrary(mediaLibrary: MediaLibrary, didStartDownloadOf series: Series)
    func mediaLibrary(mediaLibrary: MediaLibrary,
                      didUpdateTotalDownloadProgress fractionCompleted: Double,
                      of series: Series)
    func mediaLibrary(mediaLibrary: MediaLibrary, didCompleteDownloadOf series: Series)

    func mediaLibrary(mediaLibrary: MediaLibrary, didStartDownloadOf station: Station, of series: Series)
    func mediaLibrary(mediaLibrary: MediaLibrary,
                      didUpdateDownloadProgress fractionCompleted: Double,
                      of station: Station,
                      of series: Series)
    func mediaLibrary(mediaLibrary: MediaLibrary, didCompleteDownloadOf station: Station, of series: Series)
}

extension MediaLibraryObserver {
    func mediaLibrary(didUpdateItemsOfMediaLibrary: MediaLibrary) {}
    func mediaLibrary(mediaLibrary: MediaLibrary, didStartDownloadOf series: Series) {}
    func mediaLibrary(mediaLibrary: MediaLibrary,
                      didUpdateTotalDownloadProgress fractionCompleted: Double,
                      of series: Series) {}
    func mediaLibrary(mediaLibrary: MediaLibrary, didCompleteDownloadOf series: Series) {}

    func mediaLibrary(mediaLibrary: MediaLibrary, didStartDownloadOf station: Station, of series: Series) {}
    func mediaLibrary(mediaLibrary: MediaLibrary,
                      didUpdateDownloadProgress fractionCompleted: Double,
                      of station: Station,
                      of series: Series) {}
    func mediaLibrary(mediaLibrary: MediaLibrary, didCompleteDownloadOf station: Station, of series: Series) {}
}

private extension MediaLibrary {
    struct Observation {
        weak var observer: MediaLibraryObserver?
    }
}

extension MediaLibrary {
    func addObserver(_ observer: MediaLibraryObserver) {
        let id = ObjectIdentifier(observer)
        observations[id] = Observation(observer: observer)
    }

    func removeObserver(_ observer: MediaLibraryObserver) {
        let id = ObjectIdentifier(observer)
        observations.removeValue(forKey: id)
    }

    private func forEachObserver(_ body: (MediaLibraryObserver) -> Void) {
        for (id, observation) in observations {
            guard let observer = observation.observer else {
                observations.removeValue(forKey: id)
                continue
            }
            body(observer)
        }
    }

    private func notifyStartDownload(of series: Series) {
        forEachObserver { $0.mediaLibrary(mediaLibrary: self, didStartDownloadOf: series) }
    }

    private func notifyUpdate(totalProgress fractionCompleted: Double, of series: Series) {
        forEachObserver { $0.mediaLibrary(mediaLibrary: self,
                                          didUpdateTotalDownloadProgress: fractionCompleted,
                                          of: series) }
    }

    private func notifyCompleteDownload(of series: Series) {
        forEachObserver { $0.mediaLibrary(mediaLibrary: self, didCompleteDownloadOf: series) }
    }

    private func notifyStartDownload(of station: Station, of series: Series) {
        forEachObserver { $0.mediaLibrary(mediaLibrary: self, didStartDownloadOf: station, of: series) }
    }

    private func notifyUpdate(progress fractionCompleted: Double, of station: Station, of series: Series) {
        forEachObserver { $0.mediaLibrary(mediaLibrary: self,
                                          didUpdateDownloadProgress: fractionCompleted,
                                          of: station,
                                          of: series) }
    }

    private func notifyCompleteDownload(of station: Station, of series: Series) {
        forEachObserver { $0.mediaLibrary(mediaLibrary: self, didCompleteDownloadOf: station, of: series) }
    }

    private func notifyLibraryUpdate() {
        forEachObserver { $0.mediaLibrary(didUpdateItemsOfMediaLibrary: self) }
    }
}
