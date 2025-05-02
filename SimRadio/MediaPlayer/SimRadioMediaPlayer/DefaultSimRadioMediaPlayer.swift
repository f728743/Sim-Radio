//
//  DefaultSimRadioMediaPlayer.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 01.05.2025.
//

import AVFoundation
import Foundation

@MainActor
class DefaultSimRadioMediaPlayer {
    var player: AVPlayer?
    weak var mediaState: SimRadioMediaState?
}

extension DefaultSimRadioMediaPlayer: SimRadioMediaPlayer {
    func playStation(withID stationID: SimStation.ID) {
        Task {
            do {
                try await doPlayStation(withID: stationID)
            } catch {
                print(error)
            }
        }
    }

    func stop() {
        print("Stop")
        player = nil
    }
}

private extension DefaultSimRadioMediaPlayer {
    func doPlayStation(withID stationID: SimStation.ID) async throws {
        print("Play \(stationID)")
        guard let mediaState else { return }

        guard let stationData = mediaState.stationData(for: stationID) else { return }
        let playlistBuilder = PlaylistBuilder(stationData: stationData)
        let playlist = try await playlistBuilder.makePlaylist(startingAt: Date(), duration: 30)

        let loader = PlayerItemLoader()
        let playerItem = try await loader.loadPlayerItem(playlist: playlist)
        let player = AVPlayer(playerItem: playerItem)
        player.play()
        self.player = player
    }
}
