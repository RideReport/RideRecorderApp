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

    let sampleWindowSize: Int = 128
    private let deviceMotionUpdateInterval: NSTimeInterval = 50/1000
    private var isMonitoringMotion: Bool = false
    
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
        self.motionManager.deviceMotionUpdateInterval = self.deviceMotionUpdateInterval
        
        self.randomForestManager = RandomForestManager(sampleSize: self.sampleWindowSize)
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
    
    private func magnitudeVector(fromSample sample:DeviceMotionsSample)->[Float] {
        var mags: [Float] = []
        
        for elem in sample.deviceMotions {
            let reading = elem as! DeviceMotion
            let sum = reading.userAccelerationX.floatValue*reading.userAccelerationX.floatValue + reading.userAccelerationY.floatValue*reading.userAccelerationY.floatValue + reading.userAccelerationZ.floatValue*reading.userAccelerationZ.floatValue
            mags.append(sqrtf(sum))
        }
        
        return mags
    }
    
    func queryCurrentActivityType(forDeviceMotionSample sample:DeviceMotionsSample, withHandler handler: (activityType: Trip.ActivityType, confidence: Double) -> Void!) {
        self.backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
            handler(activityType: .Unknown, confidence: 1.0)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        })

        self.isMonitoringMotion = true
            
        self.motionManager.startDeviceMotionUpdatesToQueue(self.motionQueue) { (motion, error) in
            guard let deviceMotion = motion else {
                return
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                sample.addDeviceMotion(deviceMotion)
                if sample.deviceMotions.count >= self.sampleWindowSize {
                    self.isMonitoringMotion = false
                    self.motionManager.stopDeviceMotionUpdates()
                    // run classification
                    var magVector = self.magnitudeVector(fromSample: sample)
                    let sampleClass = self.randomForestManager.classifyMagnitudeVector(&magVector)
                    
                    handler(activityType: Trip.ActivityType(rawValue: Int16(sampleClass))!, confidence: 1.0)
                    if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
                        UIApplication.sharedApplication().endBackgroundTask(self.backgroundTaskID)
                        self.backgroundTaskID = UIBackgroundTaskInvalid
                    }
                }
            }
        }
    }
    
    func queryMotionActivity(starting: NSDate!, toDate: NSDate!, withHandler handler: CMMotionActivityQueryHandler!) {
        self.motionActivityManager.queryActivityStartingFromDate(starting, toDate: toDate, toQueue: self.motionQueue, withHandler: handler)
    }
}