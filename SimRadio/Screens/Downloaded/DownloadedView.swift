//
//  DownloadedView.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 26.01.2025.
//

import SwiftUI

struct DownloadedView: View {
    var body: some View {
        empty
            .padding(.horizontal, 40)
            .offset(y: -ViewConst.compactNowPlayingHeight)
    }
}

extension DownloadedView {
    var empty: some View {
        VStack(spacing: 0) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 48))
                .foregroundStyle(Color(.palette.textTertiary))
            Text("Download Stations to Listen to Offline")
                .font(.system(size: 22, weight: .semibold))
                .padding(.top, 16)
            Text("Downloaded Stations will appear here.")
                .font(.system(size: 17, weight: .regular))
                .padding(.top, 8)
                .foregroundStyle(Color(.palette.textTertiary))
        }
        .multilineTextAlignment(.center)
    }
}

#Preview {
    DownloadedView()
}
