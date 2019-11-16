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
    var result: DownloadedSeriesModel?

    private let url: URL // it is possible that url ≠ origin
    private let completion: ((DownloadedSeriesModel) -> Void)?
    private let directory: String

    init(from url: URL, to directory: String, completion: ((DownloadedSeriesModel) -> Void)? = nil) {
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
                self.completion?(result)
            } catch {
                self.state = .finished
                print(error) // TODO:
            }
        }.resume()
    }
}

extension SeriesModelDownloadOperation: DownloadedSeriesProvider {
    var series: DownloadedSeriesModel? {
        return result
    }
}
