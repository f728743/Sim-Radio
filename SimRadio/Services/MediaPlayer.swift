//
//  MediaPlayer.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 30.11.2024.
//

import AVFoundation
import Foundation

class MediaPlayer {
    var player: AVPlayer?

    func play(_ media: Media) {
        print("Play \(media.meta.title)")
    }

    func stop() {
        print("Stop")
    }
}

private extension MediaPlayer {
    func currentSecondOfDay() -> Double {
        let now = Date()
        let calendar = Calendar.current

        let h = calendar.component(.hour, from: now)
        let m = calendar.component(.minute, from: now)
        let s = calendar.component(.second, from: now)
        return Double(h * 60 * 60 + m * 60 + s)
    }

    @MainActor func testBuildPlaylist(baseUrlStr: String, series: SimRadioDTO.GameSeries) {
        guard
            let baseUrl = URL(string: baseUrlStr),
            let station = series.stations.first
        else { return }

        let nowSec = currentSecondOfDay()
        do {
            let playlist = try Playlist(
                baseUrl: baseUrl,
                gameSeriesSharedFiles: series.gameSeriesShared.fileGroups,
                station: station
            )
            Task {
                let item = try await playlist.playerItem(
                    for: Date().startOfDay,
                    from: nowSec,
                    minDuration: 3 * 60
                )
                let player = AVPlayer(playerItem: item)
                player.play()
                self.player = player
            }
        } catch {
            print(error)
        }
    }
}
