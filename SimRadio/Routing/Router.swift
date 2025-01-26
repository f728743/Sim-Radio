//
//  Router.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 26.01.2025.
//

import SwiftUI

enum Route: Hashable, Equatable {
    case mediaList(item: MediaList)
    case downloaded
}

@Observable
class Router {
    var path = NavigationPath()

    func navigateToMediaList(item: MediaList) {
        path.append(Route.mediaList(item: item))
    }

    func navigateToDownloaded() {
        path.append(Route.downloaded)
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}

private struct RouterViewModifier: ViewModifier {
    @State private var router = Router()
    func body(content: Content) -> some View {
        NavigationStack(path: $router.path) {
            content
                .environment(router)
                .navigationDestination(for: Route.self) { route in
                    RoutedView(route: route)
                }
        }
    }
}

extension View {
    func withRouter() -> some View {
        modifier(RouterViewModifier())
    }
}
