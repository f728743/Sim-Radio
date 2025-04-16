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
    let storage: RadioStorage

    init(simRadioDownloader: SimRadioDownload) {
        self.simRadioDownloader = simRadioDownloader
        storage = UserDefaultsRadioStorage()
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
            "GTA-V-Radio-Stations-TestDownload/master/sim_radio_stations.json"
//            "GTA-IV-Radio-Stations/master/sim_radio_stations.json",
//            "GTA-V-Radio-Stations/master/sim_radio_stations.json"
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
        downloadStatus[mediaID] = .init(state: .scheduled)
        if case let .simRadio(stationID) = mediaID {
            storage.setStorageState(.downloadStarted, for: stationID)
        }
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
            switch status.state {
            case .paused, .failed:
                storage.setStorageState(.downloadPaused, for: id)
            case .completed:
                storage.setStorageState(.downloaded, for: id)
            default: break
            }
        default: break
        }
    }

    func loadSimRadio() async {
        let series = storage.addedSeriesIDs

        for id in series {
            do {
                try await loadSimRadio(series: id)
            } catch {
                print(error)
            }
        }
        await updateDownloadState()
    }

    func loadSimRadio(series id: SimGameSeries.ID) async throws {
        let fileURL = id.jsonFileURL
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

        let stations = Array(newMedia.stations.keys)
        await stopCurrentMediaDownload(stations)
        try await removeAllFilesExceptListed(newMedia.fileGroups.values.compactMap { $0 })
        try saveJsonData(series: radio, origin: url)
        storage.addSeries(id: seriesID)
        simRadio = SimRadioMedia(
            series: simRadio.series.merging(newMedia.series) { _, new in new },
            fileGroups: simRadio.fileGroups.merging(newMedia.fileGroups) { _, new in new },
            stations: simRadio.stations.merging(newMedia.stations) { _, new in new }
        )
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

    func stopCurrentMediaDownload(_ stations: [SimStation.ID]) async {
        for station in stations {
            await simRadioDownloader.cancelDownloadMedia(withID: .simRadio(station))
            downloadStatus.removeValue(forKey: .simRadio(station))
        }
    }

    func updateDownloadState() async {
        for (station, storageState) in storage.allStoredStationStates {
            switch storageState {
            case .downloadPaused:
                downloadStatus[.simRadio(station)] = .init(state: .paused)
            case .downloadStarted:
                await resumeDownloading(station)
            case .downloaded:
                downloadStatus[.simRadio(station)] = .init(state: .completed)
            }
        }
    }

    func resumeDownloading(_ station: SimStation.ID) async {
        do {
            let currntStatus = try await simRadio.calculateStationLoacalStatus(station)
            switch currntStatus {
            case .completed:
                storage.setStorageState(.downloaded, for: station)
                downloadStatus[.simRadio(station)] = .init(state: .completed)
                return
            case let .partial(missing: missing):
                simRadioDownloader.downloadMedia(withID: .simRadio(station), missing: missing)
            case .missing:
                break
            }
        } catch {
            print(error)
        }
        downloadStatus[.simRadio(station)] = .init(state: .scheduled)
        simRadioDownloader.downloadMedia(withID: .simRadio(station))
    }

    func calculateStationLoacalStatus(id: MediaID) async throws -> SimRadioMedia.StationLoacalStatus? {
        switch id {
        case let .simRadio(simStationID):
            return try await simRadio.calculateStationLoacalStatus(simStationID)
        default:
            return nil
        }
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
