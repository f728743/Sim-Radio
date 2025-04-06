//
//  URL+Extensions.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 08.04.2025.
//

import Foundation

extension URL {
    func ensureDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: path) {
            try FileManager.default.createDirectory(
                at: self,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    func removeFileIfExists() throws {
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(at: self)
        }
    }
}
