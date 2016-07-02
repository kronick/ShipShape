//
//  Point.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/22/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation


public enum PropulsionMethod: String {
    case Sail
    case Motor
    case Human
    case Anchor
    case None
}
class Point: NSManagedObject {
    class func CreateInContext(moc: NSManagedObjectContext, location: CLLocation, propulsion: PropulsionMethod? = .Sail, remoteID: String? = nil, notes: String? = nil, path: Path? = nil) -> Point {
        let createdPoint = NSEntityDescription.insertNewObjectForEntityForName("Point", inManagedObjectContext: moc) as! Point
        
        
        createdPoint.latitude = location.coordinate.latitude
        createdPoint.longitude = location.coordinate.longitude
        createdPoint.propulsion = propulsion == nil ? PropulsionMethod.Sail.rawValue : propulsion!.rawValue
        createdPoint.remoteID = remoteID
        createdPoint.created = location.timestamp
        createdPoint.notes = notes
        createdPoint.path = path
        
        return createdPoint
    }
    
    class func CreateInContext(moc: NSManagedObjectContext, latitude: CLLocationDegrees, longitude: CLLocationDegrees, timestamp: NSDate? = NSDate(), propulsion: PropulsionMethod? = .Sail, remoteID: String? = nil, notes: String? = nil, path: Path? = nil) -> Point {
        let createdPoint = NSEntityDescription.insertNewObjectForEntityForName("Point", inManagedObjectContext: moc) as! Point
        
        
        createdPoint.latitude = latitude
        createdPoint.longitude = longitude
        createdPoint.propulsion = propulsion == nil ? PropulsionMethod.Sail.rawValue : propulsion!.rawValue
        createdPoint.remoteID = remoteID
        createdPoint.created = timestamp
        createdPoint.notes = notes
        createdPoint.path = path
        
        return createdPoint
    }
    
    func location() -> CLLocation? {
        if self.latitude != nil && self.longitude != nil && self.created != nil {
            let coord = CLLocationCoordinate2D(latitude: self.latitude! as CLLocationDegrees, longitude: self.longitude! as CLLocationDegrees)
            
            let loc = CLLocation(coordinate: coord, altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: self.created!)
            
            return loc
        }
        return nil
    }
}
