//
//  Path+CoreDataProperties.swift
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

extension Path {

    @NSManaged var title: String?
    @NSManaged var created: NSDate?
    @NSManaged var globalID: NSNumber?
    @NSManaged var notes: String?
    @NSManaged var totalTime: NSNumber?
    @NSManaged var totalDistance: NSNumber?
    @NSManaged var averageSpeed: NSNumber?
    @NSManaged var type: String?
    @NSManaged var state: String?
    @NSManaged var vessel: Vessel?
    @NSManaged var points: NSOrderedSet?
    @NSManaged var creator: Sailor?

}
