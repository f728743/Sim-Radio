//
//  MediaItemView.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 09.04.2025.
//

import Kingfisher
import SwiftUI

struct MediaItemView: View {
    struct Model {
        let artwork: URL?
        let title: String
        let subtitle: String?
        var status: MediaDownloadStatus?
    }

    let model: Model

    var body: some View {
        HStack(spacing: 12) {
            let border = UIScreen.hairlineWidth
            KFImage.url(model.artwork)
                .resizable()
                .frame(width: 48, height: 48)
                .aspectRatio(contentMode: .fill)
                .background(Color(.palette.artworkBackground))
                .clipShape(.rect(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .inset(by: border / 2)
                        .stroke(Color(.palette.artworkBorder), lineWidth: border)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(model.title)
                    .font(.appFont.mediaListItemTitle)
                Text(model.subtitle ?? "")
                    .font(.appFont.mediaListItemSubtitle)
                    .foregroundStyle(Color(.palette.textTertiary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            if let status = model.status {
                MediaDownloadProgressView(status: status)
            }
        }
        .padding(.top, 4)
        .frame(height: 56, alignment: .top)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    MediaItemView(
        model: .init(
            artwork: URL(string: "https://raw.githubusercontent.com/tmp-acc/GTA-V-Radio-Stations-TestDownload" +
                "/master/radio_01_class_rock/radio_01_class_rock.png"),
            title: "Los Santos Rock Radio",
            subtitle: "Classic rock, soft rock, pop rock"
        )
    )
}
