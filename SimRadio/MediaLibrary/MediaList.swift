//
//  MediaList.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 29.03.2025.
//

import Foundation

struct MediaList: Identifiable, Hashable, Equatable {
    let id: MediaListID
    let meta: Meta
    let items: [Media]

    struct Meta: Hashable, Equatable {
        let artwork: URL?
        let title: String
        let subtitle: String?
    }
}

struct MediaDownloadStatus {
    enum DownloadState {
        case scheduled
        case inProgress
        case completed
        case paused
    }

    let state: DownloadState
    let totalBytes: Int64
    let downloadedBytes: Int64
}

struct Media: Identifiable, Hashable, Equatable {
    let id: MediaID
    let meta: Meta

    struct Meta: Equatable, Hashable {
        let artwork: URL?
        let title: String
        let listSubtitle: String?
        let detailsSubtitle: String?
        let online: Bool
    }
}

enum MediaListID: Hashable, Equatable {
    case emptyMediaListID
    case simRadioSeries(SimSeries.ID)
}

enum MediaID: Hashable {
    case emptyMediaID
    case simRadio(SimStation.ID)
}

extension MediaList {
    static let empty: MediaList = .init(
        id: .emptyMediaListID,
        meta: .init(
            artwork: nil,
            title: "",
            subtitle: nil
        ),
        items: []
    )
}
