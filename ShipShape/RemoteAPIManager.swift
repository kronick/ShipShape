//
//  RemoteAPIManager.swift
//  ShipShape
//
//  Created by Sam Kronick on 6/24/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//
//  This singleton is used to manage uploading/downloading data from the remote REST API
//  It converts between local instances of Path, Point, Sailor, Vessel, etc objects and
//  remote objects which are transferred as JSON. 
//  
//  Local objects should have a remoteID after the first time they are sent to the
//  server. Subsequent updates will use this remoteID as a key to the remote object.
//  This should happen transparently; calls to this object only require the manage
//  object as a parameter.

import Foundation
import Alamofire
import SwiftyJSON
import CoreLocation
import CoreData

class RemoteAPIManager : NSObject {
    static let sharedInstance = RemoteAPIManager()
    
    // Retreive the managedObjectContext from AppDelegate
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let mainManagedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    
    let apiBase = "https://u26f5.net/api/v0.1/"
    
    // TODO: Integrate this with registration/login flow - Should ask for credentials (again) if a auth fails
    var username = ""
    var password = ""
    
    private override init() {
        super.init()
    }
    
    func getAuthHeader(username: String? = nil, password: String? = nil) -> [String: String] {
        let use = username == nil ? self.username : username
        let pass = password == nil ? self.password : password
        
        let credentialData = "\(use!):\(pass!)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])
        let header = ["Authorization": "Basic \(base64Credentials)"]
        return header
    }
    
    func registerSailor(username: String, email: String, password: String, callback: (success: Bool, response: JSON) -> Void) {
        let payload = ["username": username, "email": email, "password": password]
        let endpoint = self.apiBase + "sailors/"
        
        Alamofire.request(.POST, endpoint,
            parameters: payload,
            encoding: .JSON,
            headers: nil)
            .responseJSON { response in
                guard let statusCode = response.response?.statusCode else {
                    callback(success: false, response: JSON(["error": "Could not reach server!"]))
                    return
                }
                switch statusCode {
                case 200:
                    if let value = response.result.value {
                        let json = JSON(value)
                        callback(success: true, response: json)
                        return
                    }
                case 400...409:
                    if let value = response.result.value {
                        let json = JSON(value)
                        callback(success: false, response: json)
                    }
                    else {
                        callback(success: false, response: JSON(["error": "Bad request"]))
                    }
                default:
                    callback(success: false, response: JSON(["error": "Server error"]))
                }
                
            }
    }
    
    func checkAuth(username: String, password: String, callback: (success: Bool, response: JSON) -> Void) {
        
        let endpoint = self.apiBase + "checkauth/"
        
        Alamofire.request(.GET, endpoint,
            headers: self.getAuthHeader(username, password: password))
            .responseJSON { response in
                guard let statusCode = response.response?.statusCode else {
                    callback(success: false, response: JSON(["error": "Could not reach server!"]))
                    return
                }
                switch statusCode {
                case 200:
                    if let value = response.result.value {
                        let json = JSON(value)
                        callback(success: true, response: json)
                        return
                    }
                case 400...409:
                    if let value = response.result.value {
                        let json = JSON(value)
                        callback(success: false, response: json)
                    }
                    else {
                        callback(success: false, response: JSON(["error": "Bad request"]))
                    }
                default:
                    callback(success: false, response: JSON(["error": "Server error"]))
                }
                
        }
    }
    
    func createPath(path: Path) {
        guard let points = path.points else {
            print("Can't create path on remote server if it has no points!")
            return
        }
        
        if points.count == 0 {
            print("Can't create path on remote server if it has no points!")
            return
        }
        
        NSLog("Creating path payload...")
        
        let endpoint = self.apiBase + "paths/"
        
        // Move properties form the Path object into a dict so it can be serialized as JSON
        // This is ugly but it unwraps all the optionals and only includes keys that have values
        // TODO: Find out if there is a better way to do this and clean it up
        var payload: [String: AnyObject] = [:]
        if let title = path.title { payload["title"] = title }
        if let created = path.created { payload["created"] = created.timeIntervalSince1970 }
        if let notes = path.notes { payload["notes"] = notes }
        if let totalTime = path.totalTime { payload["totalTime"] = totalTime }
        if let totalDistance = path.totalDistance { payload["totalDistance"] = totalDistance }
        if let averageSpeed = path.averageSpeed { payload["averageSpeed"] = averageSpeed }
        if let type = path.type { payload["type"] = type }
        if let state = path.state { payload["state"] = state }
        if let vessel = path.vessel?.name { payload["vessel"] = vessel }
        if let vessel_id = path.vessel?.remoteID { payload["vessel_id"] = vessel_id }
        
        if payload["averageSpeed"] == nil || isnan(payload["averageSpeed"] as! Double) { payload["averageSpeed"] = 0 }
        
        var pointsArray = [[String: AnyObject]]()
   
        for point in points {
            guard let p = point as? Point else { continue }
            var pointDict: [String : AnyObject] = [:]
            if let latitude = p.latitude { pointDict["latitude"] = latitude }
            if let longitude = p.longitude { pointDict["longitude"] = longitude }
            if let propulsion = p.propulsion { pointDict["propulsion"] = propulsion }
            if let created = p.created { pointDict["created"] = created.timeIntervalSince1970 }
            if let notes = p.notes { pointDict["notes"] = notes }
           
            pointsArray.append(pointDict)
        }
        
        payload["points"] = pointsArray
            
        if let remoteID = path.remoteID {
            let title = path.title == nil ? "(unknown)" : path.title!
            print("Path '\(title)' already has a remoteID: \(remoteID)")
        }
        NSLog("Sending request...")
        Alamofire.request(.POST, endpoint,
                          parameters: payload,
                          encoding: .JSON,
                          headers: self.getAuthHeader())
                 .validate()
                 .responseJSON { response in
                    guard response.result.error == nil else {
                        // Handle error
                        print("Error uploading path: \(response.result.error!)")
                        return
                    }
                    
                    if let value = response.result.value {
                        let json = JSON(value)
                        
                        // Update local CoreData objects back on the main thread
                        dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                            path.remoteID = json["path_id"].string
                            let title = path.title == nil ? "(unknown)" : path.title!
                            NSLog("Successfully posted path '\(title)' -> remote ID '\(path.remoteID!)'")
                            
                            self.appDelegate.saveContext()
                        }
                    }
                    
                 }
    }
    func addPointsToPath(path: Path, points: [Point]) {
        
    }
    func syncPath(path: Path) {
        
    }
    
    func getPathByID(remoteID: String, includePoints: Bool = true, completion: (pathID: NSManagedObjectID?) -> Void) {
        let modifier = includePoints ? "" : "metadata"
        let endpoint = self.apiBase + "paths/" + remoteID + "/" + modifier
        
        print("getPathByID: Downloading path \(remoteID)")
        
        Alamofire.request(.GET, endpoint,
                          headers: self.getAuthHeader())
            .responseJSON(queue: dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), completionHandler: { response in
                guard response.result.error == nil else {
                    print("getPathByID: Error downloading path: \(response.result.error!)")
                    completion(pathID: nil)
                    return
                }
                guard let value = response.result.value else {
                    print("getPathByID: No response.")
                    completion(pathID: nil)
                    return
                }
                
                let path = JSON(value)
                
                
                // Create temporary CoreData ManagedObjectContext to save these results
                // Set the parent to the main MOC so the results can be merged in on the main thread
                let moc = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
                moc.parentContext = self.mainManagedObjectContext
                moc.performBlockAndWait {   // Do all this work in the proper queue for this MOC
                    let title = path["title"].string
                    print("getPathByID: Downloaded '\(title)'")
                    // Parse the JSON for this path's metadata and get it ready to store as a managed object
                    let created = NSDate.init(timeIntervalSince1970: path["created"].doubleValue)
                    let id = path["_id"].stringValue
                    let notes = path["notes"].string
                    let totalTime = path["totalTime"].double
                    let totalDistance = path["totalDistance"].double
                    let averageSpeed = path["averageSpeed"].double
                    let type = PathType(rawValue: path["type"].stringValue)
                    let state = PathState(rawValue: path["state"].stringValue)
                    // TODO: Get vessel and sailor, download if needed
                    let vessel: Vessel? = nil
                    var sailor: Sailor? = nil
                    
                    let creator = path["creator"]["username"].string
                    print(creator)
                    if creator != nil && creator != "" {
                        sailor = Sailor.FetchByUsernameInContext(moc, username: creator!)
                    }
                    
                    // Create the managed object
                    let newPath = Path.CreateInContext(moc, title: title, created: created, remoteID: id, notes: notes, totalTime: totalTime, totalDistance: totalDistance, averageSpeed: averageSpeed, type: type, state: state, vessel: vessel, creator: sailor, points: nil)
                    
                    // Now process the points and add them to this path
                    let pointsArray = path["points"].arrayValue
                    for p in pointsArray {
                        let latitude = p["latitude"].doubleValue
                        let longitude = p["longitude"].doubleValue
                        let pointCreation = NSDate.init(timeIntervalSince1970: p["created"].doubleValue)
                        let propulsion = PropulsionMethod(rawValue: p["propulsion"].stringValue)
                        let notes = p["notes"].string
                        
                        // Create the point in the temporary managed object context
                        Point.CreateInContext(moc, latitude: latitude, longitude: longitude, timestamp: pointCreation, propulsion: propulsion, remoteID: nil, notes: notes, path: newPath)
                    }
                    
                    do {
                        try moc.save()
                        // Call the completion callback with the created object ID
                        completion(pathID: newPath.objectID)
                    }
                    catch {
                        print("getPathByID: Error saving temporary managed object context.")
                        completion(pathID: nil)
                        return
                    }
                }
            }
        )
    }
    
    func getPathsInBounds(a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ c: CLLocationCoordinate2D, _ d: CLLocationCoordinate2D, completion: (pathIDs: [NSManagedObjectID]) -> Void) {
        
        let endpoint = self.apiBase + "paths/in/\(a.longitude),\(a.latitude),\(b.longitude),\(b.latitude),\(c.longitude),\(c.latitude),\(d.longitude),\(d.latitude)"
        
        NSLog("Sending request to \(endpoint)...")
        Alamofire.request(.GET, endpoint,
            headers: self.getAuthHeader())
            .validate()
            .responseJSON(queue: dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), completionHandler: { response in
                guard response.result.error == nil else {
                    // Handle error
                    print("getPathsInBounds: Error getting paths: \(response.result.error!)")
                    completion(pathIDs: [])
                    return
                }
                
                guard let value = response.result.value else {
                    print("getPathsInBounds: No response.")
                    completion(pathIDs: [])
                    return
                }
                // Create temporary CoreData ManagedObjectContext to save these results
                // Set the parent to the main MOC so the results can be merged in on the main thread
                let moc = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
                moc.parentContext = self.mainManagedObjectContext
                moc.performBlockAndWait {   // Do all this work in the proper queue for this MOC
                    let json = JSON(value)
                    let paths = json["paths"].arrayValue
                    
                    var pathIDs = [NSManagedObjectID]()
                    
                    // Create a dispatch group so we can download any paths asynchronously but wait for them all before calling the completion handler
                    let pathDownloadGroup = dispatch_group_create()
                    
                    print("getPathsInBounds: Found these paths in range:")
                    for p in paths {
                        print(p["title"].stringValue + " (" + p["_id"].stringValue + ")")
                        
                        // For each path, see if it already exists in the local store
                        let remoteID = p["_id"].stringValue
                        if let localPath = Path.FetchPathWithRemoteIDInContext(moc, remoteID: remoteID) {
                            // This Path already exists locally
                            // TODO: Update/sync metadata
                            // Add this path's objectID to the array
                            pathIDs.append(localPath.objectID)
                        }
                        else {
                            // A path with this remoteID does not exist. Download it
                            dispatch_group_enter(pathDownloadGroup)
                            self.getPathByID(remoteID, completion: { objectID in
                                // Put the downloaded path's local CoreData objectID into the list
                                if let id = objectID {
                                    pathIDs.append(id)
                                }
                                dispatch_group_leave(pathDownloadGroup)
                            })
                        }
                    }
                    
                    // Wait for all paths to finish downloading
                    //dispatch_group_wait(pathDownloadGroup, DISPATCH_TIME_FOREVER)
                    dispatch_group_notify(pathDownloadGroup, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
                        // Now call the completion callback with the objectIDs of all the paths
                        completion(pathIDs: pathIDs)
                    })
                    
                    
                }
            
            }
        )
    }
    
}