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

class ViewController: UIViewController, MGLMapViewDelegate {
    
    // Retreive the managedObjectContext from AppDelegate
    let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    
    @IBOutlet var mapView: MGLMapView!
    var line: MGLPolyline?
    var coordinates: [CLLocationCoordinate2D] = []
    var points_to_draw = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //mapView.attributionButton.hidden = true
        
        

        
        self.loadPolyline()
        self.drawPolyline()
    }

    func mapView(mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        // Always try to show a callout when an annotation is tapped.
        return true
    }
    
    func drawPolyline() {
        if self.coordinates.count > 0 {
            // Create a new one
            self.points_to_draw += 1
            self.points_to_draw %= self.coordinates.count
            let n  = self.points_to_draw
            let line = MGLPolyline(coordinates: &self.coordinates, count: UInt(n))
            
            line.title = "A polyline"
            
            // Add new line
            self.mapView.addAnnotation(line)
            
            // Remove old line
            if self.line != nil {
                self.mapView.removeAnnotation(self.line!)
            }
            self.line = line
            
            //self.mapView.showAnnotations([self.line!], animated: true)
            
        }
        delay(0.1) {
            self.drawPolyline()
        }
    }
    
    func loadPolyline() {
        // Parse GeoJSON on background thread
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            let jsonPath = NSBundle.mainBundle().pathForResource("sail", ofType:"geojson")
            let jsonData = NSData(contentsOfFile: jsonPath!)
            
            do {
                // Load the GeoJSON file into a dictionary
                if let jsonDict = try NSJSONSerialization.JSONObjectWithData(jsonData!, options: []) as? NSDictionary {
                    // Load the "features" array from the json file
                    if let features = jsonDict["features"] as? NSArray {
                        for feature in features {
                            if let feature = feature as? NSDictionary {
                                if let geometry = feature["geometry"] as? NSDictionary {
                                    if geometry["type"] as? String == "LineString" {
                                        // Create an array to hold the coordinates
                                        
                                        
                                        if let locations = geometry["coordinates"] as? NSArray {
                                            for location in locations {
                                                let coordinate = CLLocationCoordinate2DMake(location[1].doubleValue, location[0].doubleValue)
                                                self.coordinates.append(coordinate)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch {
                print("Failed parsing GeoJSON")
            }
        })
    }
    
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
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

