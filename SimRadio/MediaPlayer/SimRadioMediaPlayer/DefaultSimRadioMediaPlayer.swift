//
//  DefaultSimRadioMediaPlayer.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 01.05.2025.
//

import AVFoundation
import Foundation

class DefaultSimRadioMediaPlayer {
    var player: AVPlayer?
}

extension DefaultSimRadioMediaPlayer: SimRadioMediaPlayer {
    func playStation(withID stationID: SimStation.ID) {
        print("Play \(stationID)")
    }

    func stop() {
        print("Stop")
    }
}

private extension DefaultSimRadioMediaPlayer {
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
            let playlist = try PlayerItemBuilder(
                baseUrl: baseUrl,
                gameSeriesSharedFiles: series.gameSeriesShared.fileGroups,
                station: station
            )
            Task {
                let item = try await playlist.makePlayerItem(
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
