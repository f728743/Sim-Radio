//
//  SimRadioMediaState.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 21.04.2025.
//

@MainActor
protocol SimRadioMediaState: AnyObject, Sendable {
    var simRadio: SimRadioMedia { get }
    var simDownloadStatus: [SimStation.ID: MediaDownloadStatus] { get }
}

extension MediaState: SimRadioMediaState {
    var simDownloadStatus: [SimStation.ID: MediaDownloadStatus] {
        return Dictionary(uniqueKeysWithValues: downloadStatus.compactMap {
            if case let .simRadio(id) = $0.key {
                return (id, $0.value)
            }
            return nil
        })
    }
}
