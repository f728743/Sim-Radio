//
//  AudiofilesDownloadOperation.swift
//  Sim Radio
//

import Foundation

struct DownloadFile: Hashable {
    let units: Int64
    let source: URL
    let destination: URL
}

protocol AudiofilesDownloadOperationDelegate: AnyObject {
    func audiofilesDownloadOperation(_ operation: AudiofilesDownloadOperation,
                                     didUpdateTotalProgress progress: Progress)
    func audiofilesDownloadOperation(_ operation: AudiofilesDownloadOperation,
                                     didCompleteWithResult result: AudiofilesDownloadOperation.CompletionResult)
    func audiofilesDownloadOperation(_ operation: AudiofilesDownloadOperation,
                                     didCompleteDownloadOf file: URL)
}

extension AudiofilesDownloadOperationDelegate {
    func audiofilesDownloadOperation(_ operation: AudiofilesDownloadOperation,
                                     didUpdateTotalProgress progress: Progress) {}
    func audiofilesDownloadOperation(_ operation: AudiofilesDownloadOperation,
                                     didCompleteWithResult result: AudiofilesDownloadOperation.CompletionResult) {}
    func audiofilesDownloadOperation(_ operation: AudiofilesDownloadOperation,
                                     didCompleteDownloadOf file: URL) {}

}

struct AudiofilesDownloadOperationConstants {
    static let maximumParallelDownloads = 3
}

class AudiofilesDownloadOperation: AsyncOperation {
    enum CompletionResult {
        case fully
        case partially(successfullyDownloaded: [URL])
    }

    struct FileDownload {
        let downloadFile: DownloadFile
        let progress: Progress
        let destination: URL
    }
    weak var delegate: AudiofilesDownloadOperationDelegate?
    fileprivate var isAtomicCancelled = AtomicBoolean()

    fileprivate let semaphore = DispatchSemaphore(value:
        AudiofilesDownloadOperationConstants.maximumParallelDownloads)
    fileprivate var activeDownloads = SynchronizedDictionary<URL, FileDownload>()

    private(set) var files: [DownloadFile]
    fileprivate let completion: ((CompletionResult) -> Void)?
    private(set) var result: CompletionResult?

    let totalProgress: Progress
    private(set) var successfullyDownloaded: [URL] = []

    lazy var downloadsSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    init(files: [DownloadFile], completion: ((CompletionResult) -> Void)? = nil) {
        isAtomicCancelled.val = false
        self.files = files
        self.completion = completion
        totalProgress = Progress(totalUnitCount: -1)
        super.init()
    }

    override func main() {
        if isCancelled { return }
        if files.isEmpty {
            doneOperation()
        }

        totalProgress.totalUnitCount = files.reduce(0) { $0 + $1.units }
        var fileProgresses: [Progress] = []
        files.forEach {
            let fileProgress = Progress(totalUnitCount: -1)
            totalProgress.addChild(fileProgress, withPendingUnitCount: $0.units)
            fileProgresses.append(fileProgress)
        }

        for (index, file) in files.enumerated() {
            if isAtomicCancelled.val == true { return }
            let task = self.downloadsSession.downloadTask(with: file.source)

            let download = FileDownload(
                downloadFile: file,
                progress: fileProgresses[index],
                destination: file.destination)
            activeDownloads[file.source] = download
            task.resume()
            semaphore.wait()
        }
    }

    override func cancel() {
        isAtomicCancelled.val = true
        doneOperation()
        // to aviod "BUG IN CLIENT OF LIBDISPATCH: Semaphore object deallocated while in use"
        for _ in 0..<AudiofilesDownloadOperationConstants.maximumParallelDownloads {
            semaphore.signal()
        }
    }

    private func doneOperation() {
        if files.count == successfullyDownloaded.count {
            result = .fully
        } else {
            result = .partially(successfullyDownloaded: successfullyDownloaded)
        }
        state = .finished
        completion?(result!)
        downloadsSession.finishTasksAndInvalidate()
        delegate?.audiofilesDownloadOperation(self, didCompleteWithResult: result!)
    }
}

extension AudiofilesDownloadOperation: URLSessionDownloadDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        semaphore.signal()
        guard let sourceURL = task.originalRequest?.url  else {
            return
        }
        guard let download = activeDownloads[sourceURL] else {
            return
        }
        if error == nil {
            successfullyDownloaded.append(download.downloadFile.source)
        }

        activeDownloads[sourceURL] = nil
        if activeDownloads.count == 0 {
            doneOperation()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        do {
            guard let sourceURL = downloadTask.originalRequest?.url,
                let download = activeDownloads[sourceURL] else {
                    throw DownloadError.internalError
            }
            try moveFile(from: location, to: download.destination)
            delegate?.audiofilesDownloadOperation(self, didCompleteDownloadOf: download.downloadFile.source)
        } catch {
            print(error)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        do {
            guard let sourceURL = downloadTask.originalRequest?.url,
                let download = activeDownloads[sourceURL] else {
                    throw DownloadError.internalError
            }
            let progress = download.progress
            progress.totalUnitCount = totalBytesExpectedToWrite
            progress.completedUnitCount = totalBytesWritten
            delegate?.audiofilesDownloadOperation(self, didUpdateTotalProgress: totalProgress)
        } catch {
            print(error) // TODO: something
        }
    }
}
