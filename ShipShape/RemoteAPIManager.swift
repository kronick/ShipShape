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

class RemoteAPIManager : NSObject {
    static let sharedInstance = RemoteAPIManager()
    
    // Retreive the managedObjectContext from AppDelegate
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    
    let apiBase = "https://u26f5.net/api/v0.1/"
    
    // TODO: Integrate this with registration/login flow - Should ask for credentials (again) if a auth fails
    var username = "Sam"
    var password = "testingthis"
    
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
        
        if isnan(payload["averageSpeed"] as! Double) { payload["averageSpeed"] = 0 }
        
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
                            print("Successfully posted path '\(title)' -> remote ID '\(path.remoteID!)'")
                            
                            self.appDelegate.saveContext()
                        }
                    }
                    
                 }
    }
    func addPointsToPath(path: Path, points: [Point]) {
        
    }
    func syncPath(path: Path) {
        
    }
    
}