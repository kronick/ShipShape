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
    let backgroundManagedObjectContext: NSManagedObjectContext!
    
    let apiBase = "https://u26f5.net/api/v0.1/"
    
    // TODO: Integrate this with registration/login flow - Should ask for credentials (again) if a auth fails
    var username = ""
    var password = ""
    
    // Used to invalidate old asynchronous requests if a newer one has been requested in the meantime
    var lastPathInBoundsRequest: NSDate?
    var activePathDownloads = [String]()    // Used to avoid downloading two of the same track at the same time
    
    private override init() {
        self.backgroundManagedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        super.init()
        self.backgroundManagedObjectContext.parentContext = self.mainManagedObjectContext
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
    
    func startPathDownloadWithID(remoteID: String) -> Bool{
        if self.activePathDownloads.contains(remoteID) {
            return false
        }
        else {
            self.activePathDownloads.append(remoteID)
            return true
        }
    }
    func finishPathDownloadWithID(remoteID: String) {
        self.activePathDownloads = self.activePathDownloads.filter { $0 != remoteID }
    }
    
    func getPathByID(remoteID: String, includePoints: Bool = true, completion: (pathID: NSManagedObjectID?) -> Void) {
        let modifier = includePoints ? "" : "metadata"
        let endpoint = self.apiBase + "paths/" + remoteID + "/" + modifier
        
        guard self.startPathDownloadWithID(remoteID) else {
            print("getPathByID: This path is already being downloaded: \(remoteID)")
            completion(pathID: nil)
            return
        }
        
        NSLog("getPathByID: Downloading path \(remoteID)")
        
        Alamofire.request(.GET, endpoint,
                          headers: self.getAuthHeader())
            //.responseJSON(queue: dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), completionHandler: { response in
        .responseJSON { response in
                guard response.result.error == nil else {
                    print("getPathByID: Error downloading path: \(response.result.error!)")
                    self.finishPathDownloadWithID(remoteID)
                    completion(pathID: nil)
                    return
                }
                guard let value = response.result.value else {
                    print("getPathByID: No response.")
                    self.finishPathDownloadWithID(remoteID)
                    completion(pathID: nil)
                    return
                }
                
                let path = JSON(value)
                
                
                // Do this in a background thread
                self.backgroundManagedObjectContext.performBlock {   // Do all this work in the proper queue for this MOC
                    let metadata = self.parsePathJSON(path, moc: self.backgroundManagedObjectContext)
                    
                    NSLog("getPathByID: Downloaded '\(metadata.title)' (\(metadata.remoteID))")
                    
                    // Create the managed object
                    let newPath = Path.CreateFromMetadataInContext(self.backgroundManagedObjectContext, metadata: metadata)
                    
                    // Now process the points and add them to this path
                    let pointsArray = path["points"].arrayValue
                    for p in pointsArray {
                        let latitude = p["latitude"].doubleValue
                        let longitude = p["longitude"].doubleValue
                        let pointCreation = NSDate.init(timeIntervalSince1970: p["created"].doubleValue)
                        let propulsion = PropulsionMethod(rawValue: p["propulsion"].stringValue)
                        let notes = p["notes"].string
                        
                        // Create the point in the temporary managed object context
                        Point.CreateInContext(self.backgroundManagedObjectContext, latitude: latitude, longitude: longitude, timestamp: pointCreation, propulsion: propulsion, remoteID: nil, notes: notes, path: newPath)
                    }
                    
                    do {
                        try self.backgroundManagedObjectContext.save()
                        // Call the completion callback with the created object ID
                        self.finishPathDownloadWithID(remoteID)
                        completion(pathID: newPath.objectID)
                    }
                    catch {
                        print("getPathByID: Error saving temporary managed object context.")
                        self.finishPathDownloadWithID(remoteID)
                        completion(pathID: nil)
                        return
                    }
                }
            }
        //)
    }
    
    func getPathsInBounds(a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ c: CLLocationCoordinate2D, _ d: CLLocationCoordinate2D, afterEach: (pathID: NSManagedObjectID) -> Void, completion: (pathIDs: [NSManagedObjectID]) -> Void) {
        // Update timestamp on most recent request so this one stays fresh until another one comes along
        let requestTime = NSDate.init()
        self.lastPathInBoundsRequest = requestTime
        
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
                
                guard self.lastPathInBoundsRequest == requestTime else {
                    print("getPathsInBounds: Old request-- too slow! Not even going to check on these paths.")
                    return
                }
                
                // Don't block the main thread-- do this in the background Managed Object Context
                self.backgroundManagedObjectContext.performBlock {   // Do all this work in the proper queue for this MOC
                    // Check again once this is actually running
                    guard self.lastPathInBoundsRequest == requestTime else {
                        print("getPathsInBounds: Old request-- too slow! Not even going to check on these paths.")
                        return
                    }
                    
                    let json = JSON(value)
                    let paths = json["paths"].arrayValue
                    
                    var pathIDs = [NSManagedObjectID]()
                    
                    // Create a dispatch group so we can download any paths asynchronously but wait for them all before calling the completion handler
                    let pathDownloadGroup = dispatch_group_create()
                    
                    print("getPathsInBounds: Found these paths in range:")
                    for p in paths {
                        let metadata = self.parsePathJSON(p, moc: self.backgroundManagedObjectContext)
                        if let title = metadata.title, id = metadata.remoteID {
                            print("> \(title) (\(id))")
                        }
                        
                        // For each path, see if it already exists in the local store
                        guard let remoteID = metadata.remoteID else { continue }
                        if let localPath = Path.FetchPathWithRemoteIDInContext(self.backgroundManagedObjectContext, remoteID: remoteID) {
                            // This Path already exists locally
                            // So just update its metadata
                            localPath.updateWithMetadata(metadata)
                            do {
                                try self.backgroundManagedObjectContext.save()
                            }
                            catch {
                                NSLog("getPathsInBounds: Uunable to save background context!")
                            }
                            // And add this path's objectID to the array
                            pathIDs.append(localPath.objectID)
                            afterEach(pathID: localPath.objectID)
                        }
                        else {
                            // A path with this remoteID does not exist. Download it
                            dispatch_group_enter(pathDownloadGroup)
                            self.getPathByID(remoteID, completion: { objectID in
                                // Put the downloaded path's local CoreData objectID into the list
                                guard let id = objectID else { return }
                                pathIDs.append(id)
                                afterEach(pathID: id)
                            
                                dispatch_group_leave(pathDownloadGroup)
                            })
                        }
                    }
                    
                    // Wait for all paths to finish downloading
                    //dispatch_group_wait(pathDownloadGroup, DISPATCH_TIME_FOREVER)
                    dispatch_group_notify(pathDownloadGroup, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
                        // Now call the completion callback with the objectIDs of all the paths
                        guard self.lastPathInBoundsRequest == requestTime else {
                            print("getPathsInBounds: Old request-- too slow!")
                            return
                        }
                        
                        completion(pathIDs: pathIDs)
                    })
                    
                    
                }
            
            }
        )
    }
    
    // MARK: - JSON -> Managed Object parsing
    func parsePathJSON(json: JSON, moc: NSManagedObjectContext) -> PathMetadata {
        // Parse the JSON for this path's metadata an return a dictionary with guaranteed-good values
        var metadata = PathMetadata()
        metadata.title = json["title"].string
        metadata.created = NSDate.init(timeIntervalSince1970: json["created"].doubleValue)
        metadata.remoteID = json["_id"].stringValue
        metadata.notes = json["notes"].string
        metadata.totalTime = json["totalTime"].double
        metadata.totalDistance = json["totalDistance"].double
        metadata.averageSpeed = json["averageSpeed"].double
        metadata.type = PathType(rawValue: json["type"].stringValue)
        metadata.state = PathState(rawValue: json["state"].stringValue)
        // TODO: Get vessel and sailor, download if needed
        metadata.vessel = nil
        metadata.sailor = nil
        
        let creator = json["creator"]["username"].string
        if creator != nil && creator != "" {
            metadata.sailor = Sailor.FetchByUsernameInContext(moc, username: creator!)
        }
        
        return metadata
    }
    
}