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


private var KVOContext = 0

class MainMapViewController: UIViewController, CLLocationManagerDelegate, MapCalloutDelegate {
    
    // Retreive the managedObjectContext from AppDelegate
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    
    @IBOutlet var mapView: MGLMapView!
    var line: MGLPolyline?
    
    var mapManager: MapManager?
    var trackingState = LocationTrackerState.Stopped
    var recentTrack: Path?
    var calloutTrack: Path?
    
    var firstShowing = true
    
    @IBOutlet weak var startNewTrackButton: UIButton!
    @IBOutlet weak var followUserButton: UIButton!
    @IBOutlet weak var anchorButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var statsButton: UIButton!
    @IBOutlet weak var hamburgerButton: UIButton!
    @IBOutlet weak var statsLabel: UILabel!
    
    
    @IBOutlet weak var calloutView: UIView!
    @IBOutlet weak var calloutViewTitle: UILabel!
    @IBOutlet weak var calloutViewStats: UILabel!
    @IBOutlet weak var calloutViewDetailButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        mapView.attributionButton.hidden = true
        
        mapView.setUserTrackingMode(MGLUserTrackingMode.Follow, animated: true)
        self.mapManager = MapManager(mapView: self.mapView)
        self.mapManager?.calloutDelegate = self
        
        self.mapManager?.addObserver(self, forKeyPath: "userTrackingMode", options: .New, context: &KVOContext)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(receiveTrackingStateNotification), name: "shipShape.locationTrackerStateChange", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(updateRecordingLocations), name: "shipShape.locationTrackerUpdate", object: nil)
//        
//        let defaultPath = Path.CreateFromGeoJSONInContext(self.managedObjectContext, filename: "sail") {
//            self.mapManager?.updateAllPaths()
//        }
//        self.mapManager?.addAnnotationForPath(defaultPath)
//      
        // Make sure we can move the callout view around even though autolayout is enabled
        self.calloutView.translatesAutoresizingMaskIntoConstraints = true
        for v in self.calloutView.subviews {
            v.translatesAutoresizingMaskIntoConstraints = true
        }
        
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.changeTrackingState(LocationTrackerManager.sharedInstance.trackerState)
        
        self.mapManager?.clearAnnotations()
        let allPaths = Path.FetchPathsForSailorInContext(self.managedObjectContext, sailor: Sailor.ActiveSailor!)
        for p in allPaths {
            self.mapManager?.addAnnotationForPath(p)
            //p.remoteID = nil
        }
        appDelegate.saveContext()
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if self.firstShowing && Sailor.ActiveSailor?.username == "anonymous" {
            self.performSegueWithIdentifier("ShowRegistration", sender: self)
            self.firstShowing = false
        }
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &KVOContext {
            if keyPath == "userTrackingMode" {
                switch(mapView.userTrackingMode) {
                case .None:
                    self.followUserButton.selected = false
                case .Follow, .FollowWithCourse, .FollowWithHeading:
                    self.followUserButton.selected = true
                }
            }
        }
    }
    
    // TODO: Receive LocationUpdate notifications 
    // self.mapManager?.updateAnnotationForPath(self.activePath!)
    // Also, call changeTrackingState in response to LocationTrackerStateChange notificatons
    
    
    func updateRecordingLocations(notification: NSNotification) {
       self.mapManager?.updateAnnotationForPath(LocationTrackerManager.sharedInstance.activePath!)
    }
    
    func receiveTrackingStateNotification(notification: NSNotification) {
        guard let newStateValue = notification.userInfo?["newState"] as? String else {
            print("Bad state change received from NSNotification")
            return
        }
        guard let newState = LocationTrackerState(rawValue: newStateValue) else {
            print("Bad state change received from NSNotification")
            return
        }
        
        self.changeTrackingState(newState)

    }
    func changeTrackingState(newState: LocationTrackerState) {
        let oldState = self.trackingState
        
        if newState == oldState {
            return
        }
        
        if oldState == .Stopped && newState == .Recording {
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
            
        }
        else if oldState == .Recording && newState == .Stopped {
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
            
        }
        
        self.trackingState = newState
    }
    
    // MARK: - MapCaloutDelegate
    func showCalloutForPath(path: Path, atPoint: CGPoint, inMapView: UIView) {
        
        // Set up labels
        self.calloutViewTitle.text = path.title == nil ? "Untitled Track" : path.title!
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateStyle = .MediumStyle
        dateFormatter.timeStyle = .ShortStyle
        self.calloutViewStats.text = path.created == nil ? "!!!" : dateFormatter.stringFromDate(path.created!)

        self.calloutTrack = path // Used when the info button segue is triggered
        
        // Set the view's frame
        let anchor = self.view.convertPoint(atPoint, fromView: inMapView)
        var x = anchor.x - self.calloutView.frame.width/2
        var y = anchor.y - self.calloutView.frame.height - 10
        var w = self.calloutView.frame.width
        var h = self.calloutView.frame.height
        var margin = 5.0 as CGFloat
        // Keep it in bounds
        if x < margin { x = margin }
        if x + w > self.view.frame.width - margin { x = self.view.frame.width - margin - w }
        if y < margin { y = margin }
        if y + h > self.view.frame.height - margin { y = self.view.frame.height - margin - h }
        self.calloutView.frame = CGRect(x: x, y: y, width: w, height: h)
    
        // Show the view

        self.calloutView.hidden = false
        self.calloutView.transform = CGAffineTransformMakeScale(0.1, 0.1)
        UIView.animateWithDuration(0.3, animations: {
            self.calloutView.transform = CGAffineTransformMakeScale(1, 1)
            //self.calloutView.layer.transform = CATransform3DMakeScale(1.0, 1.0, 1.0)
            self.calloutView.alpha = 1
            self.calloutViewStats.sizeToFit()
            }, completion: { finished in
                return
        })
    }
    func dismissCallout() {
        self.calloutView.transform = CGAffineTransformMakeScale(1, 1)
        UIView.animateWithDuration(0.3, animations: {
            self.calloutView.transform = CGAffineTransformMakeScale(0.1, 0.1)
            //self.calloutView.layer.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
            self.calloutView.alpha = 0
            }, completion: { finished in
//                self.calloutView.hidden = true
                self.calloutView.transform = CGAffineTransformMakeScale(1, 1)
                self.calloutTrack = nil
        })
    }
    
    
    // MARK: - Interface actions
    
    @IBAction func unwindToMap(segue: UIStoryboardSegue) {
        
    }
    @IBAction func startRecordingNewTrack(sender: AnyObject? = nil) {
        LocationTrackerManager.sharedInstance.changeState(.Recording)
        self.recentTrack = LocationTrackerManager.sharedInstance.activePath
    }
    
    @IBAction func stopRecordingTrack(sender: AnyObject? = nil) {
        LocationTrackerManager.sharedInstance.changeState(.Stopped)
        
        // Show track detail after track is over to save or quit
        self.performSegueWithIdentifier("ShowTrackDetail", sender: self)
        self.recentTrack = nil
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        switch segue.identifier {
        case "ShowTrackDetail"?:
            if let destination = segue.destinationViewController as? TrackDetailViewController {
                destination.hideNavBar = false
                if sender as? UIButton == self.calloutViewDetailButton {
                    // This is an old track selected from the map
                    destination.editMode = .SavedTrack
                    destination.activePath = self.calloutTrack!
                }
                else {
                    // This is a new track and the detail is automatically presented by the stop recording button
                    destination.activePath = self.recentTrack
                    destination.editMode = .NewTrack
                }
            }
        default:
            return
        }
    }
    
    @IBAction func toggleStats(sender: AnyObject? = nil) {
        //self.mapManager?.updateAllPaths()
        if let activePath = LocationTrackerManager.sharedInstance.activePath {
            activePath.recalculateStats()

            let nf = NSNumberFormatter()
            nf.numberStyle = NSNumberFormatterStyle.DecimalStyle
            nf.maximumFractionDigits = 2
            
            let time = nf.stringFromNumber(activePath.totalTime! as Double / 60.0)!
            let distance = nf.stringFromNumber(metersToNauticalMiles(activePath.totalDistance!))!
            let speed = nf.stringFromNumber(metersPerSecondToKnots(activePath.averageSpeed!))!
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
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        self.mapManager?.removeObserver(self, forKeyPath: "userTrackingMode")
    }


}

