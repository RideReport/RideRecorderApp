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
    private var motionActivityManager : CMMotionActivityManager!
    private var motionQueue : NSOperationQueue!
    private var motionCheckStartDate : NSDate!
    let motionStartTimeoutInterval : NSTimeInterval = 30
    let motionContinueTimeoutInterval : NSTimeInterval = 60
    
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
    
    func queryMotionActivity(starting: NSDate!, toDate: NSDate!, withHandler handler: CMMotionActivityQueryHandler!) {
        self.motionActivityManager.queryActivityStartingFromDate(starting, toDate: toDate, toQueue: self.motionQueue, withHandler: handler)
    }
}