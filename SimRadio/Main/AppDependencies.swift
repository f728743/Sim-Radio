//
//  AppDependencies.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 06.04.2025.
//

@MainActor
struct AppDependencies {
    let mediaState: MediaState

    init() {
        mediaState = MediaState(simRadioDownloader: SimRadioDownload())
        mediaState.load()
    }
}
