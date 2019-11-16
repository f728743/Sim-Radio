//
//  Series.swift
//  RadioDownloader
//

import UIKit
import CoreData

protocol SeriesDownloadDelegate: class {
    func series(didCompleteDownloadCommonFilesOf series: Series)
    func series(didCompleteDownloadOf series: Series)
    func series(series: Series, didCompleteDownloadOf station: Station)
    func series(series: Series, didUpdateTotalProgress fractionCompleted: Double)
    func series(series: Series, didUpdateProgress fractionCompleted: Double, of station: Station)
}

extension SeriesDownloadDelegate {
    func series(didCompleteDownloadCommonFilesOf series: Series) {}
    func series(didCompleteDownloadOf series: Series) {}
    func series(series: Series, didCompleteDownloadOf station: Station) {}
    func series(series: Series, didUpdateTotalProgress fractionCompleted: Double) {}
    func series(series: Series, didUpdateProgress fractionCompleted: Double, of station: Station) {}
}

//func printDownload(downloadPersistence: DownloadTaskPersistence?) {
//    guard let downloadPersistence = downloadPersistence else {
//        print("no DownloadTaskPersistence")
//        return
//    }
//    print("files")
//    downloadPersistence.files.allObjects.forEach { file in
//        guard let file = file as? DownloadFilePersistence else {
//            print("???")
//            return
//        }
//        print(file.source)
//    }
//    print("downloaded")
//    downloadPersistence.downloaded.allObjects.forEach { file in
//        guard let file = file as? DownloadedPersistence else {
//            print("???")
//            return
//        }
//        print(file.source)
//    }
//}

// MARK: Series
class Series {
    var origin: URL {
        return managedObject.origin
    }
    var directory: String {
        return managedObject.directory
    }
    var title: String {
        return model.info.title
    }

    let model: Model.Series
    let logo: UIImage
    private(set) var stations: [Station] = []
    private let managedObject: SeriesPersistence
    let persistentContainer: NSPersistentContainer
    lazy var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    fileprivate var activeDownloads = SynchronizedDictionary<URL, FilesDownloadTask>()
    weak var downloadDelegate: SeriesDownloadDelegate?
    let totalProgress = Progress(totalUnitCount: -1)

    init?(persistentContainer: NSPersistentContainer, managedObject: SeriesPersistence) {
        do {
            self.persistentContainer = persistentContainer
            self.managedObject = managedObject
//            print("common files:")
//            printDownload(downloadPersistence: managedObject.downloadTask)

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
//                print("station \(stationsManagedObject.origin)")
//                printDownload(downloadPersistence: stationsManagedObject.downloadTask)

                return Station(series: self, managedObject: stationsManagedObject)
            }
        } catch {
            print("Series.init():", error)
            return nil
        }
    }

    deinit {
        let downlads = activeDownloads.values
        downlads.forEach { $0.cancel() }
    }

    static private func loadLogo(contentsOfFile url: URL) -> UIImage {
        return UIImage(contentsOfFile: url.path) ?? UIImage(named: "Cover Artwork") ?? UIImage()
    }
}

// MARK: Series download files extension

extension Series {
    private func addFilesDownloadTask(managedObject: DownloadTaskPersistence,
                                      source: FilesDownloadTask.Source,
                                      destinationDirectory: URL) {

        let allFiles = managedObject.files.allObjects.compactMap { (file) -> DownloadFile? in
            guard let file = file as? DownloadFilePersistence else { return nil }
            return DownloadFile(units: file.units,
                                source: file.source,
                                destination: destinationDirectory.appendingPathComponent(file.destination))
        }
        let downloadedFiles = managedObject.downloaded.allObjects.compactMap { (file) -> URL? in
            guard let file = file as? DownloadedPersistence else { return nil }
            return file.source
        }
        let task = FilesDownloadTask(queue: queue,
                                     files: allFiles,
                                     downloadedFiles: downloadedFiles,
                                     source: source)
        let unitCount = allFiles.reduce(0) { $0 + $1.units }
        totalProgress.totalUnitCount += unitCount
        totalProgress.addChild(task.progress, withPendingUnitCount: unitCount)
        activeDownloads[task.origin] = task
        task.delegate = self
        task.start()
    }

    func startFilesDownload() {
        let documentsURL = FileManager.documents
        let seriesDirectoryURL = documentsURL.appendingPathComponent(directory)
        totalProgress.totalUnitCount = 0
        if let downloadObject = managedObject.downloadTask {
            addFilesDownloadTask(managedObject: downloadObject,
                                 source: .commonSeriesFiles(seriesOrigin: origin),
                                 destinationDirectory: seriesDirectoryURL)
        }
        for station in stations {
            guard let stationDownloadObject = station.managedObject.downloadTask else { continue }
            let stationDirectoryURL = documentsURL.appendingPathComponent(station.directory)
            addFilesDownloadTask(
                managedObject: stationDownloadObject,
                source: .stationFiles(stationOrigin: station.origin, station: station),
                destinationDirectory: stationDirectoryURL)
        }
    }
}

// MARK: Series FilesDownloadTaskDelegate extension
extension Series: FilesDownloadTaskDelegate {
    func filesDownloadTask(_ filesDownloadTask: FilesDownloadTask, didUpdateProgress progress: Progress) {
        if case let .stationFiles(_, station) = filesDownloadTask.sourse {
            downloadDelegate?.series(series: self,
                                     didUpdateProgress: progress.fractionCompleted,
                                     of: station)
        }
        downloadDelegate?.series(
            series: self,
            didUpdateTotalProgress: totalProgress.fractionCompleted)
    }

    func filesDownloadTask(didComplete filesDownloadTask: FilesDownloadTask) {
        let context = persistentContainer.viewContext
        if case let .stationFiles(stationOrigin, station) = filesDownloadTask.sourse {
            activeDownloads[stationOrigin] = nil
            downloadDelegate?.series(
                series: self,
                didCompleteDownloadOf: station)

            guard let downloadTask = station.managedObject.downloadTask else {
                print("Internal error: can't obtain downloadTask ManagedObject")
                return
            }
            context.delete(downloadTask)
        } else if case let .commonSeriesFiles(seriesOrigin) = filesDownloadTask.sourse {
            activeDownloads[seriesOrigin] = nil
            downloadDelegate?.series(didCompleteDownloadCommonFilesOf: self)
            guard let downloadTask = managedObject.downloadTask else {
                print("Internal error: can't obtain downloadTask ManagedObject")
                return
            }
            context.delete(downloadTask)
        }
        if activeDownloads.count == 0 {
            downloadDelegate?.series(didCompleteDownloadOf: self)
        }
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let error = error as NSError
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }

    func filesDownloadTask(_ filesDownloadTask: FilesDownloadTask, didCompleteDownloadOf file: URL) {
        //        print(file)
        let context = persistentContainer.viewContext
        if case let .stationFiles(_, station) = filesDownloadTask.sourse {
            guard let downloadTask = station.managedObject.downloadTask else {
                print("Internal error: can't obtain downloadTask ManagedObject")
                return
            }
            let downloadFile = DownloadedPersistence(
                entity: DownloadedPersistence.entity(),
                insertInto: context)
            downloadFile.source = file
            downloadFile.task = downloadTask

        } else if case .commonSeriesFiles(_) = filesDownloadTask.sourse {
            guard let downloadTask = managedObject.downloadTask else {
                print("Internal error: can't obtain downloadTask ManagedObject")
                return
            }
            let downloadFile = DownloadedPersistence(
                entity: DownloadedPersistence.entity(),
                insertInto: context)
            downloadFile.source = file
            downloadFile.task = downloadTask
        }

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let error = error as NSError
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
}

// MARK: Station
class Station {
    unowned let series: Series
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
    var host: String? {
        return model.info.dj
    }
    var genre: String {
        return model.info.genre
    }
    let logo: UIImage
    fileprivate let managedObject: StationPersistence

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
        } catch {
            print("Station.init():", error)
            return nil
        }
    }

    static private func loadLogo(contentsOfFile url: URL) -> UIImage {
        return UIImage(contentsOfFile: url.path) ?? UIImage(named: "Cover Artwork") ?? UIImage()
    }
}
