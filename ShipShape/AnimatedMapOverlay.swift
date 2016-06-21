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
    var animations: [CAKeyframeAnimation]
    var boatViews = [UITextView]()
    //var coordinates: [[CGPoint]]
    var mapManager: MapManager
    var curvesAreDirty = false
    
    init(mapManager: MapManager) {
        self.mapManager = mapManager
        self.curves = [UIBezierPath]()
        //self.boatViews = [UITextView]()
        self.animations = [CAKeyframeAnimation]()
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
                    var firstPoint = CGPoint()
                    for p in points {
                        if let point = p as? Point {
                            let coordinate = CLLocationCoordinate2D(latitude: point.latitude! as Double, longitude: point.longitude! as Double)
                            let position = self.mapManager.mapView!.convertCoordinate(coordinate, toPointToView: self)
                            if !curveStarted {
                                newCurve.moveToPoint(position)
                                lastPoint = position
                                curveStarted = true
                                firstPoint = position
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
                    
                    dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                        self.createBoatAnimationAlongCurve(newCurve, start: firstPoint)
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
        for boat in self.boatViews {
            UIView.animateWithDuration(0.5, delay: 0, options: [], animations: {
                boat.alpha = 0
                }, completion: { (b) -> Void in
                    boat.removeFromSuperview()
                    self.boatViews = self.boatViews.filter() { $0 !== boat }
            })
        }
        self.setNeedsDisplay()
    }
    
    func createBoatAnimationAlongCurve(curve: UIBezierPath, start: CGPoint) {
        let boatView = UITextView()
        boatView.text = "⛵️"
        boatView.center = start
        boatView.editable = false
        boatView.userInteractionEnabled = false
        boatView.alpha = 0
        boatView.opaque = false
        boatView.backgroundColor = UIColor.clearColor()
        
        boatView.scrollEnabled = false
        boatView.font = UIFont(name: "Apple Color Emoji", size: 36)

        self.mapManager.mapView?.addSubview(boatView)
    
        boatView.sizeToFit()
        boatView.layoutIfNeeded()

        let animation = CAKeyframeAnimation()
        animation.keyPath = "position"
        animation.path = curve.CGPath;
        //animation.rotationMode = kCAAnimationRotateAuto
        animation.calculationMode = kCAAnimationCubicPaced
        animation.removedOnCompletion = true
        animation.repeatCount = 1
        //animation.beginTime = Double.random(0,3)
        animation.duration = Double.random(10,14)
        
        boatView.layer.addAnimation(animation, forKey: "move")
        
        boatViews.append(boatView)
        
        // Fade in
        UIView.animateWithDuration(0.5, delay: 0, options: [], animations: {
            boatView.alpha = 1.0 as CGFloat
        }, completion: nil)
        // Fade out and remove when done
        UIView.animateWithDuration(0.5, delay: animation.duration - 0.5, options: [], animations: {
            boatView.alpha = 0
            }, completion: { (b) -> Void in
                boatView.removeFromSuperview()
                self.boatViews = self.boatViews.filter() { $0 !== boatView }
        })

    }
    
    override func drawRect(rect: CGRect) {
        super.drawRect(rect)
//        UIColor.whiteColor().setStroke()
//        for curve in curves {
//            curve.stroke()
//        }
    }
}