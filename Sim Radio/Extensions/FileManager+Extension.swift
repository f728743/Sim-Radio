//
//  FileManager+Extension.swift
//  Sim Radio
//

import Foundation

extension FileManager {
    static var documents: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

func moveFile(from source: URL, to destination: URL) throws {
    //        print("moveFile(\(source), \(destination))")
    let fileManager = FileManager.default
    let dstDir = destination.deletingLastPathComponent()
    if !fileManager.fileExists(atPath: dstDir.path) {
        try fileManager.createDirectory(
            at: dstDir,
            withIntermediateDirectories: true,
            attributes: nil)
    }
    if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
    }
    try FileManager.default.moveItem(at: source, to: destination)
}
