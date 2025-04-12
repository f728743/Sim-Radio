//
//  MediaState.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 26.03.2025.
//

import Foundation
import Observation

@Observable @MainActor
class MediaState {
    var simRadio: SimRadioMedia = .empty
    private(set) var downloadStatus: [MediaID: MediaDownloadStatus] = [:]
    let simRadioDownloader: SimRadioDownload

    init(simRadioDownloader: SimRadioDownload) {
        self.simRadioDownloader = simRadioDownloader
        simRadioDownloader.mediaState = self
        Task { [weak self] in
            guard let self else { return }
            let stream = await self.simRadioDownloader.events
            for await event in stream {
                await self.handleDownloaderEvent(event)
            }
        }
    }

    var mediaList: [MediaList] {
        simRadio.series.values.map { series in
            MediaList(
                id: .simRadioSeries(series.id),
                meta: series.meta,
                items: series.stations.compactMap {
                    guard let station = simRadio.stations[$0] else { return nil }
                    return Media(
                        id: .simRadio(station.id),
                        meta: station.meta
                    )
                }
            )
        }
    }

    func populate() async {
        let baseUrl = "https://raw.githubusercontent.com/tmp-acc/"
        let simRadioURLs = [
            //            "GTA-V-Radio-Stations-TestDownload/master/sim_radio_stations.json"
//            "GTA-IV-Radio-Stations/master/sim_radio_stations.json",
            "GTA-V-Radio-Stations/master/sim_radio_stations.json"
        ].compactMap { URL(string: "\(baseUrl)\($0)") }

        await addSimRadio(urls: simRadioURLs)
    }

    func load() {
        Task {
            await loadSimRadio()
        }
    }

    func download(_ mediaID: MediaID) async {
        guard !downloadStatus.keys.contains(mediaID) else { return }
        downloadStatus[mediaID] = .new
        simRadioDownloader.downloadMedia(withID: mediaID)
    }
}

extension MediaDownloadStatus.DownloadState {
    init(_ state: SimRadioDownload.DownloadState) {
        switch state {
        case .completed: self = .completed
        case .scheduled: self = .scheduled
        case .downloading: self = .downloading
        case .paused: self = .paused
        case .failed: self = .paused
        }
    }
}

private extension MediaState {
    func handleDownloaderEvent(_ event: SimRadioDownload.Event) async {
        switch event {
        case let .updatedStation(id, status):
            downloadStatus[.simRadio(id)] = .init(
                state: .init(status.state),
                totalBytes: status.totalBytes,
                downloadedBytes: status.downloadedBytes
            )
        default: break
        }
    }

    func loadSimRadio() async {
        let series: [String] = UserDefaults
            .standard
            .array(forKey: SimGameSeries.userDefaultsKey) as? [String] ?? []
        for id in series {
            do {
                try await loadSimRadio(series: .init(value: id))
            } catch {
                print(error)
            }
        }
        let mediaList: [MediaID] = simRadio.stations.keys.map { .simRadio($0) }
        await updateDownloadState(mediaList)
    }

    func loadSimRadio(series id: SimGameSeries.ID) async throws {
        let fileURL = id.directoryURL.appending(path: SimGameSeries.defaultFileName)
        let jsonData = try await URLSession.shared.data(from: fileURL)
        let radio = try JSONDecoder().decode(SimRadioDTO.GameSeries.self, from: jsonData.0)
        guard let url = radio.origin.map({ URL(string: $0) }) ?? nil else { return }
        let newMedia = SimRadioMedia(dto: radio, origin: url)
        simRadio = SimRadioMedia(
            series: simRadio.series.merging(newMedia.series) { _, new in new },
            fileGroups: simRadio.fileGroups.merging(newMedia.fileGroups) { _, new in new },
            stations: simRadio.stations.merging(newMedia.stations) { _, new in new }
        )
    }

    func addSimRadio(urls: [URL]) async {
        for url in urls {
            do {
                try await addSimRadio(url: url)
            } catch {
                print(error)
            }
        }
    }

    func addSimRadio(url: URL) async throws {
        let jsonData = try await URLSession.shared.data(from: url)
        let radio = try JSONDecoder().decode(SimRadioDTO.GameSeries.self, from: jsonData.0)
        let newMedia = SimRadioMedia(dto: radio, origin: url)

        guard newMedia.series.keys.count == 1,
              let seriesID = newMedia.series.keys.first
        else { return }

        let mediaList: [MediaID] = newMedia.stations.keys.map { .simRadio($0) }
        await stopCurrentMediaDownload(mediaList)
        try await removeAllFilesExceptListed(newMedia.fileGroups.values.compactMap { $0 })
        try saveJsonData(series: radio, origin: url)
        saveToUserDefaults(seriesID)
        simRadio = SimRadioMedia(
            series: simRadio.series.merging(newMedia.series) { _, new in new },
            fileGroups: simRadio.fileGroups.merging(newMedia.fileGroups) { _, new in new },
            stations: simRadio.stations.merging(newMedia.stations) { _, new in new }
        )
        await updateDownloadState(mediaList)
    }

    func saveJsonData(series: SimRadioDTO.GameSeries, origin: URL) throws {
        let directory = SimGameSeries.ID(origin: origin).directoryURL
        try directory.ensureDirectoryExists()
        let fileURL = directory.appending(path: SimGameSeries.defaultFileName, directoryHint: .notDirectory)
        try fileURL.removeFileIfExists()
        let gameSeries = SimRadioDTO.GameSeries(
            origin: origin.absoluteString,
            info: series.info,
            gameSeriesShared: series.gameSeriesShared,
            stations: series.stations,
        )
        let jsonData = try JSONEncoder().encode(gameSeries)
        try jsonData.write(to: fileURL)
    }

    func saveToUserDefaults(_ seriesID: SimGameSeries.ID) {
        let currentIDs: [String] = UserDefaults
            .standard
            .array(forKey: SimGameSeries.userDefaultsKey) as? [String] ?? []
        guard !currentIDs.contains(seriesID.value) else { return }
        UserDefaults.standard.set(currentIDs + [seriesID.value], forKey: SimGameSeries.userDefaultsKey)
    }

    func stopCurrentMediaDownload(_ mediaIDs: [MediaID]) async {
        for id in mediaIDs {
            await simRadioDownloader.cancelDownloadMedia(withID: id)
            downloadStatus.removeValue(forKey: id)
        }
    }

    func updateDownloadState(_: [MediaID]) async {
        // TODO:
    }

    func removeAllFilesExceptListed(_: [SimFileGroup]) async throws {
        // TODO:
//        let fileManager = FileManager.default
//        let allFiles = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
//
//        for fileURL in allFiles {
//            if !filesToKeep.contains(fileURL) {
//                try fileManager.removeItem(at: fileURL)
//            }
//        }
    }
}
