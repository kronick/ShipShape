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
import SwiftyJSON

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

struct PathMetadata {
    var created: NSDate?
    var remoteID: String?
    var title: String?
    var notes: String?
    var totalTime: NSNumber?
    var totalDistance: NSNumber?
    var averageSpeed: NSNumber?
    var type: PathType?
    var state: PathState?
    var vessel: Vessel?
    var sailor: Sailor?
}

class Path: NSManagedObject {
    
    // MARK: - Class methods to create and fetch
    
    class func CreateInContext(moc: NSManagedObjectContext, title: String? = "Untitled Path", created: NSDate? = NSDate(), remoteID: String? = nil, notes: String? = nil, totalTime: NSNumber? = 0, totalDistance: NSNumber? = 0, averageSpeed: NSNumber? = nil, type: PathType? = .Past, state: PathState? = .Editing, vessel: Vessel? = Vessel.ActiveVessel, creator: Sailor? = Sailor.ActiveSailor, points: NSOrderedSet? = nil) -> Path {
        let newPath = NSEntityDescription.insertNewObjectForEntityForName("Path", inManagedObjectContext: moc) as! Path
        
        newPath.created = created
        newPath.remoteID = remoteID
        newPath.notes = notes
        newPath.totalTime = totalTime
        newPath.totalDistance = totalDistance
        newPath.averageSpeed = averageSpeed
        newPath.type = type?.rawValue
        newPath.state = state?.rawValue
        newPath.vessel = vessel
        newPath.creator = creator
        newPath.points = points
        newPath.title = title
        
        return newPath
    }
    
    class func CreateFromMetadataInContext(moc: NSManagedObjectContext, metadata: PathMetadata) -> Path {
        return CreateInContext(moc, title: metadata.title, created: metadata.created, remoteID: metadata.remoteID, notes: metadata.notes, totalTime: metadata.totalTime, totalDistance: metadata.totalDistance, averageSpeed: metadata.averageSpeed, type: metadata.type, state: metadata.state, vessel: metadata.vessel, creator: metadata.sailor)
    }
    
    class func CreateFromGeoJSONInContext(moc: NSManagedObjectContext, filename: String, title: String? = nil, creator: Sailor? = Sailor.ActiveSailor, created: NSDate? = NSDate(), saveOnComplete: Bool = true, completion: ()->() = {}) -> Path {
        let newPath = NSEntityDescription.insertNewObjectForEntityForName("Path", inManagedObjectContext: moc) as! Path
        
        newPath.created = created
        newPath.creator = creator
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
    
    class func ClearCacheInContext(moc: NSManagedObjectContext) {
        // Make sure a sailor is set to active or we'll delete everything
        guard let activeSailor = Sailor.ActiveSailor else {
            print("No active sailor set!!!")
            return
        }
        print(activeSailor)
        
        let pathFetchRequest = NSFetchRequest(entityName: "Path")
        pathFetchRequest.predicate = NSPredicate(format: "temporary == 1 AND (creator != %@ OR creator == nil)", argumentArray: [activeSailor])
        //pathFetchRequest.predicate = NSPredicate(format: "temporary == 1", argumentArray: [])
        do {
            if let pathResults = try moc.executeFetchRequest(pathFetchRequest) as? [Path] {
                //return pathResults
                for p in pathResults {
                    let title = p.title == nil ? "<untitled>" : p.title!
                    print("Deleting cached path '\(title)'")
                    //print(p.creator)
                    moc.deleteObject(p)
                }
                
                do {
                    try moc.save()
                }
                catch {
                    return
                }
            }
        }
        catch let error as NSError {
            print("Could not fetch Paths \(error), \(error.userInfo)")
        }
        
    }
  
    class func FetchPathsWithStateInContext(moc: NSManagedObjectContext, state: PathState) -> [Path] {
        let pathFetchRequest = NSFetchRequest(entityName: "Path")
        pathFetchRequest.predicate = NSPredicate(format: "state == %@", argumentArray: [state.rawValue])
        do {
            if let pathResults = try moc.executeFetchRequest(pathFetchRequest) as? [Path] {
                return pathResults
            }
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
    
    
    class func FetchPathWithRemoteIDInContext(moc: NSManagedObjectContext, remoteID: String) -> Path? {
        let pathFetchRequest = NSFetchRequest(entityName: "Path")
        pathFetchRequest.predicate = NSPredicate(format: "remoteID == %@", argumentArray: [remoteID])
        do {
            let pathResults = try moc.executeFetchRequest(pathFetchRequest) as! [Path]
            return pathResults.count > 0 ? pathResults[0] : nil
        }
        catch let error as NSError {
            print("Could not fetch Paths \(error), \(error.userInfo)")
        }
        
        return nil
    }
    
    
    // MARK: - Instance methods
    func updateWithMetadata(metadata: PathMetadata) {
        // Update this object's properties with the non-nil entries in the provided PathMetadata struct
        if metadata.created != nil { self.created = metadata.created }
        if metadata.remoteID != nil { self.remoteID = metadata.remoteID }
        if metadata.title != nil { self.title = metadata.title }
        if metadata.notes != nil { self.notes = metadata.notes }
        if metadata.totalTime != nil { self.totalTime = metadata.totalTime }
        if metadata.totalDistance != nil { self.totalDistance = metadata.totalDistance }
        if metadata.averageSpeed != nil { self.averageSpeed = metadata.averageSpeed }
        if metadata.type != nil { self.type = metadata.type?.rawValue }
        if metadata.state != nil { self.state = metadata.state?.rawValue }
        if metadata.vessel != nil { self.vessel = metadata.vessel }
        if metadata.sailor != nil { self.creator = metadata.sailor }
    }
    
    func getMetadata() -> PathMetadata {
        let type = self.type == nil ? nil : PathType(rawValue: self.type!)
        let state = self.state == nil ? nil : PathState(rawValue: self.state!)
        return PathMetadata(created: self.created, remoteID: self.remoteID, title: self.title, notes: self.notes, totalTime: self.totalTime, totalDistance: self.totalDistance, averageSpeed: self.averageSpeed, type: type, state: state, vessel: self.vessel, sailor: self.creator)
    }
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
