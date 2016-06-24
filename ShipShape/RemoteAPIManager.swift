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
//  Local objects should have a globalID after the first time they are sent to the
//  server. Subsequent updates will use this globalID as a key to the remote object.
//  This should happen transparently; calls to this object only require the manage
//  object as a parameter.

import Foundation
import Alamofire

class RemoteAPIManager : NSObject {
    static let sharedInstance = RemoteAPIManager()
    
    let apiBase = "http://u26f5.net/api/v0.1/"
    
    // TODO: Integrate this with registration/login flow - Should ask for credentials (again) if a auth fails
    let username = "Sam"
    let password = "testingthis"
    
    private override init() {
        super.init()
    }
    
    func getAuthHeader() -> [String: String] {
        let credentialData = "\(self.username):\(self.password)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])
        let header = ["Authorization": "Basic \(base64Credentials)"]
        return header
    }
    func createPath(path: Path) {
        guard let points = path.points else {
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
        if let vessel_id = path.vessel?.globalID { payload["vessel_id"] = vessel_id }
        
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
            
            
        Alamofire.request(.POST, endpoint,
                          parameters: payload,
                          encoding: .JSON,
                          headers: self.getAuthHeader())
                 .responseString { response in
                    print("Success: \(response.result.isSuccess)")
                    print("Response String: \(response.result.value)")
                 }
    }
    func addPointsToPath(path: Path, points: [Point]) {
        
    }
    func syncPath(path: Path) {
        
    }
}