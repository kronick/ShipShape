//
//  Vessel.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/22/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import Foundation
import CoreData


class Vessel: NSManagedObject {
    static var ActiveVessel: Vessel?
        
    class func CreateInContext(moc: NSManagedObjectContext, name: String, propulsion: String? = nil, length: NSNumber? = nil, yearBuilt: NSNumber? = nil, globalID: NSNumber? = nil, notes: String? = nil, owner: Sailor? = nil) -> Vessel {
        let createdVessel = NSEntityDescription.insertNewObjectForEntityForName("Vessel", inManagedObjectContext: moc) as! Vessel
        createdVessel.name = name
        createdVessel.propulsion = propulsion
        createdVessel.length = length
        createdVessel.yearBuilt = yearBuilt
        createdVessel.globalID = globalID
        createdVessel.notes = notes
        createdVessel.owner = owner
        
        return createdVessel
    }
    
    class func FetchByOwnerInContext(moc: NSManagedObjectContext, owner: Sailor) -> [Vessel] {
        let vesselFetchRequest = NSFetchRequest(entityName: "Vessel")
        vesselFetchRequest.predicate = NSPredicate(format: "owner == %@", argumentArray: [owner])
        
        do {
            let vesselResults = try moc.executeFetchRequest(vesselFetchRequest) as! [Vessel]
            return vesselResults
        }
        catch let error as NSError {
            print("Could not fetch Vessel \(error), \(error.userInfo)")
        }
        
        return []
    }
}
