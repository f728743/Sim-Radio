//
//  PlaylistComponent.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 02.05.2025.
//

import Foundation

struct AudioFile: Sendable {
    let url: URL
    let timeRange: TimeRange
    let startTime: TimeInterval
}

struct PlaylistComponent: Sendable {
    let track: AudioFile
    let mixes: [AudioFile]
}

extension AudioFile {
    var playing: TimeRange {
        .init(start: startTime, duration: timeRange.duration - timeRange.start)
    }
}

extension AudioFile: CustomStringConvertible {
    func description(nesting: Int) -> String {
        let start = startTime.rounded(places: 2)
        let from = timeRange.start.rounded(places: 2)
        let to = timeRange.duration.rounded(places: 2)
        let indent = String(repeating: "  ", count: nesting)
        return "\(indent)\(start):(\(from)..\(to)), \(url.pathComponents.suffix(2).joined(separator: "/"))\n"
    }

    var description: String {
        description(nesting: 0)
    }
}

extension PlaylistComponent: CustomStringConvertible {
    var description: String {
        return [
            track.description,
            mixes.description(nesting: 1)
        ].joined()
    }
}

extension Array where Element == PlaylistComponent {
    var description: String {
        map(\.description).joined()
    }
}

extension Array where Element == AudioFile {
    func description(nesting: Int) -> String {
        map { $0.description(nesting: nesting) }.joined()
    }
}

extension Double {
    func rounded(places: Int) -> Double { // TODO: remove
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

struct TimeRange {
    var start: TimeInterval = 0
    var duration: TimeInterval = 0

    var end: TimeInterval {
        start + duration
    }
}
