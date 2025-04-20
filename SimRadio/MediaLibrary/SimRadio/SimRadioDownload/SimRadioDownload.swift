//
//  SimRadioDownload.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 21.04.2025.
//

import Foundation

/// Represents an event related to a station's download progress.
struct SimRadioDownloadEvent: Sendable {
    let id: SimStation.ID
    let status: SimRadioDownloadStatus
}

/// Represents the download status, including state and progress.
struct SimRadioDownloadStatus: Equatable, Sendable {
    let state: SimRadioDownloadState
    let totalBytes: Int64
    let downloadedBytes: Int64

    // Convenience initializer
    init(state: SimRadioDownloadState, totalBytes: Int64 = 0, downloadedBytes: Int64 = 0) {
        self.state = state
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
    }
}

/// Represents the possible states of a station's download.
enum SimRadioDownloadState: Equatable, Sendable {
    case scheduled
    case downloading
    case completed
    case paused
    case failed([URL]) // Keep track of failed URLs if needed
}

protocol SimRadioDownload: Actor {
    /// An asynchronous stream of download events for stations.
    var events: AsyncStream<SimRadioDownloadEvent> { get }

    /// Initiates or resumes the download for a specific media item.
    /// - Parameters:
    ///   - id: The ID of the media to download.
    ///   - missing: Optionally, a dictionary specifying which files are known to be missing for partial downloads.
    func downloadStation(withID id: SimStation.ID, missing: [SimFileGroup.ID: [URL]]) async

    /// Pauses the download for a specific station.
    /// - Parameter id: The ID of the station download to pause.
    func pauseDownloadStation(withID id: SimStation.ID) async

    /// Cancels the download for a specific station, potentially removing partially downloaded files.
    /// - Parameter id: The ID of the station download to cancel.
    func cancelDownloadStation(withID id: SimStation.ID) async
}
