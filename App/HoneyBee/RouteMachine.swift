//
//  RouteMachine.swift
//  HoneyBee
//
//  Created by William Henderson on 10/27/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreLocation
import CoreMotion

class RouteMachine : NSObject, CLLocationManagerDelegate {
    let distanceFilter : Double = 30
    let locationTrackingDeferralTimeout : NSTimeInterval = 120
    
    private var isDefferringLocationUpdates : Bool = false
    
    private var isInLowPowerState : Bool = false
    
    private var locationManager : CLLocationManager!
    private var lastMovingLocation :  CLLocation!
    private var stoppedMovingLocation :  CLLocation!
    
    private var motionActivityManager : CMMotionActivityManager!
    private var motionQueue : NSOperationQueue!
    private var motionCheckStartDate : NSDate!
    let motionStartTimeoutInterval : NSTimeInterval = 30
    let motionContinueTimeoutInterval : NSTimeInterval = 60
    
    internal private(set) var currentTrip : Trip!
    
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedMachine : RouteMachine?
    }
    
    
    class var sharedMachine:RouteMachine {
        dispatch_once(&Static.onceToken) {
            Static.sharedMachine = RouteMachine()
        }
        
        return Static.sharedMachine!
    }
    
    override init () {
        self.locationManager = CLLocationManager()
        self.locationManager.activityType = CLActivityType.AutomotiveNavigation
        self.locationManager.pausesLocationUpdatesAutomatically = false
        self.locationManager.disallowDeferredLocationUpdates()
        
        self.motionQueue = NSOperationQueue.mainQueue()
        self.motionActivityManager = CMMotionActivityManager()

        super.init()
    }
    
    func startup () {
        self.locationManager.delegate = self;
        self.locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - State Machine
    
    func startActiveTracking() {
        if (self.currentTrip != nil) {
            return
        }
        
        #if DEBUG
            let notif = UILocalNotification()
            notif.alertBody = "Starting Active Tracking"
            notif.category = "RIDE_COMPLETION_CATEGORY"
            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
        #endif
        
        DDLogWrapper.logInfo("Starting Active Tracking")
        
        self.currentTrip = Trip()
        CoreDataController.sharedCoreDataController.saveContext()
        
        if (self.stoppedMovingLocation != nil) {
            // set up the stoppedMovingLocation as the first location in thr trip
            let newLocation = Location(location: self.stoppedMovingLocation!, trip: self.currentTrip)
        }
        
        CoreDataController.sharedCoreDataController.saveContext()
        
        self.stoppedMovingLocation = nil
        self.lastMovingLocation = nil
        
        self.enterHighPowerState()
    }
    
    func stopActivelyTrackingIfNeeded() {
        if (self.currentTrip == nil) {
            return
        }

        
        let notif = UILocalNotification()
        notif.alertBody = "🚴💨 You biked 1.5 miles from Lower Burnside -> Downtown. What'd you think?"
        notif.category = "RIDE_COMPLETION_CATEGORY"
        UIApplication.sharedApplication().presentLocalNotificationNow(notif)
        
        DDLogWrapper.logInfo("Stopping Active Tracking")
        
        if (self.currentTrip != nil && self.currentTrip.locations.count == 0) {
            // if it is an empty trip, don't save it.
            CoreDataController.sharedCoreDataController.currentManagedObjectContext().deleteObject(self.currentTrip)
        }
        
        self.currentTrip = nil
        self.enterLowPowerState()
    }
    
    func enterLowPowerState() {
        DDLogWrapper.logInfo("Entering low power state")
        
        self.locationManager.distanceFilter = 50
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.isInLowPowerState = true
    }
    
    func enterHighPowerState() {
        DDLogWrapper.logInfo("Entering HIGH power state")
        
        self.locationManager.distanceFilter = 10
        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        
        self.isInLowPowerState = false
    }
    
//    func startDeferringUpdates() {
//        if (!self.isDefferringLocationUpdates) {
//            self.locationManager.distanceFilter = 8 // must be set to none for deferred location updates
//            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest // // must be set to best for deferred location updates
//            
//            DDLogWrapper.logVerbose("Started deferring updates")
//            
//            self.isDefferringLocationUpdates = true
//            self.locationManager.allowDeferredLocationUpdatesUntilTraveled(CLLocationDistanceMax, timeout: self.locationTrackingDeferralTimeout)
//        }
//    }
//    
//    func stopDeferringUpdates() {
//        self.locationManager.disallowDeferredLocationUpdates()
//        
//        self.locationManager.distanceFilter = kCLDistanceFilterNone
//        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
//    }

    // MARK: - CLLocationManger
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        DDLogWrapper.logVerbose("Did change authorization status")
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.Authorized) {
            self.enterLowPowerState()
            self.locationManager.startUpdatingLocation()
            #if (arch(i386) || arch(x86_64)) && os(iOS)
                // simulator.
            #endif
        } else {
            // tell the user they need to give us access to the zion mainframes
            DDLogWrapper.logVerbose("Not authorized for location access!")
        }
    }
    
    func locationManagerDidPauseLocationUpdates(manager: CLLocationManager!) {
        DDLogWrapper.logVerbose("Did Pause location updates!")
    }
    
    func locationManagerDidResumeLocationUpdates(manager: CLLocationManager!) {
        DDLogWrapper.logVerbose("Did Resume location updates!")
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        DDLogWrapper.logError(NSString(format: "Got active tracking location error! %@", error))
    }
    
    func locationManager(manager: CLLocationManager!, didFinishDeferredUpdatesWithError error: NSError!) {
        DDLogWrapper.logVerbose("Finished deferring updates")

        self.isDefferringLocationUpdates = false
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [CLLocation]!) {
        if (self.currentTrip != nil) {
            for location in locations {
                DDLogWrapper.logVerbose(NSString(format: "Location Speed: %f", location.speed))
                if (location.speed < 0 || location.speed > 1) {
                    // if the speed is above 1 meters per second, keep tracking
                    DDLogWrapper.logVerbose("Got new active tracking location")
                    
                    self.lastMovingLocation = location
                    Location(location: location as CLLocation, trip: self.currentTrip)
                } else {
                    DDLogWrapper.logVerbose("Moving slow, ignoring location point")
                }
            }
            
            if ((self.lastMovingLocation != nil && abs(self.lastMovingLocation.timestamp.timeIntervalSinceNow) > 40.0)){
                // otherwise, check the acceleromtere for recent data
                DDLogWrapper.logVerbose("Moving too slow for too long")
                self.stoppedMovingLocation = locations[0]
                self.stopActivelyTrackingIfNeeded()
            } else {
                CoreDataController.sharedCoreDataController.saveContext()
                NSNotificationCenter.defaultCenter().postNotificationName("RouteMachineDidUpdatePoints", object: nil)
            }
        } else if (self.isInLowPowerState) {
            var foundMovement = false
            for location in locations {
                DDLogWrapper.logVerbose(NSString(format: "Location Speed: %f", location.speed))
                if (location.speed > 1) {
                    // if the speed is above 1 meters per second, start tracking
                    DDLogWrapper.logVerbose("Found movement while in low power state")
                    foundMovement = true
                    break
                }
            }
            
            if (foundMovement) {
                self.startActiveTracking()
                
                for location in locations {
                    Location(location: location as CLLocation, trip: self.currentTrip)
                }
            } else {
               DDLogWrapper.logVerbose("Did NOT find movement while in low power state")
            }
        } else {
            DDLogWrapper.logVerbose("Skipped location update!")
        }
    }
    
    func queryMotionActivity(starting: NSDate!, toDate: NSDate!, withHandler handler: CMMotionActivityQueryHandler!) {
        self.motionActivityManager.queryActivityStartingFromDate(starting, toDate: toDate, toQueue: self.motionQueue, withHandler: handler)
    }
}