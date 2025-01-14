//
//  TabBarItem.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 01.01.2025.
//

import SwiftUI

enum TabBarItem: Hashable, CaseIterable {
    case home, radio, library, search
}

extension TabBarItem {
    var title: String {
        switch self {
        case .home: return "Home"
        case .radio: return "Radio"
        case .library: return "Library"
        case .search: return "Search"
        }
    }

    var image: Image {
        switch self {
        case .home: return Image("img_home")
        case .radio: return Image(systemName: "radio")
        case .library: return Image(systemName: "music.note")
        case .search: return Image(systemName: "magnifyingglass")
        }
    }
}
