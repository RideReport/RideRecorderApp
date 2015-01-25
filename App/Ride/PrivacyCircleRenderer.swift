//
//  PrivacyCircleRenderer.swift
//  Ride
//
//  Created by William Henderson on 12/15/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import MapKit

class PrivacyCircleRenderer : MKOverlayPathRenderer {
    var coordinate : CLLocationCoordinate2D {
        didSet {
            self.invalidatePath()
        }
    }
    var radius : CLLocationDistance {
        didSet {
            self.invalidatePath()
        }
    }
    
    init!(circle: MKCircle!) {
        self.coordinate = circle.coordinate
        self.radius = circle.radius
        
        super.init(overlay: circle)
    }
    
    override func createPath() {
        let path = CGPathCreateMutable()
        let centerPoint = self.pointForMapPoint(MKMapPointForCoordinate(self.coordinate))
        let radius = MKMapPointsPerMeterAtLatitude(self.coordinate.latitude) * self.radius
        CGPathAddArc(path, nil, centerPoint.x, centerPoint.y, CGFloat(radius), 0.0, 2.0 * CGFloat(M_PI), true)
        
        self.path = path
    }
}