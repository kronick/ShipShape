//
//  Vessel+CoreDataProperties.swift
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

extension Vessel {

    @NSManaged var name: String?
    @NSManaged var propulsion: String?
    @NSManaged var length: NSNumber?
    @NSManaged var yearBuilt: NSNumber?
    @NSManaged var remoteID: String?
    @NSManaged var notes: String?
    @NSManaged var paths: NSSet?
    @NSManaged var owner: Sailor?

}
