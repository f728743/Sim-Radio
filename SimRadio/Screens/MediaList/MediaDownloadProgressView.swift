//
//  MediaDownloadProgressView.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 09.04.2025.
//

import SwiftUI

struct MediaDownloadProgressView: View {
    var status: MediaDownloadStatus = .init(state: .scheduled)
    var size: CGFloat = 12.3

    var body: some View {
        Group {
            switch status.state {
            case .scheduled: spinner(progressValue: status.progress)
            case .downloading: downloading(value: status.progress)
            case .completed: arrowDown
            case .paused: pause
            }
        }
        .frame(width: size, height: size)
    }
}

private extension MediaDownloadProgressView {
    func downloading(value: Double) -> some View {
        ZStack {
            Circle()
                .inset(by: Const.lineWidth / 2)
                .stroke(
                    Color(Palette.stroke),
                    style: StrokeStyle(lineWidth: Const.lineWidth)
                )
            progress(value: value)
        }
    }

    func progress(value: Double) -> some View {
        Circle()
            .inset(by: Const.lineWidth / 2)
            .trim(from: 0, to: value)
            .rotation(.degrees(-90))
            .stroke(
                Color(Palette.brand),
                style: StrokeStyle(
                    lineWidth: Const.lineWidth,
                    lineCap: .round
                )
            )
    }

    func spinner(progressValue: Double) -> some View {
        ZStack {
            let segmentCount: CGFloat = 8
            let circleLength: CGFloat = .pi * (size - Const.lineWidth * 1.1)
            let segmentLength = circleLength / segmentCount
            let dash = segmentLength / 4 * 3
            let space = segmentLength / 4

            Circle()
                .inset(by: Const.lineWidth / 2)
                .rotation(.degrees(-17.0))
                .stroke(
                    Color(Palette.stroke),
                    style: StrokeStyle(
                        lineWidth: Const.lineWidth,
                        lineCap: .butt,
                        dash: [dash, space]
                    )
                )
            progress(value: progressValue)
                .opacity(0.4)
        }
    }

    var arrowDown: some View {
        ZStack {
            Circle()
                .foregroundStyle(Color(Palette.stroke))
            Image(systemName: "arrow.down")
                .font(.system(size: size * 0.55, weight: .black))
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    var pause: some View {
        ZStack {
            Circle()
                .foregroundStyle(Color(Palette.stroke))
            Image(systemName: "pause.fill")
                .font(.system(size: size * 0.58))
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    enum Const {
        static let lineWidth: CGFloat = 2
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    MediaDownloadProgressView(status: .init(state: .scheduled))
    MediaDownloadProgressView(status: .init(state: .scheduled, totalBytes: 100, downloadedBytes: 33))
    MediaDownloadProgressView(status: .init(state: .downloading, totalBytes: 100, downloadedBytes: 33))
    MediaDownloadProgressView(status: .init(state: .paused, totalBytes: 100, downloadedBytes: 33))
    MediaDownloadProgressView(status: .init(state: .completed, totalBytes: 100, downloadedBytes: 100))
}
