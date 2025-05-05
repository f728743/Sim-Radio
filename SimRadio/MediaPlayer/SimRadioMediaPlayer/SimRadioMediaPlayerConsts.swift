//
//  SimRadioMediaPlayerConsts.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 07.05.2025.
//

import CoreMedia

extension CMTimeScale {
    static let defaultTimeScale: CMTimeScale = 600
}

extension CMTime {
    init(seconds: Double) {
        self.init(
            seconds: seconds,
            preferredTimescale: .defaultTimeScale
        )
    }
}

func += (lhs: inout CMTime, rhs: CMTime) {
    lhs = lhs + rhs
}
