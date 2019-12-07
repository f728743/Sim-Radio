//
//  SeriesModelDownloadOperation.swift
//  Sim Radio
//

import Foundation

struct DownloadedSeriesModel {
    let origin: URL
    let model: Model.Series
    let directory: String
}

protocol DownloadedSeriesProvider {
    var series: DownloadedSeriesModel? { get }
}

class SeriesModelDownloadOperation: AsyncOperation {
    typealias Handler = (Result<DownloadedSeriesModel, DownloadError>) -> Void
    var result: DownloadedSeriesModel?

    private let url: URL // it is possible that url ≠ origin
    private let completion: Handler?
    private let directory: String

    init(from url: URL, to directory: String, completion: Handler? = nil) {
        self.url = url
        self.directory = directory
        self.completion = completion
        super.init()
    }

    override func main() {
        if isCancelled { return }

        URLSession.shared.downloadTask(with: url) { localTempFileURL, response, error in
            do {
                guard let localTempFileURL = localTempFileURL,
                    let remoteFileURL = response?.url  else {
                        let error = DownloadError.failedToDownloadSeries(url: self.url)
                        self.state = .finished
                        self.completion?(.failure(error))
                        return
                }
                if self.isCancelled { return }
                let model = try Model.loadSeries(from: localTempFileURL)
                let destinationURL = FileManager.documents
                    .appendingPathComponent(self.directory)
                    .appendingPathComponent(LibraryConstants.seriesJson)
                if self.isCancelled { return }
                try moveFile(from: localTempFileURL, to: destinationURL)
                let result = DownloadedSeriesModel(
                    origin: remoteFileURL,
                    model: model,
                    directory: self.directory)
                self.result = result
                self.state = .finished
                self.completion?(.success(result))
            } catch {
                let error = DownloadError.failedToDownloadSeries(url: self.url)
                self.state = .finished
                self.completion?(.failure(error))
            }
        }.resume()
    }
}

extension SeriesModelDownloadOperation: DownloadedSeriesProvider {
    var series: DownloadedSeriesModel? {
        return result
    }
}
