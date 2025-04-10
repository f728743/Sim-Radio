//
//  MediaDownloadStatus.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 12.04.2025.
//

struct MediaDownloadStatus {
    enum DownloadState {
        case scheduled
        case downloading
        case completed
        case paused
    }

    let state: DownloadState
    let totalBytes: Int64
    let downloadedBytes: Int64
}

extension MediaDownloadStatus: DownloadProgressProtocol {}

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
