//
//  DownloadTaskPersistence+CoreDataProperties.swift
//  Sim Radio
//
//  Created by Alexey Vorobyov on 15.11.2019.
//  Copyright © 2019 Alexey Vorobyov. All rights reserved.
//
//

import Foundation
import CoreData


extension DownloadTaskPersistence {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadTaskPersistence> {
        return NSFetchRequest<DownloadTaskPersistence>(entityName: "DownloadTask")
    }

    @NSManaged public var downloaded: NSSet?
    @NSManaged public var files: NSSet?
    @NSManaged public var series: SeriesPersistence?
    @NSManaged public var station: StationPersistence?

}

// MARK: Generated accessors for downloaded
extension DownloadTaskPersistence {

    @objc(addDownloadedObject:)
    @NSManaged public func addToDownloaded(_ value: DownloadedPersistence)

    @objc(removeDownloadedObject:)
    @NSManaged public func removeFromDownloaded(_ value: DownloadedPersistence)

    @objc(addDownloaded:)
    @NSManaged public func addToDownloaded(_ values: NSSet)

    @objc(removeDownloaded:)
    @NSManaged public func removeFromDownloaded(_ values: NSSet)

}

// MARK: Generated accessors for files
extension DownloadTaskPersistence {

    @objc(addFilesObject:)
    @NSManaged public func addToFiles(_ value: DownloadFilePersistence)

    @objc(removeFilesObject:)
    @NSManaged public func removeFromFiles(_ value: DownloadFilePersistence)

    @objc(addFiles:)
    @NSManaged public func addToFiles(_ values: NSSet)

    @objc(removeFiles:)
    @NSManaged public func removeFromFiles(_ values: NSSet)

}
