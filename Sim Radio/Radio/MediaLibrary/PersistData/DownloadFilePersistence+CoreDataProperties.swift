//
//  DownloadFilePersistence+CoreDataProperties.swift
//  Sim Radio
//
//  Created by Alexey Vorobyov on 15.11.2019.
//  Copyright © 2019 Alexey Vorobyov. All rights reserved.
//
//

import Foundation
import CoreData


extension DownloadFilePersistence {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadFilePersistence> {
        return NSFetchRequest<DownloadFilePersistence>(entityName: "DownloadFile")
    }

    @NSManaged public var destination: String?
    @NSManaged public var source: URL?
    @NSManaged public var units: Int64
    @NSManaged public var task: DownloadTaskPersistence?

}
