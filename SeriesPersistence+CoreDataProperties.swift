//
//  SeriesPersistence+CoreDataProperties.swift
//  Sim Radio
//
//  Created by Alexey Vorobyov on 15.11.2019.
//  Copyright © 2019 Alexey Vorobyov. All rights reserved.
//
//

import Foundation
import CoreData


extension SeriesPersistence {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SeriesPersistence> {
        return NSFetchRequest<SeriesPersistence>(entityName: "Series")
    }

    @NSManaged public var directory: String?
    @NSManaged public var origin: URL?
    @NSManaged public var downloadTask: DownloadTaskPersistence?
    @NSManaged public var stations: NSSet?

}

// MARK: Generated accessors for stations
extension SeriesPersistence {

    @objc(addStationsObject:)
    @NSManaged public func addToStations(_ value: StationPersistence)

    @objc(removeStationsObject:)
    @NSManaged public func removeFromStations(_ value: StationPersistence)

    @objc(addStations:)
    @NSManaged public func addToStations(_ values: NSSet)

    @objc(removeStations:)
    @NSManaged public func removeFromStations(_ values: NSSet)

}
