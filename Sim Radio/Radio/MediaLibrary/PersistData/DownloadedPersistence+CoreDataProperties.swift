//
//  DownloadedPersistence+CoreDataProperties.swift
//  RadioDownloader
//
//  Created by Alexey Vorobyov on 15.11.2019.
//  Copyright © 2019 Alexey Vorobyov. All rights reserved.
//
//

import Foundation
import CoreData

extension DownloadedPersistence {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadedPersistence> {
        return NSFetchRequest<DownloadedPersistence>(entityName: "Downloaded")
    }

    @NSManaged public var source: URL
    @NSManaged public var task: DownloadTaskPersistence

}
