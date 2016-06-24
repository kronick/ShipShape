//
//  MapManager.swift
//  ShipShape
//
//  Act as MGLMapView delegate as well as linking paths to annotations
//
//  Created by Sam Kronick on 5/23/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import Foundation
import Mapbox

class MapManager : NSObject, MGLMapViewDelegate {
    
    var pathAnnotations = [Path:PathAnnotation]()   // Holds a list of PathAnnotations indexed by Path instances
    var pathAnnotationSegmentStyles = [MGLPolyline:PathAnnotationSegmentStyle]()    // Holds style info for each path segment. Must be updated in concert with pathAnnotations!!
    var tappablePathPoints = [(CGPoint, Path)]()  // Holds a list of points that are currently on screen and potentially tappable
    var selectedPointAnnotation: MGLPointAnnotation?
    var mapView: MGLMapView? = nil
    var mapIsLoaded = false
    var mapOverlay: AnimatedMapOverlay?
    
    var initialAnnotationsToDisplay: [MGLPolyline]
    var initialEdgePadding = UIEdgeInsetsZero
    var initialAnnotationsAnimated = false
    
    var tracksAreTappable = true
    let tappableThresholdSquared = 400 as CGFloat

    
    dynamic var userTrackingMode: MGLUserTrackingMode = .None   // dynamic so this can be KVO'ed
    
    init(mapView: MGLMapView?) {
        
        self.initialAnnotationsToDisplay = [MGLPolyline]()
        super.init()
        
        self.mapView = mapView
        
        self.mapOverlay = AnimatedMapOverlay(mapManager: self)
        self.mapView?.addSubview(self.mapOverlay!)
        
        self.mapView?.delegate = self
        
        // Set up tap gesture to select routes
        // But first set up a double tap that does nothing, just so we can ignore it and Mapbox's double tap handling
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: nil)
        doubleTapGesture.numberOfTapsRequired = 2
        self.mapView?.addGestureRecognizer(doubleTapGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(viewWasTappedByGestureRecognizer))
        tapGesture.numberOfTapsRequired = 1
        //tapGesture.requireGestureRecognizerToFail(doubleTapGesture)
        self.mapView?.addGestureRecognizer(tapGesture)
        
    }
    
    func clearAnnotations() {
        for path in pathAnnotations.keys {
            removeAnnotationForPath(path)
        }
    }
    
    func showPaths(paths: [Path], animated: Bool = true, padding: UIEdgeInsets = UIEdgeInsetsMake(20, 20, 20, 20)) {
        var annotations = [MGLPolyline]()
        for p in paths {
            if let pathAnnotation = self.pathAnnotations[p] {
                let segments = pathAnnotation.segments
                let polylines = segments.map({$0.polyline})
                annotations.appendContentsOf(polylines)
            }
        }
    
        if !mapIsLoaded {
            initialAnnotationsToDisplay = annotations
            initialEdgePadding = padding
            initialAnnotationsAnimated = animated
        }
        else {
            mapView?.showAnnotations(annotations, edgePadding: padding, animated: animated)
        }
    }
    
    func updateAllPaths() {
        for path in pathAnnotations.keys {
            updateAnnotationForPath(path)
        }
        
        // Force view refresh
        mapView?.centerCoordinate = CLLocationCoordinate2D(latitude: mapView!.centerCoordinate.latitude, longitude: mapView!.centerCoordinate.longitude)
    }
    
    func updateTappablePoints() {
        guard self.mapView != nil else { return }
        
        // Loop through all paths and convert their points to coordinates in the map view
        // Filter out points that are very close to each other
        // TODO: add intermediate points to long segments
        
        self.tappablePathPoints.removeAll()
        
        // Do this calculation on a background thread
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
            var newTappablePathPoints = [(CGPoint, Path)]()
            let paths = self.pathAnnotations.keys
            
            for path in paths {
                var lastPoint: CGPoint? = nil   // Used to calculate segment distance
                if let points = path.points {
                    for p in points {
                        if let point = p as? Point {
                            let coordinate = CLLocationCoordinate2D(latitude: point.latitude! as Double, longitude: point.longitude! as Double)
                            let position = self.mapView!.convertCoordinate(coordinate, toPointToView: self.mapView)
                        
                            // Filter out points that are very close together
                            var addPoint = false
                            var distanceSquared: CGFloat?
                            if let last = lastPoint {
                                distanceSquared = (last.x-position.x)*(last.x-position.x) + (last.y-position.y)*(last.y-position.y)
                                if distanceSquared > 64 {
                                    addPoint = true
                                }
                            }
                            else {
                                addPoint = true
                            }
                            if addPoint {
                                if self.mapView!.frame.contains(position) {
                                   newTappablePathPoints.append((position, path))
                                }
                                lastPoint = position
                            }
                    
                        }
                        
                    }
                    
                    // Add the points back in on the main thread
                    dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                        self.tappablePathPoints = newTappablePathPoints
                    }
                }
            }
        }
    }
    
    func viewWasTappedByGestureRecognizer(recognizer: UITapGestureRecognizer) {
        guard let mapView = self.mapView else { return }
        
        let location = recognizer.locationInView(mapView)
        
        // Remove old annotation
        if let selectedPointAnnotation = self.selectedPointAnnotation {
            mapView.removeAnnotation(selectedPointAnnotation)
        }
        
        // Look up the closest path/point in a background thread
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
            var closestDistance = CGFloat.max
            var closestPath: Path? = nil
            var closestPoint: CGPoint? = nil
            
            for pathPoint in self.tappablePathPoints {
                let p = pathPoint.0
                let path = pathPoint.1
                
                let distanceSquared = (location.x - p.x) * (location.x - p.x) + (location.y - p.y) * (location.y - p.y)
                if distanceSquared < self.tappableThresholdSquared && distanceSquared < closestDistance {
                    closestPath = path
                    closestDistance = distanceSquared
                    closestPoint = p
                }
            }
            
            if let closestPath = closestPath, closestPoint = closestPoint {
                print(closestPath.title)
                // Create a new point annotation
                self.selectedPointAnnotation = MGLPointAnnotation()
                self.selectedPointAnnotation?.coordinate = mapView.convertPoint(closestPoint, toCoordinateFromView: mapView)
                if let title = closestPath.title {
                    self.selectedPointAnnotation?.title = title
                }
                if let date = closestPath.created {
                    let dateFormatter = NSDateFormatter()
                    dateFormatter.dateStyle = .MediumStyle
                    dateFormatter.timeStyle = .ShortStyle
                    
                    self.selectedPointAnnotation?.subtitle = dateFormatter.stringFromDate(date)
                }
                
                dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                    if let selectedPointAnnotation = self.selectedPointAnnotation {
                        mapView.addAnnotation(selectedPointAnnotation)
                        mapView.selectAnnotation(selectedPointAnnotation, animated: true)
                    }
                }
            }
        }

    }
    
    func addAnnotationForPath(path: Path) {
        updateAnnotationForPath(path)
    }
    func updateAnnotationForPath(path: Path) {
        // Remove the old annotation from the map view
        if let oldAnnotationSegments = pathAnnotations[path]?.segments {
            for segment in oldAnnotationSegments {
                // Remove polyline from map and remove style from dictionary
                mapView?.removeOverlay(segment.polyline)
                pathAnnotationSegmentStyles.removeValueForKey(segment.polyline)
            }
        }

        // Try to create a new path and add it to the map view
        let newSegments = generateAnnotationSegmentsForPath(path)
        pathAnnotations[path] = PathAnnotation(path: path, segments: newSegments, state: .Complete, sailor: path.creator)
        
        mapView?.addOverlays(newSegments.map({$0.polyline}))
    }
    
    func removeAnnotationForPath(path: Path) {
        // Remove the old annotation segments from the map view
        if let oldAnnotationSegments = pathAnnotations[path]?.segments {
            for segment in oldAnnotationSegments {
                // Remove polyline from map and remove style from dictionary
                mapView?.removeOverlay(segment.polyline)
                pathAnnotationSegmentStyles.removeValueForKey(segment.polyline)
            }
        }
        
        pathAnnotations.removeValueForKey(path)
    }
    
    
    func generateAnnotationSegmentsForPath(path: Path) -> [PathAnnotationSegment] {
        if let points = path.points {
        
            var annotationSegments = [PathAnnotationSegment]()
            
            var currentPropulsion: PropulsionMethod?
            var currentCoordinates: [CLLocationCoordinate2D] = []
            
            for p in points {
                if let point = p as? Point {
                    let newPropulsion = PropulsionMethod(rawValue: point.propulsion != nil ? point.propulsion! : "")
                    if currentPropulsion == nil && newPropulsion != nil{
                        currentPropulsion = newPropulsion
                    }
                    
                    if newPropulsion != currentPropulsion {
                        // Propulsion method has changed, create a new segment
                        let line = MGLPolyline(coordinates: &currentCoordinates, count: UInt(currentCoordinates.count))
                        let completedSegment = PathAnnotationSegment(propulsion: currentPropulsion!, polyline: line)
                        annotationSegments.append(completedSegment)
                        
                        // Calculate line style
                        pathAnnotationSegmentStyles[completedSegment.polyline] = styleForAnnotationSegment(completedSegment, sailor: path.creator)
                        
                        currentPropulsion = newPropulsion
                        currentCoordinates = [CLLocationCoordinate2D]()
                    }
                    
                    currentCoordinates.append(CLLocationCoordinate2D(latitude: point.latitude! as Double, longitude: point.longitude! as Double))
                }
            }
            
            
            // Wrap up final segment
            let line = MGLPolyline(coordinates: &currentCoordinates, count: UInt(currentCoordinates.count))
            let completedSegment = PathAnnotationSegment(propulsion: currentPropulsion, polyline: line)
            annotationSegments.append(completedSegment)
            
            // Calculate line style
            pathAnnotationSegmentStyles[completedSegment.polyline] = styleForAnnotationSegment(completedSegment, sailor: path.creator)
            
            if annotationSegments.count > 0 {
                return annotationSegments
            }
        }
        
        // No path or points
        var coordinates = [CLLocationCoordinate2D]()
        let emptyLine = MGLPolyline(coordinates: &coordinates, count: 0)
        let emptyPathAnnotationSegment = PathAnnotationSegment(propulsion: .None, polyline: emptyLine)
        return[emptyPathAnnotationSegment]
    }
    
    func styleForAnnotationSegment(segment: PathAnnotationSegment, sailor: Sailor? = Sailor.ActiveSailor) -> PathAnnotationSegmentStyle {
        var style = PathAnnotationSegmentStyle()

        if sailor == Sailor.ActiveSailor {
            style.strokeColor = UIColor(red: 0.94, green: 0.30, blue: 0.30, alpha: 1)
            style.lineWidth = 1.0
        }
        
        style.strokeColor = UIColor(red: CGFloat.random(0.3,1), green: CGFloat.random(0.3,1), blue: CGFloat.random(0.3,1), alpha: 1.0)
        
        return style
        
    }

    func snapshot() -> UIImage {
        if self.mapView == nil {
            return UIImage()
        }
        
        UIGraphicsBeginImageContextWithOptions(self.mapView!.bounds.size, true, 0)
        self.mapView!.drawViewHierarchyInRect(self.mapView!.bounds, afterScreenUpdates: true)
        let snapshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return snapshot
    }
    
    
    
    
    
    // MARK: - MGLMapViewDelegate
    
    func mapView(mapView: MGLMapView, regionWillChangeAnimated animated: Bool) {
        mapOverlay?.fadeOutCurves()
    }
    func mapView(mapView: MGLMapView, regionDidChangeAnimated animated: Bool) {
        mapOverlay?.fadeInCurves()
        self.updateTappablePoints()
    }
    
    func mapViewDidFinishLoadingMap(mapView: MGLMapView) {
        mapIsLoaded = true
        
        if initialAnnotationsToDisplay.count > 0 {
            mapView.showAnnotations(initialAnnotationsToDisplay, edgePadding: initialEdgePadding, animated: initialAnnotationsAnimated)
        }
        
    }
    func mapViewDidFinishRenderingFrame(mapView: MGLMapView, fullyRendered: Bool) {
        //self.updateAllPaths()
    }
    func mapView(mapView: MGLMapView, alphaForShapeAnnotation annotation: MGLShape) -> CGFloat {
        if let polyline = annotation as? MGLPolyline {
            if let style = pathAnnotationSegmentStyles[polyline] {
                return style.alpha
            }
        }
        
        return 1
    }
    func mapView(mapView: MGLMapView, lineWidthForPolylineAnnotation annotation: MGLPolyline) -> CGFloat {
        if let style = pathAnnotationSegmentStyles[annotation] {
            return style.lineWidth
        }
        
        return 5.0
    }
    func mapView(mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        if let polyline = annotation as? MGLPolyline {
            if let style = pathAnnotationSegmentStyles[polyline] {
                return style.strokeColor
            }
        }
        
        if(annotation.title == "A polyline" && annotation is MGLPolyline) {
            return UIColor(red: 0.94, green: 0.30, blue: 0.30, alpha: 1)
        }
        else {
            return UIColor.blueColor()
        }
    }
    
    func mapView(mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    func mapView(mapView: MGLMapView, didChangeUserTrackingMode mode: MGLUserTrackingMode, animated: Bool) {
        self.userTrackingMode = mode
//        switch(mode) {
//        case .None:
//            self.followUserButton.selected = false
//        case .Follow, .FollowWithCourse, .FollowWithHeading:
//            self.followUserButton.selected = true
//        }
    }
    
    func mapView(mapView: MGLMapView, didSelectAnnotation annotation: MGLAnnotation) {
        
    }
    func mapView(mapView: MGLMapView, tapOnCalloutForAnnotation annotation: MGLAnnotation) {
        
    }
}

public enum PathAnnotationState {
    case Recording
    case Complete
    case Reviewing
}
struct PathAnnotation {
    var path: Path
    var segments: [PathAnnotationSegment]
    var state: PathAnnotationState
    var sailor: Sailor?
}
struct PathAnnotationSegment {
    var propulsion: PropulsionMethod?
    var polyline: MGLPolyline
}
struct PathAnnotationSegmentStyle {
    var alpha: CGFloat = 1.0
    var strokeColor: UIColor = UIColor.blueColor()
    var lineWidth: CGFloat = 3.0
}