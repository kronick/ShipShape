//
//  AnnotationManager.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/23/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import Foundation
import Mapbox

class AnnotationManager {
    static let SharedInstance = AnnotationManager()
    var pathAnnotations = [Path:MGLPolyline]()
    var mapView: MGLMapView? = nil
    
    init() {
        
    }
    
    func updateAllPaths() {
        for path in pathAnnotations.keys {
            updateAnnotationForPath(path)
        }
        
        mapView?.centerCoordinate = CLLocationCoordinate2D(latitude: mapView!.centerCoordinate.latitude, longitude: mapView!.centerCoordinate.longitude)
    }
    
    func addAnnotationForPath(path: Path) {
        updateAnnotationForPath(path)
    }
    func updateAnnotationForPath(path: Path) {
        // Remove the old annotation from the map view
        if let oldAnnotation = pathAnnotations[path] {
            mapView?.removeAnnotation(oldAnnotation)
        }

        // Try to create a new path and add it to the map view
        let newPolyline = generateAnnotationForPath(path)
        pathAnnotations[path] = newPolyline
        mapView?.addAnnotation(newPolyline)
    }
    
    func removeAnnotationForPath(path: Path) {
        // Check if it exists and remove if so
        if let oldAnnotation = pathAnnotations[path] {
            mapView?.removeAnnotation(oldAnnotation)
        }
        
        pathAnnotations.removeValueForKey(path)
    }
    
    
    func generateAnnotationForPath(path: Path) -> MGLPolyline {
        // Get the coordinates from the Path instance
        var coordinates: [CLLocationCoordinate2D] = []
        guard let points = path.points else {
            print("Path has no points.")
            return MGLPolyline(coordinates: &coordinates, count: 0)
        }
        
        for p in points {
            let point = p as! Point
            
            coordinates.append(CLLocationCoordinate2D(latitude: point.latitude! as Double, longitude: point.longitude! as Double))
        }
        if coordinates.count > 0 {
            // Create a new Polyline form the coordinates
            let line = MGLPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
            
            line.title = "A polyline"
            
            return line
        }
        
        return MGLPolyline(coordinates: &coordinates, count: 0)

    }
}