//
//  DownloadInfo.swift
//  SimRadio
//
//  Created by Alexey Vorobyov
//

import Foundation

struct DownloadInfo: Equatable {
    let url: URL
    var state: DownloadInfo.State = .pending
    var downloadedBytes: Int64 = 0
    var totalBytes: Int64 = 0
}

extension DownloadInfo {
    enum State {
        case pending
        case queued
        case downloading
        case completed
        case failed
        case paused
    }

    init(url: URL, state: DownloadInfo.State) {
        self.url = url
        self.state = state
    }

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(downloadedBytes) / Double(totalBytes)
    }
}

extension DownloadInfo: Identifiable {
    var id: String { url.absoluteString }
}
