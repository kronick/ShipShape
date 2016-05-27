//
//  Path.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/22/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation

public enum PathType: String {
    case Past = "past"
    case Future = "future"
}
public enum PathState: String {
    case Editing = "editing"
    case Complete = "complete"
    case Recording = "recording"
    case Downloading = "downloading"
    case Fault = "fault"
}

class Path: NSManagedObject {
    
    // MARK: - Class methods to create and fetch
    
    class func CreateInContext(moc: NSManagedObjectContext, title: String? = "Untitled Path", created: NSDate? = NSDate(), globalID: NSNumber? = nil, notes: String? = nil, totalTime: NSNumber? = 0, totalDistance: NSNumber? = 0, averageSpeed: NSNumber? = nil, type: PathType? = .Past, state: PathState? = .Editing, vessel: Vessel? = Vessel.ActiveVessel, creator: Sailor? = Sailor.ActiveSailor, points: NSOrderedSet? = nil) -> Path {
        let newPath = NSEntityDescription.insertNewObjectForEntityForName("Path", inManagedObjectContext: moc) as! Path
        
        newPath.created = created
        newPath.globalID = globalID
        newPath.notes = notes
        newPath.totalTime = totalTime
        newPath.totalDistance = totalDistance
        newPath.averageSpeed = averageSpeed
        newPath.type = type?.rawValue
        newPath.state = state?.rawValue
        newPath.vessel = vessel
        newPath.creator = creator
        newPath.points = points
        
        return newPath
    }
    
    class func CreateFromGeoJSONInContext(moc: NSManagedObjectContext, filename: String, title: String? = nil,  created: NSDate? = NSDate(), saveOnComplete: Bool = true, completion: ()->() = {}) -> Path {
        let newPath = NSEntityDescription.insertNewObjectForEntityForName("Path", inManagedObjectContext: moc) as! Path
        
        newPath.created = created
        newPath.title = title == nil ? filename : title
        newPath.state = PathState.Downloading.rawValue
        
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            let jsonPath = NSBundle.mainBundle().pathForResource(filename, ofType:"geojson")
            
            guard let jsonData = NSData(contentsOfFile: jsonPath!) else {
                newPath.state = PathState.Fault.rawValue
                print("Could not load JSON Data file")
                return
            }
            
            let json = JSON(data: jsonData)
            guard let coordinates = json["features"][0]["geometry"]["coordinates"].array else {
                newPath.state = PathState.Fault.rawValue
                print ("No coordinates in this file.")
                return
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                // Create a coordinate for each entry and tie it back to this path
                for c in coordinates {
                    Point.CreateInContext(moc, latitude: c[1].doubleValue, longitude: c[0].doubleValue, path: newPath)
                }
                newPath.state = PathState.Complete.rawValue
                
                if saveOnComplete {
                    do {
                        try moc.save()
                    }
                    catch let error as NSError {
                        print("Could not save data \(error), \(error.userInfo)")
                    }
        
                }
                completion()
            }
            
        })

        
        return newPath
    }
  
    class func FetchPathsWithStateInContext(moc: NSManagedObjectContext, state: PathState) -> [Path] {
        let pathFetchRequest = NSFetchRequest(entityName: "Path")
        pathFetchRequest.predicate = NSPredicate(format: "state == %@", argumentArray: [state.rawValue])
        do {
            let pathResults = try moc.executeFetchRequest(pathFetchRequest) as! [Path]
            return pathResults
        }
        catch let error as NSError {
            print("Could not fetch Paths \(error), \(error.userInfo)")
        }
        
        return [Path]()
    }
    
    
    class func FetchPathsForSailorInContext(moc: NSManagedObjectContext, sailor: Sailor) -> [Path] {
        let pathFetchRequest = NSFetchRequest(entityName: "Path")
        pathFetchRequest.predicate = NSPredicate(format: "creator == %@", argumentArray: [sailor])
        pathFetchRequest.sortDescriptors = [NSSortDescriptor(key: "created", ascending: false)]
        
        do {
            let pathResults = try moc.executeFetchRequest(pathFetchRequest) as! [Path]
            return pathResults
        }
        catch let error as NSError {
            print("Could not fetch Paths \(error), \(error.userInfo)")
        }
        
        return [Path]()
    }
    
    
    // MARK: - Instance methods
    
    func recalculateStats() {
        if self.points == nil || self.points!.count == 0 {
            self.totalTime = 0
            self.totalDistance = 0
            self.averageSpeed = 0
            return
        }
        
        var newTotalTime = 0 as Double
        var newTotalDistance = 0 as Double
        var newAverageSpeedSum = 0 as Double
        
        var lastLoc: CLLocation? = nil
        for p in self.points! {
            guard let point = p as? Point else {
                continue
            }
            let thisLoc = CLLocation(coordinate: CLLocationCoordinate2D(latitude: point.latitude! as Double, longitude: point.longitude! as Double), altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: point.created!)
            
            if lastLoc != nil {
                // Calculate time delta and add to total
                let timeDelta = thisLoc.timestamp.timeIntervalSinceDate(lastLoc!.timestamp)
                
                // Calculate distance delta and add to total
                let distanceDelta = thisLoc.distanceFromLocation(lastLoc!)
                
                // Calculate speed and add to average sum
                let speed = distanceDelta / timeDelta // meters / second
                
                newTotalTime  += timeDelta
                newTotalDistance += distanceDelta
                newAverageSpeedSum += speed
                
            }
            lastLoc = thisLoc
        }
        
        let firstPoint = (self.points!.firstObject as! Point)
        let lastPoint = (self.points!.lastObject as! Point)
        
        self.totalTime = lastPoint.created?.timeIntervalSinceDate(firstPoint.created!)
        self.totalDistance = newTotalDistance
        self.averageSpeed = newTotalDistance / newTotalTime
        
    }
}
