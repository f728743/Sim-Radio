//
//  AppView.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 14.01.2025.
//

import SwiftUI

struct AppView: View {
    @StateObject private var playerController: NowPlayingController

    init() {
        let nowPlaying = NowPlayingController(player: Player())
        _playerController = StateObject(wrappedValue: nowPlaying)
    }

    var body: some View {
        OverlayableRootView {
            OverlaidRootView()
                .environmentObject(playerController)
        }
    }
}
