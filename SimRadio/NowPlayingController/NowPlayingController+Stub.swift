//
//  NowPlayingController+Stub.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 23.04.2025.
//

extension NowPlayingController {
    static var stub: NowPlayingController {
        let mediaPlayer = MediaPlayer()
        mediaPlayer.simRadio = SimRadioMediaPlayerStub()
        return .init(player: mediaPlayer)
    }
}
