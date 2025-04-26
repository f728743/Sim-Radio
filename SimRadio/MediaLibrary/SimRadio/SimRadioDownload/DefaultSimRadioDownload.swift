//
//  DefaultSimRadioDownload.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 26.03.2025.
//

import Foundation

private enum DownloadLog {
    case info(verbose: Bool), warning, error
}

private let logSettings: [DownloadLog] = [.warning, .error]

extension DefaultSimRadioDownload: SimRadioDownload {}

actor DefaultSimRadioDownload {
    @MainActor weak var mediaState: SimRadioMediaState?
    private let downloadQueue: DownloadQueue
    private var stationDownloads: [SimStation.ID: StationDownloadInfo] = [:]
    private var groupDownloads: [SimFileGroup.ID: FileGroupDownloadInfo] = [:]

    let events: AsyncStream<SimRadioDownloadEvent>
    private var eventContinuation: AsyncStream<SimRadioDownloadEvent>.Continuation?

    struct StationDownloadInfo {
        var status: SimRadioDownloadStatus
        let fileGroupIDs: [SimFileGroup.ID]
    }

    struct FileGroupDownloadInfo {
        let id: SimFileGroup.ID
        var status: SimRadioDownloadStatus
        var files: [FileDownloadInfo]
    }

    struct FileDownloadInfo: Equatable {
        let url: URL
        var status: SimRadioDownloadStatus
    }

    init() {
        downloadQueue = DownloadQueue(
            destinationDirectory: .documentsDirectory,
            maxConcurrentDownloads: 8
        )

        (events, eventContinuation) = AsyncStream.makeStream(of: SimRadioDownloadEvent.self)

        Task { [weak self] in
            guard let self else { return }
            let stream = self.downloadQueue.events
            for await event in stream {
                await self.handleDownloaderEvent(event)
            }
            await self.finishEventStream()
        }
    }

    deinit {
        eventContinuation?.finish()
    }

    func downloadStation(withID id: SimStation.ID, missing: [SimFileGroup.ID: [URL]] = [:]) {
        Task {
            await doDownloadStation(withID: id, missing: missing)
        }
    }

    func cancelDownloadStation(withID id: SimStation.ID) async -> Bool {
        log(info: "Cancelling download for station \(id.value)")
        guard let requests = requestsOnlyForStation(withID: id) else {
            log(warning: "Cannot cancel download for untracked station: \(id.value)")
            return false
        }
        log(info: "Cancelling \(requests.count) download requests for station \(id.value)")
        for request in requests {
            await downloadQueue.cancel(request)
        }
        return true
    }
}

private extension DefaultSimRadioDownload {
    func finishEventStream() {
        eventContinuation?.finish()
        eventContinuation = nil
    }

    func doDownloadStation(withID id: SimStation.ID, missing: [SimFileGroup.ID: [URL]]) async {
        guard let mediaState = await mediaState else { return }

        // Access mediaState on the MainActor
        let stations = await mediaState.simRadio.stations
        guard let station = stations[id] else {
            log(error: "Station \(id) not found in mediaState")
            return
        }

        guard !stationDownloads.keys.contains(id) else {
            log(warning: "Station \(id) already tracked for download.")
            // Optionally: Re-evaluate state or publish current status?
            return
        }

        log(info: "Starting download for station \(id)")
        await download(station: station, missing: missing)
    }

    func download(station: SimStation, missing: [SimFileGroup.ID: [URL]]) async {
        guard let mediaState = await mediaState else { return }
        stationDownloads[station.id] = StationDownloadInfo(
            status: .initial,
            fileGroupIDs: station.fileGroupIDs
        )

        print("Download missing", missing)

        var groupURLs: [SimFileGroup.ID: [URL]] = [:]
        let allFileGroups = await mediaState.simRadio.fileGroups // Access MainActor state
        for groupID in station.fileGroupIDs {
            guard groupDownloads[groupID] == nil else {
                continue
            }

            guard let urls = allFileGroups[groupID]?.files.compactMap({ $0.url }) else {
                continue
            }

            let files = urls.map { FileDownloadInfo(url: $0, status: .initial) }
            let downloadableGroup = FileGroupDownloadInfo(id: groupID, status: .initial, files: files)
            groupDownloads[groupID] = downloadableGroup
            groupURLs[groupID] = urls
        }

        for (groupID, urls) in groupURLs {
            log(info: "Queuing group \(groupID) with \(urls.count) files for station \(station.id.value)")
            Task {
                await updateFileSizes(for: urls, groupID: groupID) // Pass groupID here too
            }
        }
        let downloadRequest: [DownloadQueue.DownloadRequest] = groupURLs.flatMap { groupID, urls in
            urls.map {
                .init(
                    sourceURL: $0,
                    destinationDirectoryPath: groupID.value
                )
            }
        }
        await downloadQueue.append(downloadRequest)
    }

    func requestsOnlyForStation(withID id: SimStation.ID) -> [DownloadQueue.DownloadRequest]? {
        var stationDownloads = stationDownloads
        guard let stationInfo = stationDownloads.removeValue(forKey: id) else {
            return nil
        }

        let otherGroupIDs = Set(stationDownloads.values.flatMap { $0.fileGroupIDs })
        let stationOnlyGroupIDs = stationInfo.fileGroupIDs.filter { !otherGroupIDs.contains($0) }

        return stationOnlyGroupIDs.flatMap { groupID in
            downloadRequestInProgressForGroup(withID: groupID)
        }
    }

    func downloadRequestInProgressForGroup(withID groupID: SimFileGroup.ID) -> [DownloadQueue.DownloadRequest] {
        (groupDownloads[groupID]?.files ?? []).compactMap {
            guard $0.status.state.isInProgress else { return nil }
            return .init(sourceURL: $0.url, destinationDirectoryPath: groupID.value)
        }
    }

    func groupID(of downloadRequest: DownloadQueue.DownloadRequest) -> SimFileGroup.ID {
        .init(value: downloadRequest.destinationDirectoryPath)
    }

    func handleDownloaderEvent(_ event: DownloadQueue.Event) async {
        let groupID = groupID(of: event.downloadRequest)
        guard let groupDownload = groupDownloads[groupID] else {
            log(warning: "Missing groupID for event: \(event)")
            return
        }

        guard let fileIndex = groupDownload.files
            .firstIndex(where: { $0.url == event.downloadRequest.sourceURL })
        else {
            log(warning: "fileIndex for event: \(event)")
            return
        }

        guard var groupInfo = groupDownloads[groupID] else {
            log(warning: "Group \(groupID) not found for event: \(event)")
            return
        }

        let fileInfo = groupInfo.files[fileIndex]
        let newFileInfo = fileInfo.updated(queueState: event.state)
        groupInfo.files[fileIndex] = newFileInfo
        if let newGroupStatus = await groupInfo.files.overallStatus {
            groupInfo.status = newGroupStatus
        }
        groupDownloads[groupID] = groupInfo

        let groupStations = findStationIDs(for: groupID)
        for stationID in groupStations {
            guard let stationInfo = stationDownloads[stationID] else {
                log(error: "Station \(stationID) not found during status calculation.")
                continue
            }

            guard let newStationStatus = await calculateStationStatus(stationInfo: stationInfo) else {
                log(warning: "nil ftatus for station with id \(stationID)")
                continue
            }
            if newStationStatus.state.isDone {
                cleanupDownloadTracking(for: stationID)
                stationDownloads[stationID] = nil
            } else {
                stationDownloads[stationID]?.status = newStationStatus
            }

            if stationInfo.status != newStationStatus {
                eventContinuation?.yield(.init(id: stationID, status: newStationStatus))
                logProgress()
            }
        }
        if groupStations.isEmpty {
            log(warning: "Could not find station for groupID \(groupID)")
        }
    }

    func cleanupDownloadTracking(for stationID: SimStation.ID) {
        guard let stationInfo = stationDownloads.removeValue(forKey: stationID) else {
            return
        }
        let groupIDsToKeep = Set(stationDownloads.values.flatMap { $0.fileGroupIDs })
        stationInfo
            .fileGroupIDs
            .filter { !groupIDsToKeep.contains($0) }
            .forEach { groupDownloads[$0] = nil }
    }

    func findStationIDs(for groupID: SimFileGroup.ID) -> [SimStation.ID] {
        stationDownloads.compactMap { id, download in
            download.fileGroupIDs.contains(groupID) ? id : nil
        }
    }

    func calculateStationStatus(stationInfo: StationDownloadInfo) async -> SimRadioDownloadStatus? {
        var fileGroupStatuses: [SimRadioDownloadStatus] = []
        for fileGroupID in stationInfo.fileGroupIDs {
            if let status = await groupStatus(fileGroupID) {
                fileGroupStatuses.append(status)
            }
        }

        return await fileGroupStatuses.overallStatus
    }

    func groupStatus(_ groupID: SimFileGroup.ID) async -> SimRadioDownloadStatus? {
        await groupDownloads[groupID]?.files.overallStatus
    }

    /// Fetches and updates the total size for each file URL using HEAD requests.
    func updateFileSizes(for urls: [URL], groupID: SimFileGroup.ID) async {
        log(info: "Updating file sizes for group \(groupID)")
        await withTaskGroup(of: (URL, Int64?).self) { group in
            for url in urls {
                group.addTask {
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        // Check for Content-Length header
                        let contentLength = response.expectedContentLength // This is Int64
                        return (url, contentLength > 0 ? contentLength : nil) // Return nil if size is unknown/invalid
                    } catch {
                        log(error: "Failed to fetch size for \(url.lastPathComponent): \(error)")
                        return (url, nil)
                    }
                }
            }

            // Collect results as they complete
            for await(url, size) in group {
                if let size = size {
                    await update(fileURL: url, groupID: groupID, size: size)
                }
            }
        }
        log(info: "Finished updating file sizes for group \(groupID)")
    }

    /// Updates the total size for a specific file within a group.
    func update(fileURL: URL, groupID: SimFileGroup.ID, size: Int64) async {
        guard var groupInfo = groupDownloads[groupID],
              let fileIndex = groupInfo.files.firstIndex(where: { $0.url == fileURL })
        else {
            log(error: "File \(fileURL.lastPathComponent) " +
                "or group \(groupID) not found for size update.")
            return
        }

        let downloadInfo = groupInfo.files[fileIndex]
        groupInfo.files[fileIndex] = .init(
            url: downloadInfo.url,
            status: .init(state: downloadInfo.status.state, totalBytes: size)
        )
        if let newGroupStatus = await groupInfo.files.overallStatus {
            groupInfo.status = newGroupStatus
        }
        groupDownloads[groupID] = groupInfo
    }

    func logProgress() {
        Task {
            guard logSettings.logInfo else { return }
            let overall = await Array(stationDownloads.values).overallStatus
            log(info: "--- Download Progress (\(Date().ISO8601Format())) ---")
            log(info: "Overall: \(overall?.state) - \(overall?.progressString)")

            for (stationID, station) in stationDownloads {
                log(info: "  Station \(stationID.value): \(station.status.state) - \(station.status.progressString)")
                for groupID in station.fileGroupIDs {
                    let group = await groupStatus(groupID)
                    log(info: "    Group \(groupID.value): \(group?.state) - \(group?.progressString)")
                    // Optional: Print individual file status within group for detailed debug
                    if logSettings.logVerboseInfo, let group = groupDownloads[groupID] {
                        for file in group.files {
                            let fileName = file.url.lastPathComponent
                            log(verboseInfo: "      File \(fileName): \(file.status.state) - \(file.status.progressString)")
                        }
                    }
                }
            }
            log(info: "---------------------------------------")
        }
    }
}

extension Sequence {
    func asyncCompactMap<T>(
        _ transform: (Element) async -> T?
    ) async -> [T] {
        var values = [T]()

        for element in self {
            if let transformed = await transform(element) {
                values.append(transformed)
            }
        }
        return values
    }
}

extension DefaultSimRadioDownload.FileDownloadInfo {
    func updated(queueState: DownloadQueue.DownloadState) -> DefaultSimRadioDownload.FileDownloadInfo {
        let newStatus: SimRadioDownloadStatus
        switch queueState {
        case .queued:
            newStatus = .init(
                state: .scheduled,
                downloadedBytes: status.downloadedBytes,
                totalBytes: status.totalBytes
            )
        case let .progress(downloadedBytes, totalBytes):
            newStatus = .init(
                state: .downloading,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes == 0 ? status.totalBytes : totalBytes
            )
        case .completed:
            newStatus = .init(
                state: .completed,
                downloadedBytes: status.totalBytes,
                totalBytes: status.totalBytes
            )
        case .canceled:
            newStatus = .init(
                state: .canceled,
                downloadedBytes: status.downloadedBytes,
                totalBytes: status.totalBytes
            )
        case .failed:
            newStatus = .init(
                state: .failed([url]),
                downloadedBytes: status.downloadedBytes,
                totalBytes: status.totalBytes
            )
        }
        return .init(url: url, status: newStatus)
    }
}

private protocol SimRadioDownloadStatusProtocol {
    var state: SimRadioDownloadState { get }
    var totalBytes: Int64 { get }
    var downloadedBytes: Int64 { get }
}

extension SimRadioDownloadStatus: SimRadioDownloadStatusProtocol {}

extension DefaultSimRadioDownload.FileDownloadInfo: SimRadioDownloadStatusProtocol {
    var state: SimRadioDownloadState { status.state }
    var totalBytes: Int64 { status.totalBytes }
    var downloadedBytes: Int64 { status.downloadedBytes }
}

extension DefaultSimRadioDownload.StationDownloadInfo: SimRadioDownloadStatusProtocol {
    var state: SimRadioDownloadState { status.state }
    var totalBytes: Int64 { status.totalBytes }
    var downloadedBytes: Int64 { status.downloadedBytes }
}

// Aggregation logic for collections
extension Collection where Element: SimRadioDownloadStatusProtocol {
    var overallState: SimRadioDownloadState? {
        get async {
            if contains(where: { $0.state == .downloading }) {
                return .downloading
            }

            let incomplete = filter { $0.state != .completed }
            if incomplete.isEmpty {
                return .completed
            }

            if incomplete.contains(where: { $0.state == .canceled }) {
                return .canceled
            }

            if incomplete.contains(where: { $0.state.isDone }) {
                return .failed(flatMap { $0.state.failedURLs })
            }
            return isEmpty ? nil : .scheduled
        }
    }

    var overallTotalBytes: Int64 { reduce(0) { $0 + $1.totalBytes } }
    var overallDownloadedBytes: Int64 { reduce(0) { $0 + $1.downloadedBytes } }

    var overallStatus: SimRadioDownloadStatus? {
        get async {
            await overallState.map {
                .init(
                    state: $0,
                    downloadedBytes: overallDownloadedBytes,
                    totalBytes: overallTotalBytes
                )
            }
        }
    }
}

extension Int64 {
    private nonisolated(unsafe) static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()

    var bytesToMB: String {
        return Self.formatter.string(fromByteCount: Swift.max(0, self))
    }
}

private func log(verboseInfo: String) {
    guard logSettings.logVerboseInfo else { return }
    print(verboseInfo)
}

private func log(info: String) {
    guard logSettings.logInfo else { return }
    print(info)
}

private func log(warning: String) {
    guard logSettings.contains(
        where: {
            if case .warning = $0 { return true }
            return false
        }
    ) else { return }
    print(warning)
}

private func log(error: String) {
    guard logSettings.contains(
        where: {
            if case .error = $0 { return true }
            return false
        }
    ) else { return }
    print(error)
}

extension Collection where Element == DownloadLog {
    var logVerboseInfo: Bool {
        contains(
            where: {
                if case let .info(verbose) = $0 {
                    if verbose { return true }
                }
                return false
            }
        )
    }

    var logInfo: Bool {
        contains(
            where: {
                if case .info = $0 { return true }
                return false
            }
        )
    }
}
