//
//  MotionManager.swift
//  Ride Report
//
//  Created by William Henderson on 10/27/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreLocation
import CoreMotion

enum MotionManagerAuthorizationStatus {
    case NotDetermined
    case Denied
    case Authorized
}

class MotionManager : NSObject, CLLocationManagerDelegate {
    private var motionActivityManager: CMMotionActivityManager!
    private var motionManager: CMMotionManager!
    private var motionQueue: NSOperationQueue!
    private var motionCheckStartDate: NSDate!
    let motionStartTimeoutInterval: NSTimeInterval = 30
    let motionContinueTimeoutInterval: NSTimeInterval = 60
    private var backgroundTaskID = UIBackgroundTaskInvalid

    let sampleWindowSize: Int = 64
    private let updateInterval: NSTimeInterval = 50/1000
    private var isGatheringMotionData: Bool = false
    private var isQueryingMotionData: Bool = false
    
    private var randomForestManager: RandomForestManager!
    
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedManager : MotionManager?
        static var authorizationStatus : MotionManagerAuthorizationStatus = .NotDetermined
    }
    
    class var authorizationStatus: MotionManagerAuthorizationStatus {
        get {
            return Static.authorizationStatus
        }
        
        set {
            Static.authorizationStatus = newValue
        }
    }
    
    
    class var sharedManager:MotionManager {
        return Static.sharedManager!
    }
    
    class func startup() {
        if (Static.sharedManager == nil) {
            Static.sharedManager = MotionManager()
            Static.sharedManager?.startup()
        }
    }
    
    override init () {
        super.init()
        
        self.motionQueue = NSOperationQueue()
        self.motionActivityManager = CMMotionActivityManager()
        self.motionManager = CMMotionManager()
        self.motionManager.deviceMotionUpdateInterval = self.updateInterval
        self.motionManager.accelerometerUpdateInterval = self.updateInterval
        self.motionManager.gyroUpdateInterval = self.updateInterval
        
        self.randomForestManager = RandomForestManager(sampleSize: self.sampleWindowSize, samplingFrequency: Int(1/updateInterval))
    }
    
    private func startup() {
        let hasBeenGrantedMotionAccess = NSUserDefaults.standardUserDefaults().boolForKey("MotionManagerHasRequestedMotionAccess")
        if (!hasBeenGrantedMotionAccess) {
            // run a query so we can have the permission dialog come up when we want it to
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.motionActivityManager.queryActivityStartingFromDate(NSDate(timeIntervalSinceNow: -10), toDate: NSDate(), toQueue: self.motionQueue) { (actibity, error) -> Void in
                    if let err = error where err.code == Int(CMErrorMotionActivityNotAuthorized.rawValue) {
                        MotionManager.authorizationStatus = .Denied
                        NSNotificationCenter.defaultCenter().postNotificationName("appDidChangeManagerAuthorizationStatus", object: self)
                    } else {
                        MotionManager.authorizationStatus = .Authorized
                        NSNotificationCenter.defaultCenter().postNotificationName("appDidChangeManagerAuthorizationStatus", object: self)
                        
                        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "MotionManagerHasRequestedMotionAccess")
                        NSUserDefaults.standardUserDefaults().synchronize()
                    }
                }
            })
        } else {
            MotionManager.authorizationStatus = .Authorized
            NSNotificationCenter.defaultCenter().postNotificationName("appDidChangeManagerAuthorizationStatus", object: self)            
        }
    }
    
    func stopGatheringSensorData() {
        self.isGatheringMotionData = false
        self.stopMotionUpdatesAsNeeded()
        
        if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
            UIApplication.sharedApplication().endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        }
    }
    
    func gatherSensorData(toSensorDataCollection sensorDataCollection:SensorDataCollection) {
        self.backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
            self.backgroundTaskID = UIBackgroundTaskInvalid
        })
        
        self.isGatheringMotionData = true
        
        self.motionManager.startDeviceMotionUpdatesToQueue(self.motionQueue) { (motion, error) in
            guard let deviceMotion = motion else {
                return
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                sensorDataCollection.addDeviceMotion(deviceMotion)
            }
        }
        
        self.motionManager.startAccelerometerUpdatesToQueue(self.motionQueue) { (data, error) in
            guard let accelerometerData = data else {
                return
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                sensorDataCollection.addAccelerometerData(accelerometerData)
            }
        }
        
        self.motionManager.startGyroUpdatesToQueue(self.motionQueue) { (data, error) in
            guard let gyroData = data else {
                return
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                sensorDataCollection.addGyroscopeData(gyroData)
            }
        }
    }
    
    private func stopMotionUpdatesAsNeeded() {
        if (!self.isQueryingMotionData && !self.isGatheringMotionData) {
            self.motionManager.stopDeviceMotionUpdates()
            self.motionManager.stopAccelerometerUpdates()
            self.motionManager.stopGyroUpdates()
            
            if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
                UIApplication.sharedApplication().endBackgroundTask(self.backgroundTaskID)
                self.backgroundTaskID = UIBackgroundTaskInvalid
            }
        }
    }
    
    
    private func magnitudeVector(forSensorData sensorData:NSOrderedSet)->[Float] {
        var mags: [Float] = []
        
        for elem in sensorData {
            let reading = elem as! SensorData
            let sum = reading.x.floatValue*reading.x.floatValue + reading.y.floatValue*reading.y.floatValue + reading.z.floatValue*reading.z.floatValue
            mags.append(sqrtf(sum))
            if mags.count >= self.sampleWindowSize { break } // it is possible we over-colleted some of the sensor data
        }
        
        return mags
    }
    
    func queryCurrentActivityType(forSensorDataCollection sensorDataCollection:SensorDataCollection, withHandler handler: (sensorDataCollection: SensorDataCollection) -> Void!) {
        self.backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
            sensorDataCollection.addUnknownTypePrediction()
            handler(sensorDataCollection: sensorDataCollection)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        })

        self.isQueryingMotionData = true
        
        let completionBlock = {
            if sensorDataCollection.accelerometerAccelerations.count >= self.sampleWindowSize &&
                sensorDataCollection.gyroscopeRotationRates.count >= self.sampleWindowSize
            {
                self.isQueryingMotionData = false
                self.stopMotionUpdatesAsNeeded()
                // run classification
                let accelVector = self.magnitudeVector(forSensorData: sensorDataCollection.accelerometerAccelerations)
                let gyroVector = self.magnitudeVector(forSensorData: sensorDataCollection.gyroscopeRotationRates)
                let classConfidences = self.randomForestManager.classifyMagnitudeVector(accelVector, gyroVector: gyroVector)
                
                sensorDataCollection.addActivityTypePredictions(forClassConfidences: classConfidences)
                CoreDataManager.sharedManager.saveContext()
                
                handler(sensorDataCollection: sensorDataCollection)
                if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
                    UIApplication.sharedApplication().endBackgroundTask(self.backgroundTaskID)
                    self.backgroundTaskID = UIBackgroundTaskInvalid
                }
            }
        }
            
        self.motionManager.startAccelerometerUpdatesToQueue(self.motionQueue) { (motion, error) in
            guard let accelerometerAcceleration = motion else {
                return
            }
            guard self.isQueryingMotionData else {
                self.stopMotionUpdatesAsNeeded()
                return
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                sensorDataCollection.addAccelerometerData(accelerometerAcceleration)
                completionBlock()
            }
        }
        
        self.motionManager.startGyroUpdatesToQueue(self.motionQueue) { (motion, error) in
            guard let gyroscopeData = motion else {
                return
            }
            guard self.isQueryingMotionData else {
                self.stopMotionUpdatesAsNeeded()
                return
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                sensorDataCollection.addGyroscopeData(gyroscopeData)
                completionBlock()
            }
        }
    }
}