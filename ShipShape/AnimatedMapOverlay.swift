//
//  AnimatedMapOverlay.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/27/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import Foundation
import UIKit
import Mapbox

class AnimatedMapOverlay : UIView {
    
    var curves: [UIBezierPath]
    //var coordinates: [[CGPoint]]
    var mapManager: MapManager
    var curvesAreDirty = false
    
    init(mapManager: MapManager) {
        self.mapManager = mapManager
        self.curves = [UIBezierPath]()
        super.init(frame: mapManager.mapView!.frame)
        self.backgroundColor = UIColor.clearColor()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func fadeInCurves() {
        //return;
        
        self.curvesAreDirty = true
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) { [unowned self] in
            // Create curves for each path in the manager
            let paths = self.mapManager.pathAnnotations.keys
            var lastPoint: CGPoint? = nil
            var newCurves = [UIBezierPath]()
            
            self.curvesAreDirty = false
            
            for path in paths {
                if let points = path.points {
                    let newCurve = UIBezierPath()
                    var curveStarted = false
                    for p in points {
                        if let point = p as? Point {
                            let coordinate = CLLocationCoordinate2D(latitude: point.latitude! as Double, longitude: point.longitude! as Double)
                            let position = self.mapManager.mapView!.convertCoordinate(coordinate, toPointToView: self)
                            if !curveStarted {
                                newCurve.moveToPoint(position)
                                lastPoint = position
                                curveStarted = true
                            }
                            else {
                                // Filter out points that are very close together
                                var addPoint = false
                                if let last = lastPoint {
                                    let distanceSquared = (last.x-position.x)*(last.x-position.x) + (last.y-position.y)*(last.y-position.y)
                                    if distanceSquared > 64 {
                                        addPoint = true
                                    }
                                }
                                else {
                                    addPoint = true
                                }
                                if addPoint {
                                    newCurve.addLineToPoint(position)
                                    lastPoint = position
                                }
                            }
                        }
                        
                        if self.curvesAreDirty { return }
                    }
                    newCurves.append(newCurve)
                }
            }
            
            self.curves.appendContentsOf(newCurves)
            
            dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                self.setNeedsDisplay()
            }
        }
    }
    func fadeOutCurves() {
        self.curves = [UIBezierPath]()
        self.curvesAreDirty = true
        self.setNeedsDisplay()
    }
    
    override func drawRect(rect: CGRect) {
        UIColor.whiteColor().setStroke()
        for curve in curves {
            curve.stroke()
        }
    }
}