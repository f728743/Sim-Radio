//
//  Media.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 27.11.2024.
//

import Foundation

struct Media: Identifiable {
    let id = UUID()
    let artwork: URL?
    let title: String
    let subtitle: String?
    let online: Bool
}
