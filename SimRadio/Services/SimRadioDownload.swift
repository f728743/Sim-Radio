//
//  SimRadioDownload.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 26.03.2025.
//

import Foundation

private enum DownloadLog {
    case info(verbose: Bool), warning, error
}

private let logSettings: [DownloadLog] = [.info(verbose: false), .warning, .error]

actor SimRadioDownload {
    @MainActor var mediaState: MediaState?
    private let downloadQueue: DownloadQueue
    private var stationDownloads: [SimStation.ID: DownloadableStation] = [:]
    private var groupDownloads: [SimFileGroup.ID: DownloadableFileGroup] = [:]

    private var eventContinuation: AsyncStream<Event>.Continuation?
    private(set) lazy var events: AsyncStream<Event> = AsyncStream { continuation in
        self.eventContinuation = continuation
    }

    enum Event {
        case updatedFileGroup(id: SimFileGroup.ID, status: DownloadStatus)
        case updatedStation(id: SimStation.ID, status: DownloadStatus)
    }

    struct DownloadStatus {
        let state: DownloadState
        let totalBytes: Int64
        let downloadedBytes: Int64
    }

    enum DownloadState {
        case queued
        case downloading
        case completed
        case paused
        case failed([URL])
    }

    struct DownloadableStation {
        var status: DownloadStatus
        let fileGroupIDs: [SimFileGroup.ID]
    }

    struct DownloadableFileGroup {
        let id: SimFileGroup.ID
        var files: [DownloadInfo]
    }

    init() {
        downloadQueue = DownloadQueue(
            destinationDirectory: .documentsDirectory,
            maxConcurrentDownloads: 8
        )

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

    nonisolated func downloadMedia(withID id: MediaID) {
        Task {
            await doDownloadMedia(withID: id)
        }
    }

    nonisolated func pauseDownloadMedia(withID _: MediaID) {
        Task {
            // TODO: await doPauseDownloadMedia(withID: id)
        }
    }

    func cancelDownloadMedia(withID _: MediaID) async {
        // TODO:
    }
}

private extension SimRadioDownload {
    func finishEventStream() {
        eventContinuation?.finish()
        eventContinuation = nil
    }

    func doDownloadMedia(withID id: MediaID) async {
        guard case let .simRadio(stationID) = id else { return }
        guard let mediaState = await mediaState else { return }

        // Access mediaState on the MainActor
        let stations = await mediaState.simRadio.stations
        guard let station = stations[stationID] else {
            log(error: "Station \(stationID) not found in mediaState")
            return
        }

        guard !stationDownloads.keys.contains(stationID) else {
            log(warning: "Station \(stationID) already tracked for download.")
            // Optionally: Re-evaluate state or publish current status?
            return
        }

        log(info: "Starting download for station \(stationID)")
        await download(station: station)
    }

    func download(station: SimStation) async {
        guard let mediaState = await mediaState else { return }
        stationDownloads[station.id] = DownloadableStation(
            status: .init(state: .queued, totalBytes: 0, downloadedBytes: 0),
            fileGroupIDs: station.fileGroups
        )

        var groupURLs: [SimFileGroup.ID: [URL]] = [:]
        let allFileGroups = await mediaState.simRadio.fileGroups // Access MainActor state
        for groupID in station.fileGroups {
            guard groupDownloads[groupID] == nil else {
                continue
            }

            guard let urls = allFileGroups[groupID]?.files.compactMap({ $0.url }) else {
                continue
            }

            let urlGroups = urls.map { ($0, groupID) }
            let groupOfURLUpdate = Dictionary(uniqueKeysWithValues: urlGroups)

            let files = urls.map { DownloadInfo(url: $0, state: .queued) }
            let downloadableGroup = DownloadableFileGroup(id: groupID, files: files)
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

        // Update the station's entry with all its group IDs
        if var stationDownload = stationDownloads[station.id] {
            // Calculate initial state/progress after adding groups
            let calculatedStatus = await calculateStationStatus(stationID: station.id)
            stationDownload.status = calculatedStatus
            stationDownloads[station.id] = stationDownload
            // Yield initial station status event
            eventContinuation?.yield(.updatedStation(id: station.id, status: calculatedStatus))
        }
    }

    func groupID(of downloadRequest: DownloadQueue.DownloadRequest) -> SimFileGroup.ID? {
        .init(value: downloadRequest.destinationDirectoryPath)
    }

    func handleDownloaderEvent(_ event: DownloadQueue.Event) async {
        guard let groupID = groupID(of: event.downloadRequest),
              let fileIndex = groupDownloads[groupID]?
              .files
              .firstIndex(where: { $0.url == event.downloadRequest.sourceURL })
        else {
            log(warning: "Missing groupID or fileIndex for event: \(event)")
            return
        }

        guard var groupInfo = groupDownloads[groupID] else {
            log(warning: "Group \(groupID) not found for event: \(event)")
            return
        }

        let (fileInfo, stateChanged) = groupInfo.files[fileIndex].updated(queueState: event.state)

        groupInfo.files[fileIndex] = fileInfo
        groupDownloads[groupID] = groupInfo

//        if case .completed = event.state {
//            groupIDByURL.removeValue(forKey: event.url)
//        }
        // --- Event Publishing Logic ---
        // Only publish if state potentially changed or progress occurred
        if stateChanged || event.isProgress {
            // 1. Calculate and yield group status
            let groupStatus = groupState(groupID)
            eventContinuation?.yield(.updatedFileGroup(id: groupID, status: groupStatus))

            // 2. Find the station associated with this group
            let groupStations = findStationIDs(for: groupID)
            for stationID in groupStations {
                // 3. Calculate and yield station status
                let stationStatus = await calculateStationStatus(stationID: stationID)

                // Update internal state as well
                stationDownloads[stationID]?.status = stationStatus

                eventContinuation?.yield(.updatedStation(id: stationID, status: stationStatus))
            }
            if groupStations.isEmpty {
                log(warning: "Could not find station for groupID \(groupID)")
            }
        }
        // --- End Event Publishing Logic ---

        // Optional: Keep printProgress for debugging? Remove if events are handled externally.
        logProgress()
    }

    func findStationIDs(for groupID: SimFileGroup.ID) -> [SimStation.ID] {
        stationDownloads.compactMap { id, download in
            download.fileGroupIDs.contains(groupID) ? id : nil
        }
    }

    func calculateStationStatus(stationID: SimStation.ID) async -> DownloadStatus {
        guard let stationDownloadInfo = stationDownloads[stationID] else {
            // Should not happen if called correctly
            log(error: "Station \(stationID) not found during status calculation.")
            return DownloadStatus(state: .queued, totalBytes: 0, downloadedBytes: 0)
        }
        return stationDownloadInfo
            .fileGroupIDs.map { groupState($0) }
            .overallStatus
    }

    func groupState(_ groupID: SimFileGroup.ID) -> DownloadStatus {
        guard let files = groupDownloads[groupID]?.files else {
            log(warning: "GroupState called for unknown groupID \(groupID)")
            return DownloadStatus(
                state: .queued,
                totalBytes: 0,
                downloadedBytes: 0,
            )
        }
        return files.overallStatus
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
                        return (url, nil) // Indicate failure to get size
                    }
                }
            }

            // Collect results as they complete
            for await(url, size) in group {
                if let size = size {
                    update(fileURL: url, groupID: groupID, size: size)
                }
            }
        }
        log(info: "Finished updating file sizes for group \(groupID)")

        // After sizes are updated, recalculate and yield status updates
        // This ensures progress calculation is accurate sooner.
        let groupStatus = groupState(groupID)
        eventContinuation?.yield(.updatedFileGroup(id: groupID, status: groupStatus))
        let groupStations = findStationIDs(for: groupID)
        for stationID in groupStations {
            let stationStatus = await calculateStationStatus(stationID: stationID)
            stationDownloads[stationID]?.status = stationStatus // Update internal state
            eventContinuation?.yield(.updatedStation(id: stationID, status: stationStatus))
        }
    }

    /// Updates the total size for a specific file within a group.
    func update(fileURL: URL, groupID: SimFileGroup.ID, size: Int64) {
        guard var groupInfo = groupDownloads[groupID],
              let fileIndex = groupInfo.files.firstIndex(where: { $0.url == fileURL })
        else {
            log(error: "File \(fileURL.lastPathComponent) " +
                "or group \(groupID) not found for size update.")
            return
        }

        groupInfo.files[fileIndex].update(totalBytes: size)
        groupDownloads[groupID] = groupInfo
    }

    func logProgress() {
        guard logSettings.logInfo else { return }
        let overall = Array(stationDownloads.values)
        log(info: "--- Download Progress (\(Date().ISO8601Format())) ---")
        log(info: "Overall: \(overall.overallState) - \(overall.progressString)")

        for (stationID, station) in stationDownloads {
            log(info: "  Station \(stationID.value): \(station.status.state) - \(station.progressString)")
            for groupID in station.fileGroupIDs {
                let group = groupState(groupID)
                log(info: "    Group \(groupID.value): \(group.state) - \(group.progressString)")
                // Optional: Print individual file status within group for detailed debug
                if logSettings.logVerboseInfo, let group = groupDownloads[groupID] {
                    for file in group.files {
                        let fileName = file.url.lastPathComponent
                        log(verboseInfo: "      File \(fileName): \(file.state) - \(file.progressString)")
                    }
                }
            }
        }
        log(info: "---------------------------------------")
    }
}

extension DownloadInfo {
    // TODO: check logic
    func updated(queueState: DownloadQueue.DownloadState) -> (info: DownloadInfo, stateChanged: Bool) {
        var result = self
        var stateChanged = false
        // Update file state based on the event
        let previousState = state
        switch queueState {
        case let .progress(downloadedBytes, totalBytes):
            if state != .downloading { // Only set downloading on first progress?
                // fileInfo.state = .downloading // Let group state calc handle this?
                // stateChanged = previousState != fileInfo.state
            }
            // Always update bytes, state remains downloading implicitly
            // unless changed by other events. If it was paused, progress indicates resume.
            if state == .paused || state == .queued {
                result.update(state: .downloading)
                stateChanged = true
            }
            result.update(downloadedBytes: downloadedBytes, totalBytes: totalBytes)

        case .completed:
            result.update(state: .completed)
            // Ensure progress is 100% if totalBytes is known
            if totalBytes > 0 {
                result.update(downloadedBytes: totalBytes)
            } else {
                // If total size wasn't fetched, maybe try again or log warning?
                log(warning: "File \(url.lastPathComponent) completed with unknown total size.")
            }
            stateChanged = previousState != result.state

        case let .failed(error):
            // Store error description or keep simple .failed state?
            // Let's keep it simple for now, aggregation collects URLs.
            result.update(state: .failed) // Indicate failure
            stateChanged = previousState != result.state
            log(error: "Download failed for \(url.lastPathComponent): \(error.localizedDescription)")

        case .paused:
            if state == .downloading { // Only transition from downloading to paused
                result.update(state: .paused)
                stateChanged = true
            }

        case .queued:
            // Usually means download hasn't started or was reset.
            if state != .queued { // Only update if not already queued
                result.update(state: .queued)
                stateChanged = true
            }

        case .canceled:
            // Treat cancel as reverting to queued or a distinct state?
            // Reverting to queued might be simplest for now.
            if state != .queued {
                result.update(state: .queued)
                result.update(downloadedBytes: 0) // Reset progress on cancel
                stateChanged = true
            }
        }
        return (info: result, stateChanged: stateChanged)
    }
}

extension DownloadQueue.Event {
    var isProgress: Bool {
        if case .progress = state { return true }
        return false
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

protocol DownloadProgressProtocol {
    var totalBytes: Int64 { get }
    var downloadedBytes: Int64 { get }
}

extension DownloadProgressProtocol {
    var progress: Double {
        guard totalBytes != 0 else { return 0.0 }
        return (Double(downloadedBytes) / Double(totalBytes)).clamped(to: 0.0 ... 1.0)
    }

    var percent: Double { progress * 100 }
    var percentString: String { String(format: "%.1f%%", percent) }
    var progressString: String { "\(percentString) (\(downloadedBytes.bytesToMB) / \(totalBytes.bytesToMB))" }
}

// Internal enum to simplify state aggregation
private enum SimDownloadStateInternal {
    case downloading
    case completed
    case paused
    case failed
    case queued
}

// Protocol combining state and progress for aggregation
private protocol SimDownloadStateInternalProtocol {
    var internalState: SimDownloadStateInternal { get }
    var failedURLs: [URL] { get }
}

private protocol DownloadStatusInternalProtocol:
    SimDownloadStateInternalProtocol,
    DownloadProgressProtocol {}

extension Array: DownloadProgressProtocol where Element: DownloadProgressProtocol {
    var totalBytes: Int64 { reduce(0) { $0 + $1.totalBytes } }
    var downloadedBytes: Int64 { reduce(0) { $0 + $1.downloadedBytes } }
}

// Aggregation logic for collections
extension Collection where Element: SimDownloadStateInternalProtocol {
    var overallState: SimRadioDownload.DownloadState {
        if contains(where: { $0.internalState == .downloading }) {
            return .downloading
        }

        let finalStates: [SimDownloadStateInternal] = [.completed, .paused, .failed]
        if let state = finalStates.first(where: { state in
            allSatisfy { $0.internalState == state }
        }) {
            switch state {
            case .completed: return .completed
            case .paused: return .paused
            case .failed: return .failed(flatMap { $0.failedURLs })
            default: fatalError()
            }
        }
        return .queued
    }
}

extension Array where Element: DownloadStatusInternalProtocol {
    var overallStatus: SimRadioDownload.DownloadStatus {
        .init(
            state: overallState,
            totalBytes: totalBytes,
            downloadedBytes: downloadedBytes,
        )
    }
}

extension DownloadInfo: DownloadStatusInternalProtocol {
    fileprivate var failedURLs: [URL] {
        if case .failed = state {
            return [url]
        } else {
            return []
        }
    }

    fileprivate var internalState: SimDownloadStateInternal {
        switch state {
        case .downloading: return .downloading
        case .completed: return .completed
        case .paused: return .paused
        case .failed: return .failed
        case .pending: return .queued
        case .queued: return .queued
        }
    }
}

extension SimRadioDownload.DownloadStatus: DownloadStatusInternalProtocol {
    fileprivate var failedURLs: [URL] { state.failedURLs }
    fileprivate var internalState: SimDownloadStateInternal { state.internalState }
}

extension SimRadioDownload.DownloadableStation: DownloadStatusInternalProtocol {
    fileprivate var failedURLs: [URL] { status.failedURLs }
    fileprivate var internalState: SimDownloadStateInternal { status.state.internalState }
    var totalBytes: Int64 { status.totalBytes }
    var downloadedBytes: Int64 { status.downloadedBytes }
}

private extension SimRadioDownload.DownloadState {
    var failedURLs: [URL] {
        if case let .failed(urls) = self {
            return urls
        } else {
            return []
        }
    }

    var internalState: SimDownloadStateInternal {
        switch self {
        case .downloading: return .downloading
        case .completed: return .completed
        case .paused: return .paused
        case .failed: return .failed
        case .queued: return .queued
        }
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
