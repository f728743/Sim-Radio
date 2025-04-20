//
//  DefaultSimRadioLibrary.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 23.04.2025.
//

import Foundation

@MainActor
class DefaultSimRadioLibrary {
    let simRadioDownload: any SimRadioDownload
    let storage: any SimRadioStorage
    weak var mediaState: SimRadioMediaState?
    weak var delegate: SimRadioLibraryDelegate?

    init(
        storage: any SimRadioStorage,
        simRadioDownload: any SimRadioDownload
    ) {
        self.storage = storage
        self.simRadioDownload = simRadioDownload

        Task { [weak self] in
            guard let self else { return }
            let stream = await self.simRadioDownload.events
            for await event in stream {
                await self.handleDownloaderEvent(event)
            }
        }
    }
}

extension DefaultSimRadioLibrary: SimRadioLibrary {
    func testPopulate() async {
        let baseUrl = "https://raw.githubusercontent.com/tmp-acc/"
        let simRadioURLs = [
            //            "GTA-V-Radio-Stations-TestDownload/master/sim_radio_stations.json"
//            "GTA-IV-Radio-Stations/master/sim_radio_stations.json",
            "GTA-V-Radio-Stations/master/sim_radio_stations.json"
        ].compactMap { URL(string: "\(baseUrl)\($0)") }

        await addSimRadio(urls: simRadioURLs)
    }

    func downloadStation(_ stationID: SimStation.ID) async {
        storage.setStorageState(.downloadStarted, for: stationID)
        await simRadioDownload.downloadStation(withID: stationID, missing: [:])
    }

    func removeDownload(_ stationID: SimStation.ID) async {
        await stopCurrentDownload([stationID])
        guard let mediaState else { return }
        let otherDownloadedStationIDs = mediaState.simDownloadStatus.keys.filter { $0 != stationID }
        let fileGroupIDsToKeep = mediaState.simRadio.sharedFileGroups(of: stationID, among: otherDownloadedStationIDs)
        let stationFileGroupIDs = mediaState.simRadio.stations[stationID]?.fileGroupIDs ?? []
        let fileGroupIDsToDelete = Array(Set(stationFileGroupIDs).subtracting(fileGroupIDsToKeep))
        do {
            try await removeFiles(of: fileGroupIDsToDelete)
            stationID.directoryURL.removeDirectoryIfEmpty()
        } catch {
            print(error)
        }
    }

    func pauseDownload(_: SimStation.ID) async {}

    func load() {
        Task {
            await loadSimRadio()
        }
    }
}

private extension DefaultSimRadioLibrary {
    func handleDownloaderEvent(_ event: SimRadioDownloadEvent) async {
        delegate?.simRadioLibrary(
            self,
            didChangeDownloadStatus: .init(
                state: .init(event.status.state),
                totalBytes: event.status.totalBytes,
                downloadedBytes: event.status.downloadedBytes
            ),
            for: event.id
        )
        switch event.status.state {
        case .paused, .failed:
            storage.setStorageState(.downloadPaused, for: event.id)
        case .completed:
            storage.setStorageState(.downloaded, for: event.id)
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
        await updateStationsDownloadState()
    }

    func loadSimRadio(series id: SimGameSeries.ID) async throws {
        let fileURL = id.jsonFileURL
        let jsonData = try await URLSession.shared.data(from: fileURL)
        let radio = try JSONDecoder().decode(SimRadioDTO.GameSeries.self, from: jsonData.0)
        guard let url = radio.origin.map({ URL(string: $0) }) ?? nil else { return }
        notifyAdded(SimRadioMedia(dto: radio, origin: url))
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
        let newSimRadio = SimRadioMedia(dto: radio, origin: url)

        guard newSimRadio.series.keys.count == 1,
              let seriesID = newSimRadio.series.keys.first
        else { return }

        let stations = Array(newSimRadio.stations.keys)
        await stopCurrentDownload(stations)
        try saveJsonData(series: radio, origin: url)
        storage.addSeries(id: seriesID)
        notifyAdded(newSimRadio)
    }

    func notifyAdded(_ new: SimRadioMedia) {
        guard let mediaState else { return }
        let curren = mediaState.simRadio
        delegate?.simRadioLibrary(
            self,
            didChange: SimRadioMedia(
                series: curren.series.merging(new.series) { _, new in new },
                fileGroups: curren.fileGroups.merging(new.fileGroups) { _, new in new },
                stations: curren.stations.merging(new.stations) { _, new in new }
            )
        )
    }

    func stopCurrentDownload(_ stationIDs: [SimStation.ID]) async {
        for stationID in stationIDs {
            await simRadioDownload.cancelDownloadStation(withID: stationID)
            delegate?.simRadioLibrary(
                self,
                didChangeDownloadStatus: nil,
                for: stationID
            )
            storage.removeStorageState(for: stationID)
        }
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

    func resumeDownloading(_ stationID: SimStation.ID) async {
        do {
            guard let mediaState else { return }
            let curren = mediaState.simRadio
            let currntStatus = try await curren.calculateStationLoacalStatus(stationID)
            switch currntStatus {
            case .completed:
                storage.setStorageState(.downloaded, for: stationID)
                delegate?.simRadioLibrary(
                    self,
                    didChangeDownloadStatus: .init(state: .completed),
                    for: stationID
                )
                return
            case let .partial(missing: missing):
                await simRadioDownload.downloadStation(withID: stationID, missing: missing)
            case .missing:
                break
            }
        } catch {
            print(error)
        }
        delegate?.simRadioLibrary(
            self,
            didChangeDownloadStatus: .init(state: .scheduled),
            for: stationID
        )
        await simRadioDownload.downloadStation(withID: stationID, missing: [:])
    }

    func updateStationsDownloadState() async {
        for (station, storageState) in storage.allStoredStationStates {
            switch storageState {
            case .downloadPaused:
                delegate?.simRadioLibrary(
                    self,
                    didChangeDownloadStatus: .init(state: .paused),
                    for: station
                )
            case .downloadStarted:
                await resumeDownloading(station)
            case .downloaded:
                delegate?.simRadioLibrary(
                    self,
                    didChangeDownloadStatus: .init(state: .completed),
                    for: station
                )
            }
        }
    }

    func removeFiles(of fileGroupIDs: [SimFileGroup.ID]) async throws {
        guard let allFileGroups = mediaState?.simRadio.fileGroups else { return }
        let fileGroups = fileGroupIDs.compactMap { allFileGroups[$0] }
        for fileGroup in fileGroups {
            let fileURLs = fileGroup.files.map { fileGroup.id.localFileURL(for: $0.url) }
            fileURLs.forEach { $0.remove() }
            fileGroup.id.directoryURL.removeDirectoryIfEmpty()
        }
    }
}

extension MediaDownloadStatus.DownloadState {
    init(_ state: SimRadioDownloadState) {
        switch state {
        case .completed: self = .completed
        case .scheduled: self = .scheduled
        case .downloading: self = .downloading
        case .paused: self = .paused
        case .failed: self = .paused
        }
    }
}
