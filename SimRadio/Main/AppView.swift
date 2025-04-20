//
//  AppView.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 14.01.2025.
//

import SwiftUI

struct AppView: View {
    @State private var playerController: NowPlayingController
    @State private var mediaState: MediaState

    init() {
        let nowPlaying = NowPlayingController(player: MediaPlayer())
        let simRadioDownload = DefaultSimRadioDownload()

        let simRadioLibrary = DefaultSimRadioLibrary(
            storage: UserDefaultsRadioStorage(),
            simRadioDownload: simRadioDownload
        )

        let mediaState = MediaState(
            simRadioLibrary: simRadioLibrary
        )
        simRadioLibrary.delegate = mediaState
        simRadioLibrary.mediaState = mediaState
        simRadioDownload.mediaState = mediaState
        Task {
            await mediaState.load()
        }

        _playerController = State(wrappedValue: nowPlaying)
        _mediaState = State(wrappedValue: mediaState)
    }

    var body: some View {
        OverlayableRootView {
            OverlaidRootView()
                .environment(playerController)
                .environment(mediaState)
        }
    }
}
