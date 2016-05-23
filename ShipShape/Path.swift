//
//  Path.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/22/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import Foundation
import CoreData


class Path: NSManagedObject {
    static let ValidTypes = Set(["past", "planned"])
    static let ValidStates = Set(["editing", "complete", "recording"])

    class func CreateInContext(moc: NSManagedObjectContext, created: NSDate? = NSDate(), globalID: NSNumber? = nil, notes: String? = nil, totalTime: NSNumber? = 0, totalDistance: NSNumber? = 0, averageSpeed: NSNumber? = nil, type: String? = "past", state: String? = "editing", vessel: Vessel? = Vessel.ActiveVessel, creator: Sailor? = Sailor.ActiveSailor, points: NSOrderedSet? = nil) -> Path {
        let newPath = NSEntityDescription.insertNewObjectForEntityForName("Path", inManagedObjectContext: moc) as! Path
        
        newPath.created = created
        newPath.globalID = globalID
        newPath.notes = notes
        newPath.totalTime = totalTime
        newPath.totalDistance = totalDistance
        newPath.averageSpeed = averageSpeed
        newPath.type = type
        newPath.state = state
        newPath.vessel = vessel
        newPath.creator = creator
        newPath.points = points
        
        return newPath
    }
  
    
}
