//
//  DownloadedScreenViewModel.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 12.04.2025.
//

import Observation
import SwiftUI

@Observable @MainActor
class DownloadedScreenViewModel {
    var mediaState: MediaState?
    var items: [Media] {
        mediaState?.donloadedMedia ?? []
    }
}

extension MediaState {
    var donloadedMedia: [Media] {
        downloadStatus
            .map { $0 }
            .filter { $0.value.state == .completed }
            .compactMap {
                guard case let .simRadio(id) = $0.key,
                      let station = simRadio.stations[id] else { return nil }
                return Media(
                    id: .simRadio(station.id),
                    meta: station.meta
                )
            }
    }
}
