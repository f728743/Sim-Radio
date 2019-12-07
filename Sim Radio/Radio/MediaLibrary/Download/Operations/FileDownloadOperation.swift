//
//  FileDownloadOperation.swift
//  Sim Radio
//

import Foundation

class FileDownloadOperation: AsyncOperation {
    private let url: URL
    private let directory: String
    private let completion: (() -> Void)?

    init(from url: URL, to directory: String, completion: (() -> Void)? = nil) {
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
                        throw DownloadError.failedToDownloadFile(url: self.url)
                }
                if self.isCancelled { return }
                let destinationURL = FileManager.documents
                    .appendingPathComponent(self.directory)
                    .appendingPathComponent(remoteFileURL.lastPathComponent)
                if self.isCancelled { return }
                try moveFile(from: localTempFileURL, to: destinationURL)
                self.state = .finished
                self.completion?()
            } catch {
                self.state = .finished
                print(error)
            }
        }.resume()
    }
}
