//
//  StationModelDownloadOperation.swift
//  Sim Radio
//

import Foundation

struct DownloadedStationModel {
    let origin: URL
    let model: Model.Station
    let directory: String
}

protocol DownloadedStationProvider {
    var station: DownloadedStationModel? { get }
}

class StationModelDownloadOperation: AsyncOperation {
    var result: DownloadedStationModel?

    private let url: URL
    private let directory: String
    private let completion: ((DownloadedStationModel) -> Void)?

    init(from url: URL, to directory: String, completion: ((DownloadedStationModel) -> Void)? = nil) {
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
                let model = try Model.loadStation(from: localTempFileURL)
                let destinationURL = FileManager.documentsURL
                    .appendingPathComponent(self.directory)
                    .appendingPathComponent(LibraryConstants.stationJson)
                if self.isCancelled { return }
                try moveFile(from: localTempFileURL, to: destinationURL)
                let result = DownloadedStationModel(
                    origin: remoteFileURL,
                    model: model,
                    directory: self.directory)
                self.result = result
                self.state = .finished
                self.completion?(result)
            } catch {
                self.state = .finished
                print(error)
            }
        }.resume()
    }
}

extension StationModelDownloadOperation: DownloadedStationProvider {
    var station: DownloadedStationModel? {
        return result
    }
}
