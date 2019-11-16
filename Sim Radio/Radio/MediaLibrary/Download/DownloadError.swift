//
//  DownloadError.swift
//  Sim Radio
//

import Foundation

enum DownloadError: Error {
    case internalError
    case failedToDownloadSeries(url: URL)
    case wrongFileSeriesFormat(url: URL)
    case failedToDownloadStation(url: URL)
    case failedToDownloadFile(url: URL)
    case alreadyDownloading(url: URL)
    case failedToFindLocalURL
}
