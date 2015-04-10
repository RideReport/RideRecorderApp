//
//  MotionManager.swift
//  Ride
//
//  Created by William Henderson on 10/27/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreLocation
import CoreMotion

class MotionManager : NSObject, CLLocationManagerDelegate {
    private var motionActivityManager : CMMotionActivityManager!
    private var motionQueue : NSOperationQueue!
    private var motionCheckStartDate : NSDate!
    let motionStartTimeoutInterval : NSTimeInterval = 30
    let motionContinueTimeoutInterval : NSTimeInterval = 60
    
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedManager : MotionManager?
    }
    
    
    class var sharedManager:MotionManager {
        dispatch_once(&Static.onceToken) {
            Static.sharedManager = MotionManager()
        }
        
        return Static.sharedManager!
    }
    
    override init () {
        super.init()
        
        self.motionQueue = NSOperationQueue()
        self.motionActivityManager = CMMotionActivityManager()
    }
    
    func startup() {
        let hasRequestedMotionAccess = NSUserDefaults.standardUserDefaults().boolForKey("MotionManagerHasRequestedMotionAccess")
        if (!hasRequestedMotionAccess) {
            // grab an update for a second so we can have the permission dialog come up right away
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.motionActivityManager.startActivityUpdatesToQueue(self.motionQueue, withHandler: { (activity) -> Void in
                    self.motionActivityManager.stopActivityUpdates()
                    NSUserDefaults.standardUserDefaults().setBool(true, forKey: "MotionManagerHasRequestedMotionAccess")
                    NSUserDefaults.standardUserDefaults().synchronize()
                })
            })
        }
    }
    
    func queryMotionActivity(starting: NSDate!, toDate: NSDate!, withHandler handler: CMMotionActivityQueryHandler!) {
        self.motionActivityManager.queryActivityStartingFromDate(starting, toDate: toDate, toQueue: self.motionQueue, withHandler: handler)
    }
}