//
//  Library.swift
//  Sim Radio
//

import UIKit
import CoreData

struct LibraryConstants {
    static let seriesJson = "series.json"
    static let stationJson = "station.json"
    static let wasAlreadyRunningKey = "wasAlreadyRunning"
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

protocol LibraryControl {
    func delete(series: Series)
    typealias Confirmation = (Bool) -> Void
    func downloadSeriesFrom(url: URL,
                            confirmDownloading: @escaping ((String, Int64, @escaping Confirmation) -> Void),
                            errorHandler: ((Error) -> Void)?)
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
        //         Merge the changes from other contexts automatically.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        return container
    }()
    private lazy var audiofilesDownloadManager: AudiofilesDownloadManager = {
        let manager = AudiofilesDownloadManager(persistentContainer: persistentContainer)
        return manager
    }()
    private var observations = [ObjectIdentifier: Observation]()
    private(set) var items: [LibraryItem] = []

    init() {
        if !UserDefaults.standard.bool(forKey: LibraryConstants.wasAlreadyRunningKey) {
            createBuiltInSeries()
            UserDefaults.standard.set(true, forKey: LibraryConstants.wasAlreadyRunningKey)
        }
        let fetchResult = fetchSeries()
        audiofilesDownloadManager.downloadSeriesAudiofiles(series: fetchResult.series, downloadDelegate: self)
        items = fetchResult.series
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                return
            }
            self.deleteAllData(seriesManagedObjects: fetchResult.beingDeletedSeries)
        }
    }

    private func createBuiltInSeries() {
        let seriesPath = UUID().uuidString
        let bundleSeriesURL = Bundle.main.resourceURL!.appendingPathComponent("BuiltIn")
        let documentsSeriesURL = FileManager.documentsURL.appendingPathComponent(seriesPath)
        do {
            try copyContentsOfDirectory(at: bundleSeriesURL, to: documentsSeriesURL)
            try createBuiltInManagedObjects(at: seriesPath)
        } catch {
            fatalError("Failed to create built in series: \(error)")
        }
    }

    private func createBuiltInManagedObjects(at directory: String) throws {
        let context = persistentContainer.viewContext
        let seriesBaseURL = FileManager.documentsURL.appendingPathComponent(directory)
        let seriesURL = seriesBaseURL.appendingPathComponent(LibraryConstants.seriesJson)
        let originBase = Bundle.main.resourceURL!.appendingPathComponent("BuiltIn")
        let origin = originBase.appendingPathComponent(LibraryConstants.seriesJson)
        let seriesManagdObgect = SeriesPersistence(entity: SeriesPersistence.entity(), insertInto: context)
        seriesManagdObgect.origin = origin
        seriesManagdObgect.directory = directory
        seriesManagdObgect.isBeingDeleted = false
        let series = try Model.loadSeries(from: seriesURL)
        series.stations.forEach { seriesPath in
            let stationManagdObgect = StationPersistence(entity: StationPersistence.entity(), insertInto: context)
            let stationOrigin = originBase
                .appendingPathComponent(seriesPath.path)
                .appendingPathComponent(LibraryConstants.stationJson)
            let stationDirectory = directory
                                  .appendingPathComponent(seriesPath.path)
            stationManagdObgect.origin = stationOrigin
            stationManagdObgect.directory = stationDirectory
            stationManagdObgect.series = seriesManagdObgect
        }
        try context.save()
    }
}

// MARK: Persistence extension
extension MediaLibrary {

    private func fetchSeries() -> (series: [Series], beingDeletedSeries: [SeriesPersistence]) {
        let context = persistentContainer.viewContext
        do {
            let seriesSeriesManagedObjects = try context.fetch(SeriesPersistence.fetchRequest())
            let series: [Series] = seriesSeriesManagedObjects.compactMap { seriesManagedObject in
                guard let seriesManagedObject = seriesManagedObject as? SeriesPersistence,
                    !seriesManagedObject.isBeingDeleted  else { return nil }
                return Series(managedObject: seriesManagedObject)
            }
            let beingDeletedSeries: [SeriesPersistence] = seriesSeriesManagedObjects.compactMap { seriesManagedObject in
                guard let seriesManagedObject = seriesManagedObject as? SeriesPersistence,
                    seriesManagedObject.isBeingDeleted  else { return nil }
                return seriesManagedObject
            }
            return (series, beingDeletedSeries)

        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        return ([], [])
    }

    private func addDownloadFiles(context: NSManagedObjectContext,
                                  from groups: [Model.FileGroup],
                                  to managedObject: DownloadTaskPersistence,
                                  baseURL: URL) {
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
                           into context: NSManagedObjectContext) -> NSManagedObjectID {

        let series = SeriesPersistence(entity: SeriesPersistence.entity(), insertInto: context)
        series.origin = downloadedSeries.origin
        series.directory = downloadedSeries.directory
        series.isBeingDeleted = false
        let seriesDownload = DownloadTaskPersistence(
            entity: DownloadTaskPersistence.entity(),
            insertInto: context)
        addDownloadFiles(context: context,
                         from: downloadedSeries.model.common.fileGroups,
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
            addDownloadFiles(context: context,
                             from: downloadedStation.model.fileGroups,
                             to: stationDownload,
                             baseURL: downloadedStation.origin.deletingLastPathComponent())
            stationDownload.station = station
        }
        do {
            try context.save()
        } catch {
            fatalError("Failure to save context: \(error)")
        }
        return series.objectID
    }

    func insertNewSeries(seriesID: NSManagedObjectID, instead placeholder: LibraryPlaceholder) {
        let place = items.firstIndex { $0 === placeholder }
        if let seriesManagedObject = persistentContainer.viewContext.object(with: seriesID) as? SeriesPersistence,
            let series = Series(managedObject: seriesManagedObject) {
            if let place = place {
                items[place] = series
            } else {
                items.append(series)
            }
            audiofilesDownloadManager.downloadSeriesAudiofiles(series: [series], downloadDelegate: self)
        } else if let place = place {
            items.remove(at: place)
        }
    }

    private func setBeingDeleted(series: Series) {
        let context = persistentContainer.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        series.managedObject.isBeingDeleted = true
        do {
            try context.save()
        } catch {
            fatalError("Failure to save context: \(error)")
        }
    }

    func deleteAllData(seriesManagedObjects: [SeriesPersistence]) {
        persistentContainer.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            for series in seriesManagedObjects {
                let seriesURL = FileManager.documentsURL.appendingPathComponent(series.directory)
                try? FileManager.default.removeItem(at: seriesURL)
                guard let backgroundSeries = context.object(with: series.objectID) as? SeriesPersistence  else {
                    print("Internal error: can't obtain series ManagedObject")
                    continue
                }
                context.delete(backgroundSeries)
            }
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    fatalError("Failure to save context: \(error)")
                }
            }
        }
    }
}

// MARK: LibraryControl extension

extension MediaLibrary: LibraryControl {

    func delete(series: Series) {
        setBeingDeleted(series: series)
        notify(willDelete: series)
        items.removeAll { $0 === series }
        notifyLibraryUpdate()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.audiofilesDownloadManager.abortDownloading(series)
            self.deleteAllData(seriesManagedObjects: [series.managedObject])
        }
    }

    func weighRoughly(series: Model.Series, stations: [Model.Station]) -> Int64 {
        let files = stations.flatMap { $0.fileGroups }.flatMap { $0.files } +
            series.common.fileGroups.flatMap { $0.files }
        let attachedFiles = files.compactMap { $0.attaches }.flatMap {$0.files}
        let totallDuration = (files + attachedFiles).reduce(0.0) { $0 + $1.duration }
        let hitOrMissHardcodedBitrate = 16000.0
        return Int64(totallDuration * hitOrMissHardcodedBitrate)
    }

    func removePlaceholder(_ placeholder: LibraryPlaceholder) {
        items.removeAll { $0 === placeholder }
        notifyLibraryUpdate()
    }

    func downloadSeriesFrom(url: URL,
                            confirmDownloading: @escaping ((String, Int64, @escaping Confirmation) -> Void),
                            errorHandler: ((Error) -> Void)? = nil) {
        var downloadedSeries: DownloadedSeriesModel?
        let downloadedStations = SynchronizedArray<DownloadedStationModel>()
        let placeholder = LibraryPlaceholder()
        items.append(placeholder)
        notifyLibraryUpdate()
        let completion = BlockOperation {
            guard let series = downloadedSeries else {
                DispatchQueue.main.async {
                    self.removePlaceholder(placeholder)
                }
                return
            }
            let stations = downloadedStations.elements
            let stationModels = stations.map { $0.model }
            let weigh = self.weighRoughly(series: series.model, stations: stationModels)
            DispatchQueue.main.async {
                confirmDownloading(series.model.info.title, weigh) { userApproved in
                    if userApproved {
                        DispatchQueue.global(qos: .userInitiated).async {
                            self.download(series: series, stations: stations, putInstead: placeholder)
                        }
                    } else {
                        let seriesURL = FileManager.documentsURL.appendingPathComponent(series.directory)
                        try? FileManager.default.removeItem(at: seriesURL)
                        self.removePlaceholder(placeholder)
                    }
                }
            }
        }
        let seriesDirectory = UUID().uuidString
        let seriesLoad = SeriesModelDownloadOperation(from: url, to: seriesDirectory) { [weak self] downloadResult in
            guard let self = self else { return }
            switch downloadResult {
            case .success(let series):
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
            case .failure(let error):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.removePlaceholder(placeholder)
                    errorHandler?(error)
                }
            }
        }
        operationQueue.addOperation(seriesLoad)
    }

    private func download(series: DownloadedSeriesModel,
                          stations: [DownloadedStationModel],
                          putInstead placeholder: LibraryPlaceholder) {
        let completion = BlockOperation {
            self.persistentContainer.performBackgroundTask { context in
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                let seriesID = self.addSeries(downloadedSeries: series,
                                              downloadedStations: stations,
                                              into: context)
                DispatchQueue.main.async {
                    self.insertNewSeries(seriesID: seriesID, instead: placeholder)
                    self.notifyLibraryUpdate()
                }
            }
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

// MARK: SeriesDownloadDelegate extension

extension MediaLibrary: SeriesDownloadDelegate {
    func series(didCompleteDownloadCommonFilesOf series: Series) {
        series.commonFilesDownloaded = true
    }

    func series(didCompleteDownloadOf series: Series) {
        //        print("Did complete download of series '\(series.title)'")
        DispatchQueue.main.async {
            series.downloadProgress = nil
            self.notifyCompleteDownload(of: series)
        }
    }

    func series(series: Series, didCompleteDownloadOf station: Station) {
        //        print("Station '\(station.title)' of series '\(series.title)' did complete download")
        DispatchQueue.main.async {
            station.downloadProgress = nil
            self.notifyCompleteDownload(of: station, of: series)
        }
    }

    func series(series: Series, didUpdateTotalProgress fractionCompleted: Double) {
        //        print("Series '\(series.title)' did update total download " +
        //            "progress: \((fractionCompleted * 100).rounded(toPlaces: 2))%")
        DispatchQueue.main.async {
            if series.downloadProgress == 0 {
                self.notifyStartDownload(of: series)
            }
            series.downloadProgress = fractionCompleted
            self.notifyUpdate(totalProgress: fractionCompleted, of: series)
        }
    }

    func series(series: Series, didUpdateProgress fractionCompleted: Double, of station: Station) {
        //        print("Station '\(station.title)' of series '\(series.title)' did update " +
        //            "download progress: \((fractionCompleted * 100).rounded(toPlaces: 2))%")
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
    func mediaLibrary(mediaLibrary: MediaLibrary, willDelete series: Series)
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
    func mediaLibrary(mediaLibrary: MediaLibrary, willDelete series: Series) {}
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

    private func notify(willDelete series: Series) {
        forEachObserver { $0.mediaLibrary(mediaLibrary: self, willDelete: series) }
    }
}
