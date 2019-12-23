//
//  FileManager+Extension.swift
//  Sim Radio
//

import Foundation

extension FileManager {
    static var documentsURL: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

func moveFile(from source: URL, to destination: URL) throws {
    //        print("moveFile(\(source), \(destination))")
    let fileManager = FileManager.default
    let dstDir = destination.deletingLastPathComponent()
    if !fileManager.fileExists(atPath: dstDir.path) {
        try fileManager.createDirectory(at: dstDir, withIntermediateDirectories: true)
    }
    if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
    }
    try FileManager.default.moveItem(at: source, to: destination)
}

func copyContentsOfDirectory(at: URL, to: URL) throws {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: to.path) {
        try fileManager.createDirectory(at: to, withIntermediateDirectories: true)
    }
    try fileManager.contentsOfDirectory(atPath: at.path).forEach {
        try fileManager.copyItem(at: at.appendingPathComponent($0),
                                 to: to.appendingPathComponent($0))
    }
}
