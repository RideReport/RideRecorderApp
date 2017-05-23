//
//  SensorManagerComponent.swift
//  Ride
//
//  Created by William Henderson on 5/17/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreMotion

class SensorManagerComponent {
    static private(set) var shared: SensorManagerComponent!
    
    public private(set) var locationManager: LocationManager!
    public private(set) var routeManager: RouteManager!
    public private(set) var classificationManager: ClassificationManager!
    public private(set) var randomForestManager: RandomForestManager!
    public private(set) var motionManager: CMMotionManager!
    public private(set) var motionActivityManager: CMMotionActivityManager!
    
    class var isInjected: Bool {
        get {
            return shared != nil
        }
    }
    
    class func inject(motionManager: CMMotionManager, motionActivityManager: CMMotionActivityManager, locationManager: LocationManager, routeManager: RouteManager, randomForestManager: RandomForestManager, classificationManager: ClassificationManager) {
        shared = SensorManagerComponent(motionManager: motionManager, motionActivityManager: motionActivityManager, locationManager: locationManager, routeManager: routeManager, randomForestManager: randomForestManager, classificationManager: classificationManager)
    }
    
    private init(motionManager: CMMotionManager, motionActivityManager: CMMotionActivityManager, locationManager: LocationManager, routeManager: RouteManager, randomForestManager: RandomForestManager, classificationManager: ClassificationManager) {
        self.motionManager = motionManager
        self.motionActivityManager = motionActivityManager
        self.locationManager = locationManager
        
        self.randomForestManager = randomForestManager
        
        self.classificationManager = classificationManager
        self.classificationManager.sensorComponent = self
        self.routeManager = routeManager
        self.routeManager.sensorComponent = self
    }
}
