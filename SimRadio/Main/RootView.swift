//
//  RootView.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 27.11.2024.
//

import SwiftUI

struct RootView: View {
    @State private var tabSelection: TabBarItem = .home

    var body: some View {
        CustomTabView(selection: $tabSelection) {
            LibraryView()
                .withRouter()
                .tabBarItem(tab: .home, selection: $tabSelection)

            Text("Looking for something?")
                .tabBarItem(tab: .search, selection: $tabSelection)
        }
    }
}

#Preview {
    RootView()
}
