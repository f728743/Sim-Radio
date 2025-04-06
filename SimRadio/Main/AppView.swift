//
//  AppView.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 14.01.2025.
//

import SwiftUI

struct AppView: View {
    @StateObject private var playerController: NowPlayingController
    @State private var dependencies: AppDependencies

    init() {
        let dependencies = AppDependencies()
        let nowPlaying = NowPlayingController(player: MediaPlayer())
        _playerController = StateObject(wrappedValue: nowPlaying)
        _dependencies = State(wrappedValue: dependencies)
    }

    var body: some View {
        OverlayableRootView {
            OverlaidRootView()
                .environmentObject(playerController)
                .environment(dependencies.mediaState)
        }
    }
}
