//
//  Sailor+CoreDataProperties.swift
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

extension Sailor {

    @NSManaged var realName: String?
    @NSManaged var username: String?
    @NSManaged var profile: String?
    @NSManaged var vessels: NSSet?
    @NSManaged var paths: NSSet?

}
