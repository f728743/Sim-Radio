//
//  StationPersistence+CoreDataProperties.swift
//  Sim Radio
//

import Foundation
import CoreData

extension StationPersistence {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StationPersistence> {
        return NSFetchRequest<StationPersistence>(entityName: "Station")
    }

    @NSManaged public var directory: String
    @NSManaged public var origin: URL
    @NSManaged public var downloadTask: DownloadTaskPersistence?
    @NSManaged public var series: SeriesPersistence

}
