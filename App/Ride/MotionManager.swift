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

    static let sampleWindowSize: Int = 64
    static let updateInterval: NSTimeInterval = 50/1000

    private var isGatheringMotionData: Bool = false
    
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
            dispatch_async(dispatch_get_main_queue()) {
                // start async
                Static.sharedManager?.startup()
            }
        }
    }
    
    override init () {
        super.init()
        
        self.motionQueue = NSOperationQueue()
        self.motionActivityManager = CMMotionActivityManager()
        self.motionManager = CMMotionManager()
        self.motionManager.accelerometerUpdateInterval = MotionManager.updateInterval
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
        self.stopMotionUpdates()
        
        if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
            DDLogInfo("Ending GatherSensorData background task!")
            
            UIApplication.sharedApplication().endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        }
    }
    
    func gatherSensorData(toSensorDataCollection sensorDataCollection:SensorDataCollection) {
        if (self.backgroundTaskID == UIBackgroundTaskInvalid) {
            DDLogInfo("Beginning GatherSensorData background task!")
            self.backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
                DDLogInfo("GatherSensorData Background task expired!")
                self.backgroundTaskID = UIBackgroundTaskInvalid
            })
        }
        
        self.isGatheringMotionData = true
        
        self.motionManager.startAccelerometerUpdatesToQueue(self.motionQueue) { (data, error) in
            guard let accelerometerData = data else {
                return
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                sensorDataCollection.addAccelerometerData(accelerometerData)
            }
        }
    }
    
    private func stopMotionUpdates() {
        self.motionManager.stopAccelerometerUpdates()
        
        if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
            DDLogInfo("Ending background task with Stop Motion Updates!")
            
            UIApplication.sharedApplication().endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        }
    }
    
    func queryCurrentActivityType(forSensorDataCollection sensorDataCollection:SensorDataCollection, withHandler handler: (sensorDataCollection: SensorDataCollection) -> Void!) {
        if (self.backgroundTaskID == UIBackgroundTaskInvalid) {
            DDLogInfo("Beginning Query Activity Type background task!")
            self.backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
                DDLogInfo("Query Activity Type Background task expired!")
    	        sensorDataCollection.addUnknownTypePrediction()
	            handler(sensorDataCollection: sensorDataCollection)
                self.backgroundTaskID = UIBackgroundTaskInvalid
            })
        } else {
            DDLogInfo("Could not query activity type, background task already in process!")
            sensorDataCollection.addUnknownTypePrediction()
            handler(sensorDataCollection: sensorDataCollection)
            return
        }

        sensorDataCollection.isBeingCollected = true
        
        let completionBlock = {
            guard sensorDataCollection.isBeingCollected else {
                // avoid possible race condition where completion block could be called after we have already finished
                return
            }
            
            if sensorDataCollection.accelerometerAccelerations.count >= MotionManager.sampleWindowSize
            {
                sensorDataCollection.isBeingCollected = false
                self.stopMotionUpdates()
                
                RandomForestManager.sharedForest.classify(sensorDataCollection)
                handler(sensorDataCollection: sensorDataCollection)
            }
        }
            
        self.motionManager.startAccelerometerUpdatesToQueue(self.motionQueue) { (motion, error) in
            guard error == nil else {
                DDLogInfo("Error reading accelerometer data! Ending early…")
                sensorDataCollection.isBeingCollected = false
                self.stopMotionUpdates()
                
                sensorDataCollection.addUnknownTypePrediction()
                handler(sensorDataCollection: sensorDataCollection)

                return
            }
            
            guard let accelerometerAcceleration = motion else {
                return
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                sensorDataCollection.addAccelerometerData(accelerometerAcceleration)
                completionBlock()
            }
        }
    }
}
