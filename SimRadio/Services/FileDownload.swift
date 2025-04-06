//
//  FileDownload.swift
//  SimRadio
//
//  Created by Alexey Vorobyov
//

import Foundation

final class FileDownload: NSObject {
    let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation
    private let urlSessionTask: URLSessionDownloadTask
    private let destinationDirectory: URL

    enum Event {
        case progress(downloadedBytes: Int64, totalBytes: Int64)
        case completed
        case canceled(data: Data?, pausing: Bool)
        case failed(error: Error)
    }

    convenience init(url: URL, destinationDirectory: URL, urlSession: URLSession) {
        self.init(
            destinationDirectory: destinationDirectory,
            urlSessionTask: urlSession.downloadTask(with: url)
        )
    }

    convenience init(resumeData data: Data, destinationDirectory: URL, urlSession: URLSession) {
        self.init(
            destinationDirectory: destinationDirectory,
            urlSessionTask: urlSession.downloadTask(withResumeData: data)
        )
    }

    private init(destinationDirectory: URL, urlSessionTask: URLSessionDownloadTask) {
        self.urlSessionTask = urlSessionTask
        self.destinationDirectory = destinationDirectory
        (events, continuation) = AsyncStream.makeStream(of: Event.self)
        super.init()
        continuation.onTermination = { @Sendable [weak self] _ in
            self?.cancel(pausing: false)
        }
    }

    func start() {
        urlSessionTask.delegate = self
        urlSessionTask.resume()
    }

    func cancel(pausing: Bool) {
        if pausing {
            urlSessionTask.cancel { data in
                self.continuation.yield(
                    .canceled(
                        data: pausing ? data : nil,
                        pausing: true
                    )
                )
                self.continuation.finish()
            }
        } else {
            urlSessionTask.cancel()
            continuation.yield(.canceled(data: nil, pausing: false))
            continuation.finish()
        }
    }
}

extension FileDownload: URLSessionDownloadDelegate {
    func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let networkError = downloadTask.response?.networkError {
            continuation.yield(.failed(error: networkError))
        } else {
            do {
                guard let fileName = downloadTask.originalRequest?.url?.lastPathComponent else {
                    throw (URLError(.badURL))
                }

                try destinationDirectory.ensureDirectoryExists()
                let fileURL = destinationDirectory.appending(path: fileName, directoryHint: .notDirectory)
                try fileURL.removeFileIfExists()
                try FileManager.default.moveItem(at: location, to: fileURL)
                continuation.yield(.completed)
            } catch {
                continuation.yield(.failed(error: error))
            }
        }
        continuation.finish()
    }

    func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        continuation.yield(
            .progress(
                downloadedBytes: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite
            )
        )
    }
}
