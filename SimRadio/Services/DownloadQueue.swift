//
//  DownloadQueue.swift
//  SimRadio
//
//  Created by Alexey Vorobyov
//

import Foundation

actor DownloadQueue {
    struct DownloadRequest: Equatable, Hashable {
        let sourceURL: URL
        let destinationDirectoryPath: String
    }

    enum DownloadState {
        case queued
        case progress(downloadedBytes: Int64, totalBytes: Int64)
        case completed
        case canceled
        case paused
        case failed(error: Error)
    }

    struct Event {
        let state: DownloadState
        let downloadRequest: DownloadRequest
    }

    let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation
    private let destinationDirectory: URL
    private let urlSession: URLSession
    private let maxConcurrentDownloads: Int
    private var downloadQueue: [QueueElement] = []
    private var activeDownloads: [DownloadRequest: FileDownload] = [:]

    init(destinationDirectory: URL, maxConcurrentDownloads: Int = 6) {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        urlSession = URLSession(configuration: config)
        self.destinationDirectory = destinationDirectory
        self.maxConcurrentDownloads = maxConcurrentDownloads
        (events, continuation) = AsyncStream.makeStream(of: Event.self)

        continuation.onTermination = { [weak self] _ in
            Task { [weak self] in
                await self?.cancelAllDownload(pausing: false)
            }
        }
    }

    func append(_ downloadRequests: [DownloadRequest]) async {
        await withTaskGroup(of: Void.self) { group in
            for downloadRequest in downloadRequests {
                group.addTask { await self.append(downloadRequest) }
            }
        }
    }

    func append(_ downloadRequest: DownloadRequest) async {
        if let index = downloadQueue.firstIndex(where: { $0.downloadRequest == downloadRequest }) {
            if case let .paused(data) = downloadQueue[index].state {
                downloadQueue[index].state = .queued(resumeData: data)
            } else {
                return
            }
        } else {
            downloadQueue.append(
                QueueElement(
                    downloadRequest: downloadRequest,
                    state: .queued(resumeData: nil)
                )
            )
        }

        continuation.yield(Event(state: .queued, downloadRequest: downloadRequest))

        if activeDownloads.count < maxConcurrentDownloads {
            await start(downloadRequest)
        }
    }

    func cancel(_ downloadRequest: DownloadRequest, pausing: Bool = true) async {
        if let download = activeDownloads[downloadRequest] {
            download.cancel(pausing: pausing)
        } else if !pausing, let index = downloadQueue.firstIndex(where: { $0.downloadRequest == downloadRequest }) {
            switch downloadQueue[index].state {
            case let .queued(data):
                await deleteQueuedDownload(index: index, resumeData: data)
            case let .paused(data):
                await deleteQueuedDownload(index: index, resumeData: data)
            default:
                break
            }
        }
    }

    func cancelAllDownload(pausing: Bool = true) async {
        for downloadRequest in activeDownloads.keys {
            await cancel(downloadRequest, pausing: pausing)
        }
    }
}

// MARK: - Private Helpers

private extension DownloadQueue {
    enum ElementState {
        case queued(resumeData: Data?)
        case downloading
        case paused(resumeData: Data?)
    }

    struct QueueElement {
        let downloadRequest: DownloadRequest
        var state: ElementState
    }

    var activeDownloadsCount: Int {
        downloadQueue.count { $0.isDownloading }
    }

    func deleteQueuedDownload(index: Int, resumeData: Data?) async {
        let element = downloadQueue[index]
        downloadQueue.remove(at: index)
        continuation.yield(Event(state: .canceled, downloadRequest: element.downloadRequest))

        if let resumeData = resumeData {
            await deleteTemporaryFileForDownload(
                resumeData: resumeData,
                destinationPath: element.downloadRequest.destinationDirectoryPath
            )
        }
    }

    func destinationDirectory(destinationPath: String) -> URL {
        destinationDirectory
            .appending(path: destinationPath, directoryHint: .notDirectory)
    }

    func deleteTemporaryFileForDownload(resumeData: Data, destinationPath: String) async {
        let download = FileDownload(
            resumeData: resumeData,
            destinationDirectory: destinationDirectory(destinationPath: destinationPath),
            urlSession: urlSession
        )
        download.start()
        download.cancel(pausing: false)
    }

    func processDownloadQueue() async {
        while activeDownloads.count < maxConcurrentDownloads {
            if let element = downloadQueue.first(where: { $0.isQueued }) {
                await start(element.downloadRequest)
            } else {
                break
            }
        }
    }

    func start(_ downloadRequest: DownloadRequest) async {
        guard let index = downloadQueue.firstIndex(where: { $0.downloadRequest == downloadRequest }) else { return }
        let oldElement = downloadQueue[index]
        downloadQueue[index].state = .downloading

        let download = oldElement.resumeData.map {
            FileDownload(
                resumeData: $0,
                destinationDirectory: destinationDirectory(destinationPath: downloadRequest.destinationDirectoryPath),
                urlSession: urlSession
            )
        } ?? FileDownload(
            url: downloadRequest.sourceURL,
            destinationDirectory: destinationDirectory(destinationPath: downloadRequest.destinationDirectoryPath),
            urlSession: urlSession
        )

        activeDownloads[downloadRequest] = download
        download.start()

        continuation.yield(
            Event(
                state: .progress(downloadedBytes: 0, totalBytes: 0),
                downloadRequest: downloadRequest
            )
        )
        Task {
            for await event in download.events {
                await process(event, for: downloadRequest)
            }
            await processDownloadQueue()
        }
    }

    func process(_ event: FileDownload.Event, for downloadRequest: DownloadRequest) async {
        switch event {
        case .completed, .failed:
            downloadQueue.removeAll { $0.downloadRequest == downloadRequest }
            activeDownloads.removeValue(forKey: downloadRequest)
        case let .canceled(data, pausing):
            if let index = downloadQueue.firstIndex(where: { $0.downloadRequest == downloadRequest }) {
                if pausing {
                    downloadQueue[index].state = .paused(resumeData: data)
                } else {
                    downloadQueue.remove(at: index)
                }
            }
            activeDownloads.removeValue(forKey: downloadRequest)
        default: break
        }
        continuation.yield(Event(state: event.downloadState, downloadRequest: downloadRequest))
    }
}

extension FileDownload.Event {
    var downloadState: DownloadQueue.DownloadState {
        switch self {
        case let .progress(downloadedBytes, totalBytes):
            .progress(downloadedBytes: downloadedBytes, totalBytes: totalBytes)
        case .completed:
            .completed
        case let .failed(error):
            .failed(error: error)
        case let .canceled(_, pausing):
            pausing ? .paused : .canceled
        }
    }
}

extension DownloadQueue.QueueElement {
    var isDownloading: Bool {
        if case .downloading = state { return true }
        return false
    }

    var isQueued: Bool {
        if case .queued = state { return true }
        return false
    }

    var resumeData: Data? {
        if case let .queued(data) = state { return data }
        return nil
    }
}
