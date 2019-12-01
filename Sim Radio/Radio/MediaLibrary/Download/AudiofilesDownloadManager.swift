//
//  AudiofilesDownloadManager.swift
//  RadioDownloader
//

import CoreData

class AudiofilesDownloadManager {
    let seriesDownloads = SynchronizedArray<SeriesDownload>()

    lazy var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    let persistentContainer: NSPersistentContainer

    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }

    func downloadSeriesAudiofiles(series: [Series], downloadDelegate: SeriesDownloadDelegate) {
        series.forEach {
            let seriesDownload = SeriesDownload(persistentContainer: persistentContainer,
                                                downloadDelegate: downloadDelegate,
                                                series: $0)
            if seriesDownload.startDownload(queue: queue) {
                seriesDownloads.append(newElement: seriesDownload)
            }
        }
    }
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

// MARK: SeriesDownloadDelegate

protocol SeriesDownloadDelegate: AnyObject {
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

// MARK: SeriesDownload

class SeriesDownload {
    private weak var series: Series?
    private let totalProgress = Progress(totalUnitCount: -1)
    private let activeDownloads = SynchronizedDictionary<URL, FilesDownloadTask>()
    private weak var downloadDelegate: SeriesDownloadDelegate?
    private let persistentContainer: NSPersistentContainer

    init(persistentContainer: NSPersistentContainer, downloadDelegate: SeriesDownloadDelegate, series: Series) {
        self.series = series
        self.persistentContainer = persistentContainer
        self.downloadDelegate = downloadDelegate
    }

    func startDownload(queue: OperationQueue) -> Bool {
        guard let series = series else { return false }
        var result = false
        let documentsURL = FileManager.documents
        let seriesDirectoryURL = documentsURL.appendingPathComponent(series.directory)
        totalProgress.totalUnitCount = 0
        if let downloadObject = series.managedObject.downloadTask {
            result = true
            addFilesDownloadTask(queue: queue,
                                 managedObject: downloadObject,
                                 source: .commonSeriesFiles(seriesOrigin: series.origin),
                                 destinationDirectory: seriesDirectoryURL)
        }
        for station in series.stations {
            guard let stationDownloadObject = station.managedObject.downloadTask else { continue }
            result = true
            let stationDirectoryURL = documentsURL.appendingPathComponent(station.directory)
            addFilesDownloadTask(
                queue: queue,
                managedObject: stationDownloadObject,
                source: .stationFiles(stationOrigin: station.origin, station: station),
                destinationDirectory: stationDirectoryURL)
        }
        return result
    }

    private func addFilesDownloadTask(queue: OperationQueue,
                                      managedObject: DownloadTaskPersistence,
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
}

// MARK: SeriesDownload FilesDownloadTaskDelegate extension

extension SeriesDownload: FilesDownloadTaskDelegate {
    func filesDownloadTask(_ filesDownloadTask: FilesDownloadTask, didUpdateProgress progress: Progress) {
        guard let series = series else { return }
        if case let .stationFiles(_, station) = filesDownloadTask.sourse {
            downloadDelegate?.series(series: series,
                                     didUpdateProgress: progress.fractionCompleted,
                                     of: station)
        }
        downloadDelegate?.series(
            series: series,
            didUpdateTotalProgress: totalProgress.fractionCompleted)
    }

    func filesDownloadTask(didComplete filesDownloadTask: FilesDownloadTask) {
        guard let series = series else { return }
        persistentContainer.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            if case let .stationFiles(stationOrigin, station) = filesDownloadTask.sourse {
                self.activeDownloads[stationOrigin] = nil
                self.downloadDelegate?.series(
                    series: series,
                    didCompleteDownloadOf: station)

                guard let downloadTaskID = station.managedObject.downloadTask?.objectID,
                    let downloadTask = context.object(with: downloadTaskID) as? DownloadTaskPersistence  else {
                    print("Internal error: can't obtain downloadTask ManagedObject")
                    return
                }
                context.delete(downloadTask)
            } else if case let .commonSeriesFiles(seriesOrigin) = filesDownloadTask.sourse {
                self.activeDownloads[seriesOrigin] = nil
                self.downloadDelegate?.series(didCompleteDownloadCommonFilesOf: series)
                guard let downloadTaskID = series.managedObject.downloadTask?.objectID,
                    let downloadTask = context.object(with: downloadTaskID) as? DownloadTaskPersistence  else {
                    print("Internal error: can't obtain downloadTask ManagedObject")
                    return
                }
                context.delete(downloadTask)
            }
            if self.activeDownloads.count == 0 {
                self.downloadDelegate?.series(didCompleteDownloadOf: series)
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

    func filesDownloadTask(_ filesDownloadTask: FilesDownloadTask, didCompleteDownloadOf file: URL) {
        guard let series = series else { return }
        persistentContainer.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            if case let .stationFiles(_, station) = filesDownloadTask.sourse {
                guard let downloadTaskID = station.managedObject.downloadTask?.objectID,
                    let downloadTask = context.object(with: downloadTaskID) as? DownloadTaskPersistence  else {
                    print("Internal error: can't obtain downloadTask ManagedObject")
                    return
                }
                let downloadFile = DownloadedPersistence(
                    entity: DownloadedPersistence.entity(),
                    insertInto: context)
                downloadFile.source = file
                downloadFile.task = downloadTask

            } else if case .commonSeriesFiles(_) = filesDownloadTask.sourse {
                guard let downloadTaskID = series.managedObject.downloadTask?.objectID,
                    let downloadTask = context.object(with: downloadTaskID) as? DownloadTaskPersistence  else {
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
}
