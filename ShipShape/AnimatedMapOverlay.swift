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
import GLKit

class PathAnimation {
    var points = [CGPoint]()
    var pointArray = [GLfloat]() // Capacity equals 2x size of points array; this is the raw data that's passed on to the shader
    var colorArray = [GLfloat]() // 4 floats per point vertex
    var VBO: GLuint = 0
    var progress: CGFloat = 0
    var startTime: NSDate?
    var duration: NSTimeInterval?
    
}

class AnimatedMapOverlay : GLKView, GLKViewDelegate, GLKViewControllerDelegate {
    let duplicatePointDistanceSquared = 2*2 as CGFloat
    var animations =  [PathAnimation]()
    var mapManager: MapManager
    
    var viewController: GLKViewController!
    
    var renderingEffect = GLKBaseEffect()
    var mapIsChanging = false
    var mapViewVersion = 0 // Counter to tie paths to only one version of the map view
    
    init(mapManager: MapManager) {
        self.mapManager = mapManager
        self.viewController = GLKViewController()
        super.init(frame: mapManager.mapView!.superview?.frame ?? mapManager.mapView!.frame)
        self.delegate = self
        self.context = EAGLContext(API: .OpenGLES2)
        
        self.backgroundColor = UIColor.clearColor()
        self.viewController.view = self
        self.viewController.delegate = self
        self.viewController.preferredFramesPerSecond = 60
        
        // Set up the projection matrix to match the mapView's coordinate system
        
        self.renderingEffect.transform.projectionMatrix = GLKMatrix4MakeOrtho(
            0, Float(self.frame.width), Float(self.frame.height), 0,  -1024, 1024
        )
        
        self.drawableMultisample = .Multisample4X
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func clear(animated animated: Bool) {
        self.animations.removeAll()
    }
    
    func viewWillChange() {
        // Remove all animations
        self.clear(animated: true)
        self.setNeedsDisplay()
    }
    func viewIsChanging() {
        self.mapIsChanging = true
    }
    func viewDidChange() {
        self.mapIsChanging = false
        self.mapViewVersion += 1
    }
    
    func revealPath(path: Path, delay: NSTimeInterval = 0, duration: NSTimeInterval = 1.0) {
        // Create a path entry animation
        // First, calculate the points in screen coordinates, but do that on a background thread
        // In order to do it in the background, we have to get unmanaged copies of all the path's points
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) { [unowned self] in
            guard let managedPoints = path.points else { return }
            var points = [UnmanagedPoint]()
            
            for p in managedPoints {
                guard let point = p as? Point else { continue }
                points.append(point.unmanagedCopy())
            }
            
            let viewVersion = self.mapViewVersion
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                var animation = PathAnimation()
                var lastAddedPoint: CGPoint? = nil
                
                for point in points {
                    // Loop through each point and calculate its CGPoint position on screen
                    let coordinate = CLLocationCoordinate2D(latitude: point.latitude! as Double, longitude: point.longitude! as Double)
                    let position = self.mapManager.mapView!.convertCoordinate(coordinate, toPointToView: self)
                    
                    // Calculate the distance between this and the last point, setting to infinity if this is the first point
                    // This is used to filter out points that are very close to each other and won't render differently
                    let distanceSquared = lastAddedPoint == nil ? CGFloat.max : (lastAddedPoint!.x-position.x)*(lastAddedPoint!.x-position.x) + (lastAddedPoint!.y-position.y)*(lastAddedPoint!.y-position.y)
                    if distanceSquared > self.duplicatePointDistanceSquared {
                        // This point should be added
                        lastAddedPoint = position
                        animation.points.append(position)
                    }
                }
                
                // Calculate duration
                var duration = 0 as NSTimeInterval
                if points.count > 1 {
                    let firstPoint = points[0]
                    let lastPoint = points[points.count-1]
                    if let startTime = firstPoint.created, endTime = lastPoint.created {
                        duration = endTime.timeIntervalSinceDate(startTime) / 3000
                    }
                }
                
                animation.startTime = NSDate.init(timeIntervalSinceNow: delay)
                animation.duration = duration
                animation.progress = 0
                
                // Create one GL point at the start point
                animation.pointArray.append(Float(animation.points[0].x))
                animation.pointArray.append(Float(animation.points[0].y))
                animation.colorArray.appendContentsOf([1, 1, 1, 0.5])
                
                dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                    // Make sure that these points are still good for the current state of the map
                    if !self.mapIsChanging && self.mapViewVersion == viewVersion {
                        self.animations.append(animation)
                    }
                }
            }
        }
    }

    // MARK: - GLKViewDelegate
    func glkView(view: GLKView, drawInRect rect: CGRect) {
        glClearColor(0.0, 0.0, 0.0, 0.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        //glColor4f(1.0, 1.0, 1.0, 1.0)
        glLineWidth(4)
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glEnable(GLenum(GL_BLEND))
        
        self.renderingEffect.prepareToDraw()

        // Render each animation
        for a in self.animations {
            glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Position.rawValue))    // Sending vertex position data
            glVertexAttribPointer(GLuint(GLKVertexAttrib.Position.rawValue), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLint(sizeof(GLfloat) * 2), a.pointArray) // Here is where the vertex position data lives
            glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Color.rawValue))    // Sending vertex color data
            glVertexAttribPointer(GLuint(GLKVertexAttrib.Color.rawValue), 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLint(sizeof(GLfloat) * 4), a.colorArray) // Here is where the vertex color data lives
            glDrawArrays(GLenum(GL_LINE_STRIP), 0, GLint(a.pointArray.count / 2)) // Render!
        }
    }

    // MARK: - GLKViewControllerDelegate
    
    func glkViewControllerUpdate(controller: GLKViewController) {
        // Loop through animations and update each
        for a in self.animations {
            // Calculate progress
            var progress = 1.0 as CGFloat
            if let start = a.startTime, duration = a.duration where a.duration > 0 {
                progress = CGFloat(NSDate().timeIntervalSinceDate(start) / duration)
            }
            
            a.progress = progress
            
            if progress > 1 {
                continue
            }
            if progress < 0 {
                continue
            }
            // Add the appropriate number of points
            // TODO: Calculate this based on the point timestamps, not just a simple linear progression
            
            var currentPointCount = a.pointArray.count / 2
            while CGFloat(currentPointCount) < a.progress * CGFloat(a.points.count) && currentPointCount < a.points.count {
                // We should add another point
                a.pointArray.append(Float(a.points[currentPointCount].x))
                a.pointArray.append(Float(a.points[currentPointCount].y))
                a.colorArray.appendContentsOf([1, 1, 1, 0.5])
                
                currentPointCount = a.pointArray.count / 2
            }
        }
    }
}