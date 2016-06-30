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

class TrackDetailViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    
    // Retreive the managedObjectContext from AppDelegate
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    
    @IBOutlet var mapView: MGLMapView!
    var mapManager: MapManager?
    
    @IBOutlet weak var pathTitleField: UITextField!
    var activePath: Path?
    
    @IBOutlet weak var publicSwitch: UISwitch!
    @IBOutlet weak var notesTextView: UITextView!
    @IBOutlet weak var deleteButton: UIBarButtonItem!
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
        
        self.pathTitleField.delegate = self
        self.notesTextView.delegate = self
        
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
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.dismissKeyboard()
        super.touchesBegan(touches, withEvent: event)
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.dismissKeyboard()
        return false
    }
    
    
    
    // MARK: - Interface actions
    
    @IBAction func deleteButtonTouched(sender: AnyObject) {
        let alertView = UIAlertController(title: "Delete this track?", message: nil, preferredStyle: .Alert)
        let deleteAction = UIAlertAction(title: "Delete", style: .Destructive, handler: { action in
            // TODO: Actually delete
            self.managedObjectContext.deleteObject(self.activePath!)
            do {
                try self.managedObjectContext.save()
                if let navigationController = self.parentViewController as? UINavigationController {
                    navigationController.popViewControllerAnimated(true)
                }
            }
            catch {
                print ("Error deleting track")
            }
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: { action in
            // Don't do anything
        })
        alertView.addAction(deleteAction)
        alertView.addAction(cancelAction)

        
        self.presentViewController(alertView, animated: true, completion: nil)
        
        
    }
    @IBAction func dismissKeyboard(sender: AnyObject? = nil) {
        self.view.endEditing(true)
    }
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

    @IBAction func publicStatusChanged(sender: UISwitch) {
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

