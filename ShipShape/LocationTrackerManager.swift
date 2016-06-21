//
//  LocationTrackerManager.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/29/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit
import CoreData

public enum LocationTrackerState: String {
    case Recording
    case Paused
    case Stopped
}

class LocationTrackerManager : NSObject, CLLocationManagerDelegate {
    
    static let sharedInstance = LocationTrackerManager()
    
    // Retreive the managedObjectContext from AppDelegate
    var appDelegate: AppDelegate!
    var managedObjectContext: NSManagedObjectContext!
    
    var locationManager = CLLocationManager()
    
    var activePath: Path?
    var trackerState = LocationTrackerState.Stopped
    
    private override init() {
        super.init()
    }
    
    func initialize() {
        self.appDelegate =  UIApplication.sharedApplication().delegate as! AppDelegate
        self.managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    
        self.locationManager.delegate = self
        self.locationManager.distanceFilter = 3
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestAlwaysAuthorization()
        
    
        if #available(iOS 9.0, *) {
            self.locationManager.allowsBackgroundLocationUpdates = true
        } else {
            // Fallback on earlier versions
        }
        self.locationManager.pausesLocationUpdatesAutomatically = false

        
        // Check if there is an open path recording in progress
        let recordingPaths = Path.FetchPathsWithStateInContext(self.managedObjectContext, state: .Recording)
        var i = 0
        for p in recordingPaths {
            if i == 0 {
                self.activePath = p
                
                self.changeState(.Recording)
            }
            else {
                // Put all but the first recording paths into a fault state-- there should never be more than 1!
                p.state = PathState.Fault.rawValue
            }
            i += 1
        }

        appDelegate.saveContext()
        
    }
    
    func changeState(newState: LocationTrackerState) {
        let oldState = self.trackerState
        
        if newState == oldState {
            return
        }
        
        if oldState == .Stopped && newState == .Recording {
            // Start a new recording
            if self.activePath == nil {
                self.activePath = Path.CreateInContext(self.managedObjectContext, title: "Active Route", state: .Recording , vessel: .ActiveVessel, creator: .ActiveSailor)
                appDelegate.saveContext()
            }
            
            self.locationManager.startUpdatingLocation()
            
        }
        else if oldState == .Recording && newState == .Stopped {
            // Stop current recording
            
            self.activePath?.state = PathState.Complete.rawValue
            
            appDelegate.saveContext()
            self.activePath = nil
            
            self.locationManager.stopUpdatingLocation()
        }
        
        self.trackerState = newState
        NSNotificationCenter.defaultCenter().postNotificationName("shipShape.locationTrackerStateChange", object: self, userInfo: ["oldState": oldState.rawValue, "newState": newState.rawValue])
        
        
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        print("didChangeAuthorizationStatus")
        
        switch status {
        case .NotDetermined:
            print(".NotDetermined")
            break
            
        case .Authorized:
            print(".Authorized")
            manager.startUpdatingLocation()
            break
        case .Denied:
            print(".Denied")
            break
        default:
            print("Unhandled authorization status")
            break
            
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Don't do anything if there is no active path recording
        if self.activePath == nil { return }
        
        // Otherwise create a new Point on the current Path
        for location in locations {
            //let location = locations.last! as CLLocation
            Point.CreateInContext(self.managedObjectContext, location: location, path: self.activePath)
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName("shipShape.locationTrackerUpdate", object: self, userInfo: ["locations": locations])
        
        self.appDelegate.saveContext()
        
        
        //self.mapManager?.updateAnnotationForPath(self.activePath!)
        
    }

}