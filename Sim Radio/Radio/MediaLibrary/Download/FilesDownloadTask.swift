//
//  FilesDownloadTask.swift
//  Sim Radio
//

import Foundation

protocol FilesDownloadTaskDelegate: AnyObject {
    func filesDownloadTask(_ filesDownloadTask: FilesDownloadTask, didUpdateProgress progress: Progress)
    func filesDownloadTask(_ filesDownloadTask: FilesDownloadTask, didCompleteDownloadOf file: URL)
    func filesDownloadTask(didComplete filesDownloadTask: FilesDownloadTask)
}

extension FilesDownloadTaskDelegate {
    func filesDownloadTask(_ filesDownloadTask: FilesDownloadTask, didUpdateProgress progress: Progress) {}
    func filesDownloadTask(_ filesDownloadTask: FilesDownloadTask, didCompleteDownloadOf file: URL) {}
    func filesDownloadTask(didComplete filesDownloadTask: FilesDownloadTask) {}
}

/// `FilesDownloadTask` manages to start AudiofilesDownloadOperation for list of audiofiles,
/// keep track of successfully downladed files and repeat AudiofilesDownloadOperation for failed to
/// download files until everething become nice
class FilesDownloadTask {
    enum Source {
        case commonSeriesFiles(seriesOrigin: URL)
        case stationFiles(stationOrigin: URL, station: Station)
    }

    let progress: Progress
    weak var delegate: FilesDownloadTaskDelegate?
    let sourse: Source

    enum State {
        case ready, executing, finished
    }
    private var state: State = .ready
    private let files: [DownloadFile]
    private var downloadedFiles: [URL]
    private weak var queue: OperationQueue?

    var origin: URL {
        switch sourse {
        case .commonSeriesFiles(let seriesOrigin):
            return seriesOrigin
        case .stationFiles(let stationOrigin, _):
            return stationOrigin
        }
    }

    init(queue: OperationQueue, files: [DownloadFile], downloadedFiles: [URL], source: Source) {
        self.sourse = source
        self.queue = queue
        self.files = files
        self.downloadedFiles = downloadedFiles
        progress = Progress(totalUnitCount: files.reduce(0) { $0 + $1.units })
    }

    func start() {
        guard state != .executing else {
            return
        }
        startOperation()
    }

    func cancel() {
        state = .finished
    }

    private func startOperation() {
        guard state != .finished else {
            return
        }

        progress.reset()
        let downloadedSet = Set(downloadedFiles)
        let filesToDownload = files.filter { !downloadedSet.contains($0.source) }
        progress.completedUnitCount = files.reduce(0) { $0 + $1.units } - filesToDownload.reduce(0) { $0 + $1.units }
        let downloadOperation = AudiofilesDownloadOperation(files: filesToDownload)
        let unitsToDownload = progress.totalUnitCount - progress.completedUnitCount
        progress.addChild(downloadOperation.totalProgress, withPendingUnitCount: unitsToDownload)
        downloadOperation.delegate = self
        queue?.addOperation(downloadOperation)
    }
}

extension FilesDownloadTask: AudiofilesDownloadOperationDelegate {
    func audiofilesDownloadOperation(_ operation: AudiofilesDownloadOperation,
                                     didUpdateTotalProgress progress: Progress) {
        delegate?.filesDownloadTask(self, didUpdateProgress: self.progress)
    }

    func audiofilesDownloadOperation(_ operation: AudiofilesDownloadOperation,
                                     didCompleteDownloadOf file: URL) {
        delegate?.filesDownloadTask(self, didCompleteDownloadOf: file)
    }

    func audiofilesDownloadOperation(
        _ operation: AudiofilesDownloadOperation,
        didCompleteWithResult result: AudiofilesDownloadOperation.CompletionResult) {
        if case .fully = result {
            delegate?.filesDownloadTask(didComplete: self)
            state = .finished
        } else if case let .partially(successfullyDownloaded) = result {
            downloadedFiles += successfullyDownloaded
            startOperation()
        }
    }
}
