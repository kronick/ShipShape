//
//  ViewController.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/21/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import UIKit
import Mapbox
import CoreData
import CoreLocation



public enum TrackingState: String {
    case Recording
    case Anchored
    case Stopped
}

class ViewController: UIViewController, MGLMapViewDelegate, CLLocationManagerDelegate {
    
    // Retreive the managedObjectContext from AppDelegate
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    
    @IBOutlet var mapView: MGLMapView!
    var line: MGLPolyline?

    var activePath: Path?
    
    var locationManager: CLLocationManager = CLLocationManager()
    
    var trackingState = TrackingState.Stopped
    
    @IBOutlet weak var startNewTrackButton: UIButton!
    @IBOutlet weak var followUserButton: UIButton!
    @IBOutlet weak var anchorButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var statsButton: UIButton!
    @IBOutlet weak var hamburgerButton: UIButton!
    @IBOutlet weak var statsLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        mapView.attributionButton.hidden = true
        
        mapView.setUserTrackingMode(MGLUserTrackingMode.Follow, animated: true)
        
        AnnotationManager.SharedInstance.mapView = self.mapView
        
        
        //let defaultPath = Path.CreateFromGeoJSONInContext(self.managedObjectContext, filename: "sail") {
        //    AnnotationManager.SharedInstance.updateAllPaths()
        //}
        //AnnotationManager.SharedInstance.addAnnotationForPath(defaultPath)
        
        
        // Check if there is an open path recording in progress
        let recordingPaths = Path.FetchPathsWithStateInContext(self.managedObjectContext, state: .Recording)
        var i = 0
        for p in recordingPaths {
            if i == 0 {
                self.activePath = p
                AnnotationManager.SharedInstance.addAnnotationForPath(self.activePath!)
                if let annotation = AnnotationManager.SharedInstance.pathAnnotations[self.activePath!] {
                    //self.mapView.showAnnotations([annotation], animated: true)
                }
                
                self.changeTrackingState(.Recording)
            }
            else {
                // Put all but the first recording paths into a fault state-- there should never be more than 1!
                p.state = PathState.Fault.rawValue
            }
            i += 1
        }
        
        let allPaths = Path.FetchPathsForSailorInContext(self.managedObjectContext, sailor: Sailor.ActiveSailor!)
        for p in allPaths {
            AnnotationManager.SharedInstance.addAnnotationForPath(p)
        }
        
        appDelegate.saveContext()
        
        // For now, automatically open up a new path recording if there isn't a preexisting one
        if recordingPaths.count == 0 {
            startRecordingNewTrack()
        }
        
        self.locationManager.delegate = self
        self.locationManager.distanceFilter = 3
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.pausesLocationUpdatesAutomatically = false
    }

    func mapView(mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        // Always try to show a callout when an annotation is tapped.
        return true
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
        
        self.appDelegate.saveContext()

        
        AnnotationManager.SharedInstance.updateAnnotationForPath(self.activePath!)
        
    }
    
    
    // MARK: - MGLMapViewDelegate
    func mapView(mapView: MGLMapView, alphaForShapeAnnotation annotation: MGLShape) -> CGFloat {
        return 1
    }
    func mapView(mapView: MGLMapView, lineWidthForPolylineAnnotation annotation: MGLPolyline) -> CGFloat {
        return 5.0
    }
    func mapView(mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        if(annotation.title == "A polyline" && annotation is MGLPolyline) {
            return UIColor(red: 0.94, green: 0.30, blue: 0.30, alpha: 1)
        }
        else {
            return UIColor.blueColor()
        }
    }
    
    func mapView(mapView: MGLMapView, didChangeUserTrackingMode mode: MGLUserTrackingMode, animated: Bool) {
        switch(mode) {
        case .None:
            self.followUserButton.selected = false
        case .Follow, .FollowWithCourse, .FollowWithHeading:
            self.followUserButton.selected = true
        }
    }
    
    func mapView(mapView: MGLMapView, didSelectAnnotation annotation: MGLAnnotation) {
        
    }
    func mapView(mapView: MGLMapView, tapOnCalloutForAnnotation annotation: MGLAnnotation) {
        
    }
    
    // MARK: - Interface actions
    @IBAction func unwindToMap(segue: UIStoryboardSegue) {
        
    }
    
    func changeTrackingState(newState: TrackingState) {
        if newState == self.trackingState {
            return
        }
        
        if self.trackingState == .Stopped && newState == .Recording {
            // Hide + button, show recording buttons
            self.anchorButton.alpha = 0
            self.stopButton.alpha = 0
            self.statsButton.alpha = 0
            UIView.animateWithDuration(0.5, animations: {
                self.startNewTrackButton.alpha = 0

                self.anchorButton.hidden = false
                self.stopButton.hidden = false
                self.statsButton.hidden = false

            }, completion: { (b) -> Void in
                UIView.animateWithDuration(0.5, animations: {
                    self.startNewTrackButton.hidden = true
                    
                    self.anchorButton.alpha = 1
                    self.stopButton.alpha = 1
                    self.statsButton.alpha = 1

                })
            })
            
            self.locationManager.startUpdatingLocation()
        }
        else if self.trackingState == .Recording && newState == .Stopped {
            // Hide recording buttons, show stop button
            self.startNewTrackButton.alpha = 0
            UIView.animateWithDuration(0.5, animations: {
                    self.anchorButton.alpha = 0
                    self.stopButton.alpha = 0
                    self.statsButton.alpha = 0
                
                    self.startNewTrackButton.hidden = false
                }, completion: { (b) -> Void in
                    UIView.animateWithDuration(0.5, animations: {
                        self.startNewTrackButton.alpha = 1
                        
                        self.anchorButton.hidden = true
                        self.stopButton.hidden = true
                        self.statsButton.hidden = true
                        
                        
                    })
            })
            
            self.locationManager.stopUpdatingLocation()
        }
        
        self.trackingState = newState
    }
    
    @IBAction func startRecordingNewTrack(sender: AnyObject? = nil) {
        self.changeTrackingState(.Recording)
        self.activePath = Path.CreateInContext(self.managedObjectContext, title: "Active Route", state: .Recording , vessel: .ActiveVessel, creator: .ActiveSailor)
        appDelegate.saveContext()
        
        AnnotationManager.SharedInstance.addAnnotationForPath(self.activePath!)
        
    }
    
    @IBAction func stopRecordingTrack(sender: AnyObject? = nil) {
        self.changeTrackingState(.Stopped)
        self.activePath?.state = PathState.Complete.rawValue
        //AnnotationManager.SharedInstance.removeAnnotationForPath(self.activePath!)
        mapView.showAnnotations([AnnotationManager.SharedInstance.pathAnnotations[self.activePath!]!], animated: true)
        
        appDelegate.saveContext()
        self.activePath = nil
        
    }
    
    @IBAction func toggleStats(sender: AnyObject? = nil) {
        AnnotationManager.SharedInstance.updateAllPaths()
        self.activePath?.recalculateStats()
        print("Total Time: \(self.activePath?.totalTime)")
        print("Total Distance: \(self.activePath?.totalDistance)")
        print("Average Speed: \(self.activePath?.averageSpeed)")
        print("Points: \(self.activePath?.points?.count)")
        
        if self.activePath != nil {
            
            let nf = NSNumberFormatter()
            nf.numberStyle = NSNumberFormatterStyle.DecimalStyle
            nf.maximumFractionDigits = 2
            
            let time = nf.stringFromNumber(self.activePath!.totalTime! as Double / 60.0)!
            let distance = nf.stringFromNumber(metersToNauticalMiles(self.activePath!.totalDistance!))!
            let speed = nf.stringFromNumber(metersPerSecondToKnots(self.activePath!.averageSpeed!))!
            self.statsLabel.text = "\(time) min\n\(distance) NM\n \(speed) kts"
        }
    }
    
    @IBAction func toggleFollowUser(sender: AnyObject? = nil) {
        switch(mapView.userTrackingMode) {
        case .None:
            mapView.setUserTrackingMode(MGLUserTrackingMode.Follow, animated: true)
            self.followUserButton.selected = true
        case .Follow, .FollowWithCourse, .FollowWithHeading:
            mapView.setUserTrackingMode(MGLUserTrackingMode.None, animated: true)
            self.followUserButton.selected = false
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

