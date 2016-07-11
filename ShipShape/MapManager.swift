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
import CoreData

protocol MapCalloutDelegate {
    func showCalloutForPath(path: Path, atPoint: CGPoint, inMapView: UIView)
    func dismissCallout()
}

class MapManager : NSObject, MGLMapViewDelegate, UIGestureRecognizerDelegate {
    // Retreive the main NSManagedObjectContext from AppDelegate
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let mainManagedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    let backgroundMOC: NSManagedObjectContext!
    
    var pathAnnotations = [Path:PathAnnotation]()   // Holds a list of PathAnnotations indexed by Path instances
    var pathAnnotationSegmentStyles = [MGLPolyline:PathAnnotationSegmentStyle]()    // Holds style info for each path segment. Must be updated in concert with pathAnnotations!!
    var tappablePathPoints = [(CGPoint, NSManagedObjectID)]()  // Holds a list of points that are currently on screen and potentially tappable
    var selectedPointAnnotation: MGLPointAnnotation?
    
    var searchForOtherPaths = true
    
    var mapView: MGLMapView? = nil
    var mapIsLoaded = false
    var mapOverlay: AnimatedMapOverlay?
    
    var initialAnnotationsToDisplay: [MGLPolyline]
    var initialEdgePadding = UIEdgeInsetsZero
    var initialAnnotationsAnimated = false
    
    var tracksAreTappable = true
    let tappableThresholdSquared = 400 as CGFloat
    
    var calloutDelegate: MapCalloutDelegate? = nil

    var pathsInViewSearchTimer: NSTimer?
    let pathSearchTimeout: NSTimeInterval = 0.3
    
    var colorIndexer = 0 as Int
    var colorPalette = [
        UIColor(red: 238/255, green: 62/255, blue: 62/255, alpha: 1),
        UIColor(red: 236/255, green: 136/255, blue: 34/255, alpha: 1),
        UIColor(red: 247/255, green: 255/255, blue: 0/255, alpha: 1),
        UIColor(red: 56/255, green: 199/255, blue: 46/255, alpha: 1),
        UIColor(red: 104/255, green: 181/255, blue: 230/255, alpha: 1),
        UIColor(red: 215/255, green: 209/255, blue: 255/255, alpha: 1),
        UIColor(red: 223/255, green: 62/255, blue: 238/255, alpha: 1)
    ]
    
    dynamic var userTrackingMode: MGLUserTrackingMode = .None   // dynamic so this can be KVO'ed
    
    init(mapView: MGLMapView?) {
        
        self.initialAnnotationsToDisplay = [MGLPolyline]()
        
        self.mapView = mapView
        
        // Set up a background ManagedObjectContext to process Point and Path data in the background
        self.backgroundMOC = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        super.init()
        self.backgroundMOC.parentContext = self.mainManagedObjectContext
        
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
        // Remove all paths and reset color index
        self.colorIndexer = 0
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
        
        // Do this calculation on a background thread in a separate ManagedObjectContext
        
        // First, we need to get the object IDs of the paths in the current MOC
        let pathIDs = self.pathAnnotations.keys.map { $0.objectID }
        
        self.backgroundMOC.performBlock {   // Do all this work in the proper queue for this MOC
            var newTappablePathPoints = [(CGPoint, NSManagedObjectID)]()
            let paths = pathIDs.map { self.backgroundMOC.objectWithID($0) as? Path }
            for path in paths {
                guard let points = path?.points, path = path else { continue }
                var lastPoint: CGPoint? = nil   // Used to calculate segment distance
                
                for p in points {
                    if let point = p as? Point {
                        let latitude = point.latitude! as Double
                        let longitude = point.longitude! as Double
                        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
                                newTappablePathPoints.append((position, path.objectID))
                            }
                            lastPoint = position
                        }
                    }
                }
            }
            
            // Add the points back in on the main thread
            dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                self.tappablePathPoints = newTappablePathPoints
            }
            
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func viewWasTappedByGestureRecognizer(recognizer: UITapGestureRecognizer) {
        guard let mapView = self.mapView else { return }
        
        let location = recognizer.locationInView(mapView)
        
        // Remove old annotation
//        if let selectedPointAnnotation = self.selectedPointAnnotation {
//            mapView.removeAnnotation(selectedPointAnnotation)
//        }

        
        
        // Look up the closest path/point in a background thread
        // Need to create a separate NSManagedObjectContext and reference by objectID
        let moc = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        moc.parentContext = self.mainManagedObjectContext
        moc.performBlock {   // Do all this work in the proper queue for this MOC
            var closestDistance = CGFloat.max
            var closestPathID: NSManagedObjectID? = nil
            var closestPoint: CGPoint? = nil
            
            for pathPoint in self.tappablePathPoints {
                let p = pathPoint.0
                let pathID = pathPoint.1
                
                let distanceSquared = (location.x - p.x) * (location.x - p.x) + (location.y - p.y) * (location.y - p.y)
                if distanceSquared < self.tappableThresholdSquared && distanceSquared < closestDistance {
                    closestPathID = pathID
                    closestDistance = distanceSquared
                    closestPoint = p
                }
            }
            
            if let closestPathID = closestPathID, closestPoint = closestPoint {
                dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                    guard let delegate = self.calloutDelegate, mapView = self.mapView else { return }
                    guard let closestPath = self.mainManagedObjectContext.objectWithID(closestPathID) as? Path else { return }
                    print("Tapped on path: \(closestPath.title)")
                    
                    delegate.showCalloutForPath(closestPath, atPoint: closestPoint, inMapView: mapView)
                }
            }
            else {
                // Just remove the view
                dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                    guard let delegate = self.calloutDelegate else { return }
                    delegate.dismissCallout()
                }
            }
        }

    }
    
    func generateCalloutViewForPath(path: Path, anchor: CGPoint) -> UIView {
        let width = 250 as CGFloat
        let height = 90 as CGFloat
        let view = UIView(frame: CGRect(x: anchor.x-width/2, y: anchor.y-height, width: width, height: height))
        view.backgroundColor = UIColor.whiteColor()
        
        if let title = path.title {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.sizeToFit()
            titleLabel.frame.offsetInPlace(dx: 10, dy: 10)
            view.addSubview(titleLabel)
        }
        
        let infoButton = UIButton(type: .DetailDisclosure)
        view.addSubview(infoButton)
        infoButton.frame.offsetInPlace(dx: 200, dy: 10)
        
        if let date = path.created {
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateStyle = .MediumStyle
            dateFormatter.timeStyle = .ShortStyle
            
            let dateLabel = UILabel()
            dateLabel.text = dateFormatter.stringFromDate(date)
            view.addSubview(dateLabel)
            dateLabel.sizeToFit()
            dateLabel.frame.offsetInPlace(dx: 10, dy: 40)
            
        }
        
        
        return view
    }
    
    func addAnnotationForPath(path: Path) {
        updateAnnotationForPath(path, colorIndex: self.colorIndexer)
        self.mapOverlay?.revealPath(path)
        self.colorIndexer += 1
    }
    func updateAnnotationForPath(path: Path, colorIndex: Int? = nil) {
        // Remove the old annotation from the map view
        if let oldAnnotationSegments = pathAnnotations[path]?.segments {
            for segment in oldAnnotationSegments {
                // Remove polyline from map and remove style from dictionary
                mapView?.removeOverlay(segment.polyline)
                pathAnnotationSegmentStyles.removeValueForKey(segment.polyline)
            }
        }

        
        // Try to create a new path and add it to the map view
        let newSegments = generateAnnotationSegmentsForPath(path, colorIndex: colorIndex == nil ? self.colorIndexer : colorIndex!)
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
    
    
    func generateAnnotationSegmentsForPath(path: Path, colorIndex: Int) -> [PathAnnotationSegment] {
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
                        let completedSegment = PathAnnotationSegment(propulsion: currentPropulsion!, polyline: line, parent: path, colorIndex: colorIndex)
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
            let completedSegment = PathAnnotationSegment(propulsion: currentPropulsion, polyline: line, parent: path, colorIndex: colorIndex)
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
        let emptyPathAnnotationSegment = PathAnnotationSegment(propulsion: .None, polyline: emptyLine, parent: path, colorIndex: colorIndex)
        return[emptyPathAnnotationSegment]
    }
    
    func styleForAnnotationSegment(segment: PathAnnotationSegment, sailor: Sailor? = Sailor.ActiveSailor) -> PathAnnotationSegmentStyle {
        var style = PathAnnotationSegmentStyle()

        if sailor == Sailor.ActiveSailor {
            //style.strokeColor = UIColor(red: 0.94, green: 0.30, blue: 0.30, alpha: 1)
            var alpha = CGFloat(10 - segment.colorIndex) / 10.0
            if alpha < 0.1 { alpha = 0.1 }
            style.strokeColor = UIColor(hue: 0.57, saturation: 0.9, brightness: 1.0, alpha: 1.0)
            style.alpha = alpha
            style.lineWidth = 1.0 //3.0
        }
        else {
            // Style for other sailors' paths
            style.strokeColor = UIColor(hue: 0.24, saturation: 0.9, brightness: 1.0, alpha: 1.0)
            style.alpha = 0.8
            style.lineWidth = 1.0
        }
        
        // Special state if this path is actively recording
        if let state = segment.parent?.state {
            if state == PathState.Recording.rawValue {
                style.strokeColor = UIColor(hue: 0, saturation: 0.9, brightness: 1.0, alpha: 1.0)
                style.alpha = 1.0
            }
        }
        //style.strokeColor = UIColor(red: CGFloat.random(0.3,1), green: CGFloat.random(0.3,1), blue: CGFloat.random(0.3,1), alpha: 1.0)
        //style.strokeColor = self.colorPalette[segment.colorIndex % self.colorPalette.count]
        
        
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
    
    
    func getPathsInView() {
        guard let mapView = self.mapView else { return }
        
        // Search for paths in viewport
        let a = mapView.convertPoint(CGPoint(x:0, y:0), toCoordinateFromView: mapView)
        let b = mapView.convertPoint(CGPoint(x:mapView.frame.width, y:0), toCoordinateFromView: mapView)
        let c = mapView.convertPoint(CGPoint(x:mapView.frame.width, y:mapView.frame.height), toCoordinateFromView: mapView)
        let d = mapView.convertPoint(CGPoint(x:0, y:mapView.frame.height), toCoordinateFromView: mapView)
        
        RemoteAPIManager.sharedInstance.getPathsInBounds(a, b, c, d,
            afterEach: { pathID in
                // This block is called after each path is ready to be added to the map
                // The pathID parameter is a CoreData NSManagedObjectID that needs to be re-associated with the main managedobjectcontext back on the main thread
                dispatch_async(dispatch_get_main_queue()) {
                    guard let path = self.mainManagedObjectContext.objectWithID(pathID) as? Path else {
                        NSLog("MapManager: Received a bad objectID for a path in bounds")
                        return
                    }
                    
                    //if path.creator != Sailor.ActiveSailor { // Only flag other peoples' paths as temporary
                    path.temporary = true // Flag as temporary so we can remove it from the cache later
                    // }
                    
                    // Add this path to the map only if it isn't already being displayed
                    if !self.pathAnnotations.keys.contains(path) {
                        self.addAnnotationForPath(path)
                    }
                
                }
            },
            completion: { pathIDs in
                // This is called once all paths are ready with a list of ObjectIDs of the paths that are in bounds.
                // Remove any annotations for paths that are not in view.
                dispatch_async(dispatch_get_main_queue()) {
                    NSLog("MapManager: Paths in bounds download complete.")
                    var freshPaths = [Path]()  // List of freshly received paths
                    for p in pathIDs {
                        if let path = self.mainManagedObjectContext.objectWithID(p) as? Path {
                            freshPaths.append(path)
                        }
                    }
                    
                    // Now delete any old temporary paths that aren't in the fresh list
                    for path in self.pathAnnotations.keys {
                        if path.temporary == true && !freshPaths.contains(path) && path.creator != Sailor.ActiveSailor {
                            self.removeAnnotationForPath(path)
                        }
                    }
                    
                    NSLog("MapManager: All paths added to the map")
                }
            })
    }
    
    
    // MARK: - MGLMapViewDelegate
    
    func mapView(mapView: MGLMapView, regionWillChangeAnimated animated: Bool) {
        self.mapOverlay?.viewWillChange()
        if let delegate = self.calloutDelegate {
            delegate.dismissCallout()
        }
        
        // Cancel any pending paths-in-view searches
        self.pathsInViewSearchTimer?.invalidate()
    }
    func mapViewRegionIsChanging(mapView: MGLMapView) {
        self.mapOverlay?.viewIsChanging()
    }
    func mapView(mapView: MGLMapView, regionDidChangeAnimated animated: Bool) {
        //self.mapOverlay?.fadeInCurves()
        self.mapOverlay?.viewDidChange()
        //self.updateTappablePoints()
        
        // Search for paths in bound of the new view, but wait 0.5 seconds to filter out short pauses
        if self.searchForOtherPaths {
            self.pathsInViewSearchTimer = NSTimer.scheduledTimerWithTimeInterval(self.pathSearchTimeout, target: self, selector: #selector(getPathsInView), userInfo: nil, repeats: false)
        }

        // Re-trigger any animations
        for p in self.pathAnnotations.keys {
            self.mapOverlay?.revealPath(p)
        }
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
        
        return 1.0
    }
    func mapView(mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        if let polyline = annotation as? MGLPolyline {
            if let style = pathAnnotationSegmentStyles[polyline] {
                return style.strokeColor
            }
        }
        return UIColor.blueColor()
        
    }
    
    func mapView(mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    func mapView(mapView: MGLMapView, didChangeUserTrackingMode mode: MGLUserTrackingMode, animated: Bool) {
        self.userTrackingMode = mode
    }
    
    func mapView(mapView: MGLMapView, didSelectAnnotation annotation: MGLAnnotation) {
        
    }
    func mapView(mapView: MGLMapView, tapOnCalloutForAnnotation annotation: MGLAnnotation) {
        
    }
    
    func mapView(mapView: MGLMapView, rightCalloutAccessoryViewForAnnotation annotation: MGLAnnotation) -> UIView? {
        return UIButton(type: .DetailDisclosure)
    }
    func mapView(mapView: MGLMapView, annotation: MGLAnnotation, calloutAccessoryControlTapped control: UIControl) {
        
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
    var parent: Path?
    var colorIndex: Int
}
struct PathAnnotationSegmentStyle {
    var alpha: CGFloat = 1.0
    var strokeColor: UIColor = UIColor.blueColor()
    var lineWidth: CGFloat = 3.0
}