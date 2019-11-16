//
//  DownloadedPersistence+CoreDataProperties.swift
//  Sim Radio
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
