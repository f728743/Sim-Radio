//
//  StationPersistence+CoreDataProperties.swift
//  RadioDownloader
//
//  Created by Alexey Vorobyov on 14.11.2019.
//  Copyright © 2019 Alexey Vorobyov. All rights reserved.
//
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
