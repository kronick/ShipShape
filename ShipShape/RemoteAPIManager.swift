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

class RemoteAPIManager : NSObject {
    static let sharedInstance = RemoteAPIManager()
    
    let APIBase = "http://u26f5.net/api/v0.1/"
    
    // TODO: Integrate this with registration/login flow - Should ask for credentials (again) if a auth fails
    let username = "Sam"
    let password = "testingthis"
    
    private override init() {
        super.init()
    }
    
    func createPath(path: Path) {
        
    }
    func addPointsToPath(path: Path, points: [Point]) {
        
    }
    func syncPath(path: Path) {
        
    }
}