//
//  MediaLibrary.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 27.11.2024.
//

import Foundation

actor LibraryManagmentActor {
    func loadSimRadioSeries(url: URL) async throws -> SimRadio.Series {
        let (data, _) = try await URLSession.shared.data(from: url)
        let series = try JSONDecoder().decode(SimRadio.Series.self, from: data)
        return series
    }
}

@MainActor
final class MediaLibrary: ObservableObject {
    var loadManager: LibraryManagmentActor
    @Published var list: [MediaList] = []

    init() {
        loadManager = .init()
    }

    func reload() {
        let baseUrlStr = "https://raw.githubusercontent.com/tmp-acc/GTA-V-Radio-Stations/master"
        let urlStr = "\(baseUrlStr)/sim_radio_stations.json"
        guard let url = URL(string: urlStr) else { return }
        Task {
            do {
                let series = try await loadManager.loadSimRadioSeries(url: url)
                list = [.init(from: series, baseUrl: baseUrlStr)]
            } catch {
                print(error)
            }
        }
    }
}

extension Media {
    init(from station: SimRadio.Station, baseUrl: String) {
        title = station.info.title
        subtitle = station.info.genre
        let artwork = "\(baseUrl)/\(station.tag)/\(station.info.logo)"
        self.artwork = URL(string: artwork)
        online = false
    }
}

extension MediaList {
    init(from series: SimRadio.Series, baseUrl: String) {
        self.init(
            artwork: URL(string: "\(baseUrl)/\(series.info.logo)"),
            title: series.info.title,
            subtitle: nil,
            items: series.stations.map { .init(from: $0, baseUrl: baseUrl) }
        )
    }
}
