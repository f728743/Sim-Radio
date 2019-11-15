//
//  LibraryError.swift
//  Sim Radio
//

import Foundation

enum LibraryError: Error {
    case playlistError
    case pathNotFound(path: String)
    case invalidStationID(id: UUID)
    case invalidSeriesID(id: UUID)
    case fragmentNotFound(tag: Tag)
    case notExhaustiveFragment(tag: Tag)
    case wrongPositionTag(tag: Tag)
    case wrongSource
    case wrongCondition
    case fileNotFound(url: URL)
    case compositionCreatingError
}
