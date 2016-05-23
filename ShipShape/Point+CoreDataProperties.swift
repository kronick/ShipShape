//
//  Point+CoreDataProperties.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/22/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Point {

    @NSManaged var latitude: NSNumber?
    @NSManaged var longitude: NSNumber?
    @NSManaged var propulsion: String?
    @NSManaged var globalID: NSNumber?
    @NSManaged var created: NSDate?
    @NSManaged var notes: String?
    @NSManaged var path: Path?

}
