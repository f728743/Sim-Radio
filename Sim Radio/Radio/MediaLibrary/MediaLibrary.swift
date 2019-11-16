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

class MediaLibrary {
    //    var delegate: DownloaderDelegate?
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "RadioDownloader")
        container.loadPersistentStores(completionHandler: { storeDescription, error in
            print(storeDescription)
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    private var observations = [ObjectIdentifier: Observation]()
    private(set) var series: [Series] = []

    init() {
        fetch()
        series.forEach {
            $0.downloadDelegate = self
            $0.startFilesDownload()
        }
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

    private func fetch() {
        let context = persistentContainer.viewContext
        do {
            let series = try context.fetch(SeriesPersistence.fetchRequest())
            self.series = series.compactMap { seriesManagedObject in
                guard let seriesManagedObject = seriesManagedObject as? SeriesPersistence else { return nil }
                return Series(persistentContainer: persistentContainer,
                              managedObject: seriesManagedObject)
            }
            print("Loaded")
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
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

    private func addSeries(downloadedSeries: DownloadedSeriesModel, downloadedStations: [DownloadedStationModel]) {
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
        guard let newSeries = Series(persistentContainer: persistentContainer, managedObject: series) else { return }
        newSeries.downloadDelegate = self
        newSeries.startFilesDownload()
        saveContext()
        DispatchQueue.main.async {
            self.series.append(newSeries)
            self.notifyOfNewSeries(series: newSeries)
        }

    }
}

// MARK: Download extension
extension MediaLibrary {

    func download(url: URL) {
        var downloadedSeries: DownloadedSeriesModel?
        let downloadedStations = SynchronizedArray<DownloadedStationModel>()
        let completion = BlockOperation {
            guard let series = downloadedSeries else { return }
            let stations = downloadedStations.elements
            self.download(series: series, stations: stations)
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

    private func download(series: DownloadedSeriesModel, stations: [DownloadedStationModel]) {
        let completion = BlockOperation {
            self.addSeries(downloadedSeries: series, downloadedStations: stations)
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
    func series(didCompleteDownloadCommonFilesOf series: Series) {}
    func series(didCompleteDownloadOf series: Series) {
        print("Did complete download of series '\(series.title)'")
    }
    func series(series: Series, didCompleteDownloadOf station: Station) {
        print("Station '\(station.title)' of series '\(series.title)' did complete download")
    }
    func series(series: Series, didUpdateTotalProgress fractionCompleted: Double) {
        print("Series '\(series.title)' did update total download " +
            "progress: \((fractionCompleted * 100).rounded(toPlaces: 2))%")
    }
    func series(series: Series, didUpdateProgress fractionCompleted: Double, of station: Station) {
        print("Station '\(station.title)' of series '\(series.title)' did update " +
            "download progress: \((fractionCompleted * 100).rounded(toPlaces: 2))%")
    }
}

// MARK: Notification extension

protocol MediaLibraryObserver: class {
    func mediaLibrary(_ mediaLibrary: MediaLibrary, didAddNewSeries series: Series)
}

extension MediaLibraryObserver {
    func mediaLibrary(_ mediaLibrary: MediaLibrary, didAddNewSeries series: Series) {}
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

    private func notifyOfNewSeries(series: Series) {
        for (id, observation) in observations {
            guard let observer = observation.observer else {
                observations.removeValue(forKey: id)
                continue
            }
            observer.mediaLibrary(self, didAddNewSeries: series)
        }
    }
}
