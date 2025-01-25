//
//  AppView.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 14.01.2025.
//

import SwiftUI

struct AppView: View {
    @StateObject private var playerController: NowPlayingController
    @StateObject private var library: MediaLibrary

    init() {
        let library = MediaLibrary()
        library.reload()
        let nowPlaying = NowPlayingController(player: Player())
        _library = StateObject(wrappedValue: library)
        _playerController = StateObject(wrappedValue: nowPlaying)
    }

    var body: some View {
        OverlayableRootView {
            OverlaidRootView()
                .environmentObject(playerController)
                .environmentObject(library)
        }
    }
}
