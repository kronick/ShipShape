//
//  TrackDetailViewController.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/27/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import UIKit
import Mapbox
import CoreData
import CoreLocation


private var KVOContext = 0

class TrackDetailViewController: UIViewController {
    
    // Retreive the managedObjectContext from AppDelegate
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    
    @IBOutlet var mapView: MGLMapView!
    var mapManager: MapManager?
    
    @IBOutlet weak var pathTitleField: UITextField!
    var activePath: Path?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        mapView.attributionButton.hidden = true
        mapView.logoView.hidden = true
        
        mapView.setUserTrackingMode(MGLUserTrackingMode.Follow, animated: true)
        self.mapManager = MapManager(mapView: self.mapView)
        
        // TODO: Don't do this here
        // Upload path upon viewing
        if let path = self.activePath {
            RemoteAPIManager.sharedInstance.createPath(path)
        }
        
        if let t = self.activePath?.title {
            self.title = t
            self.pathTitleField.text = t
        }
        else {
            self.title = "Untitled Track"
            self.pathTitleField.text = "Untitled Track"
        }
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.mapManager?.clearAnnotations()
        if let p = self.activePath {
            self.mapManager?.addAnnotationForPath(p)
            self.mapManager?.showPaths([p], animated: false)
        }
    }

    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        if let p = self.activePath {
            self.mapManager?.showPaths([p], animated: false)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

    }
    
    
    // MARK: - Interface actions
    
    @IBAction func toggleStats(sender: AnyObject? = nil) {
        self.mapManager?.updateAllPaths()
        self.activePath?.recalculateStats()
//        print("Total Time: \(self.activePath?.totalTime)")
//        print("Total Distance: \(self.activePath?.totalDistance)")
//        print("Average Speed: \(self.activePath?.averageSpeed)")
//        print("Points: \(self.activePath?.points?.count)")
//        
//        if self.activePath != nil {
//            
//            let nf = NSNumberFormatter()
//            nf.numberStyle = NSNumberFormatterStyle.DecimalStyle
//            nf.maximumFractionDigits = 2
//            
//            let time = nf.stringFromNumber(self.activePath!.totalTime! as Double / 60.0)!
//            let distance = nf.stringFromNumber(metersToNauticalMiles(self.activePath!.totalDistance!))!
//            let speed = nf.stringFromNumber(metersPerSecondToKnots(self.activePath!.averageSpeed!))!
//            self.statsLabel.text = "\(time) min\n\(distance) NM\n \(speed) kts"
//        }
    }

    @IBAction func editingTitleComplete(sender: AnyObject) {
        if sender as! NSObject == self.pathTitleField {
            self.activePath?.title = self.pathTitleField.text
            appDelegate.saveContext()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

