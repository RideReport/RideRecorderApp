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
    let locationTrackingDeferralTimeout : NSTimeInterval = 30
    let acceptableLocationAccuracy = kCLLocationAccuracyNearestTenMeters * 3
    
    var startedInBackground = false
    
    private var shouldDeferUpdates = false
    private var isDefferringLocationUpdates : Bool = false

    private var locationManagerIsUpdating : Bool = false
    private var isInLowPowerState : Bool = false
    private var lowPowerReadingsCount = 0
    
    private var locationManager : CLLocationManager!
    private var lastLowPowerLocation :  CLLocation!
    private var lastMovingLocation :  CLLocation!
    private var stoppedMovingLocation :  CLLocation!
    
    private var motionActivityManager : CMMotionActivityManager!
    private var motionQueue : NSOperationQueue!
    private var motionCheckStartDate : NSDate!
    let motionStartTimeoutInterval : NSTimeInterval = 30
    let motionContinueTimeoutInterval : NSTimeInterval = 60
    
    internal private(set) var currentTrip : Trip?
    
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
        
        self.motionQueue = NSOperationQueue()
        self.motionActivityManager = CMMotionActivityManager()

        super.init()
    }
    
    func startup(startingFromBackground: Bool) {
        if (startingFromBackground) {
            let notif = UILocalNotification()
            notif.alertBody = "You must launch Ride to start logging again."
            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
        }
        
        self.startedInBackground = startingFromBackground
        self.locationManager.delegate = self;
        self.locationManager.requestAlwaysAuthorization()
        let hasRequestedMotionAccess = NSUserDefaults.standardUserDefaults().boolForKey("RouteMachineHasRequestedMotionAccess")
        if (!hasRequestedMotionAccess) {
            // grab an update for a second so we can have the permission dialog come up right away
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.motionActivityManager.startActivityUpdatesToQueue(self.motionQueue, withHandler: { (activity) -> Void in
                    self.motionActivityManager.stopActivityUpdates()
                    NSUserDefaults.standardUserDefaults().setBool(true, forKey: "RouteMachineHasRequestedMotionAccess")
                })
            })
        }
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
            // set up the stoppedMovingLocation as the first location in the trip
            if (self.stoppedMovingLocation.horizontalAccuracy <= self.acceptableLocationAccuracy) {
                let newLocation = Location(location: self.stoppedMovingLocation!, trip: self.currentTrip!)
                
                // but give it a recent date.
                newLocation.date = NSDate()   
            }
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
        
        DDLogWrapper.logInfo("Stopping Active Tracking")
        
        if (self.currentTrip!.locations.count <= 6) {
            // if it doesn't more than 6 points, toss it.
            #if DEBUG
                let notif = UILocalNotification()
                notif.alertBody = "Canceled Trip"
                notif.category = "RIDE_COMPLETION_CATEGORY"
                UIApplication.sharedApplication().presentLocalNotificationNow(notif)
            #endif
            CoreDataController.sharedCoreDataController.currentManagedObjectContext().deleteObject(self.currentTrip!)
        } else {
            let closingTrip = self.currentTrip
            closingTrip!.closeTrip()
            closingTrip!.clasifyActivityType({ () -> Void in
                closingTrip!.sendTripCompletionNotification()
            })
        }
        
        self.currentTrip = nil
    }
    
    func isPaused() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey("RouteMachineIsPaused")
    }
    
    func pauseTracking() {
        if (isPaused()) {
            return
        }
        
        DDLogWrapper.logInfo("Paused Tracking")
        
        self.locationManager.stopUpdatingLocation()
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "RouteMachineIsPaused")
    }
    
    func resumeTracking() {
        if (!isPaused()) {
            return
        }
        
        DDLogWrapper.logInfo("Resume Tracking")
        
        NSUserDefaults.standardUserDefaults().setBool(false, forKey: "RouteMachineIsPaused")
    }
    
    func enterLowPowerState() {
        if (isPaused()) {
            DDLogWrapper.logInfo("Tracking is Paused, not enterign low power state")
            
            if (self.locationManagerIsUpdating) {
                self.locationManager.stopUpdatingLocation()
            }
            
            return
        } else if (!self.locationManagerIsUpdating) {
            self.locationManagerIsUpdating = true
            self.locationManager.startUpdatingLocation()
        }
        
        DDLogWrapper.logInfo("Entering low power state")
        DDLogWrapper.logInfo(NSString(format: "Current Battery Level: %.0f", UIDevice.currentDevice().batteryLevel * 100))
        
        self.locationManager.distanceFilter = 100
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        if (!self.isInLowPowerState) {
            self.lowPowerReadingsCount = 0
            self.isInLowPowerState = true
        }
        self.lastLowPowerLocation = nil
        
        self.locationManager.disallowDeferredLocationUpdates()
    }
    
    func enterHighPowerState() {
        if (isPaused()) {
            DDLogWrapper.logInfo("Tracking is Paused, not enterign high power state")
            
            if (self.locationManagerIsUpdating) {
                self.locationManager.stopUpdatingLocation()
            }
            
            return
        } else if (!self.locationManagerIsUpdating) {
            self.locationManagerIsUpdating = true
            self.locationManager.startUpdatingLocation()
        }
        
        DDLogWrapper.logInfo("Entering HIGH power state")
        DDLogWrapper.logInfo(NSString(format: "Current Battery Level: %.0f", UIDevice.currentDevice().batteryLevel * 100))

        if (self.shouldDeferUpdates) {
            self.locationManager.distanceFilter = kCLDistanceFilterNone
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            
            self.isDefferringLocationUpdates = true
            self.locationManager.allowDeferredLocationUpdatesUntilTraveled(CLLocationDistanceMax, timeout: self.locationTrackingDeferralTimeout)
        } else {
            self.locationManager.distanceFilter = 20
            self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }
        
        self.isInLowPowerState = false
    }

    // MARK: - CLLocationManger
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        DDLogWrapper.logVerbose("Did change authorization status")
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.Authorized) {
            self.locationManager.startMonitoringSignificantLocationChanges()
            #if (arch(i386) || arch(x86_64)) && os(iOS)
                self.startActiveTracking()
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
        if (error.code == CLError.Denied.rawValue) {
            // alert the user and pause tracking.
        }
    }
    
    func locationManager(manager: CLLocationManager!, didFinishDeferredUpdatesWithError error: NSError!) {
        DDLogWrapper.logVerbose("Finished deferring updates")

        self.isDefferringLocationUpdates = false
        if (self.shouldDeferUpdates && self.isInLowPowerState && self.currentTrip != nil) {
            // if we are still tracking a route, continue deferring.
            self.isDefferringLocationUpdates = true
            self.locationManager.allowDeferredLocationUpdatesUntilTraveled(CLLocationDistanceMax, timeout: self.locationTrackingDeferralTimeout)
        }
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [CLLocation]!) {
        if (self.currentTrip != nil) {
            
            var foundNonNegativeSpeed = false
            
            for location in locations {
                DDLogWrapper.logVerbose(NSString(format: "Location Speed: %f", location.speed))
                if (location.speed > 0) {
                    foundNonNegativeSpeed = true
                }
                
                if (location.speed > 3) {
                    // if the speed is above 3 meters per second, keep tracking
                    DDLogWrapper.logVerbose("Got new active tracking location")
                    
                    self.lastMovingLocation = location
                    if (location.horizontalAccuracy <= self.acceptableLocationAccuracy) {
                        Location(location: location as CLLocation, trip: self.currentTrip!)
                    }
                }
            }
            
            #if (arch(i386) || arch(x86_64)) && os(iOS)
                foundNonNegativeSpeed = true
                self.lastMovingLocation = locations.first
                Location(location: self.lastMovingLocation as CLLocation, trip: self.currentTrip!)
            #endif
            
            if (foundNonNegativeSpeed == true && (self.lastMovingLocation != nil && abs(self.lastMovingLocation.timestamp.timeIntervalSinceNow) > 60.0)){
                // otherwise, check the acceleromtere for recent data
                DDLogWrapper.logVerbose("Moving too slow for too long")
                self.stoppedMovingLocation = locations[0]
                self.stopActivelyTrackingIfNeeded()
            } else if (foundNonNegativeSpeed == false) {
                if (self.lastMovingLocation != nil && abs(self.lastMovingLocation.timestamp.timeIntervalSinceNow) > 100.0) {
                    DDLogWrapper.logVerbose("Went too long with negative speeds.")
                    self.stoppedMovingLocation = locations[0]
                    self.stopActivelyTrackingIfNeeded()
                } else {
                    DDLogWrapper.logVerbose("Nothing but negative speeds. Awaiting next update")
                }
            } else {
                CoreDataController.sharedCoreDataController.saveContext()
                NSNotificationCenter.defaultCenter().postNotificationName("RouteMachineDidUpdatePoints", object: nil)
            }
        } else if (self.isInLowPowerState) {
            self.lowPowerReadingsCount += 1
            
            var foundMovement = false
            for location in locations {
                DDLogWrapper.logVerbose(NSString(format: "Location Speed: %f", location.speed))
                if (location.speed > 3) {
                    // if the speed is above 3 meters per second, start tracking
                    DDLogWrapper.logVerbose("Found movement while in low power state")
                    foundMovement = true
                    break
                }
            }
            
            let newLocation = locations.first
            if (foundMovement == false && self.lastLowPowerLocation != nil && newLocation != nil) {
                let distance = self.lastLowPowerLocation.distanceFromLocation(newLocation)
                let time = newLocation?.timestamp.timeIntervalSinceDate(self.lastLowPowerLocation.timestamp)
                
                let speed = distance/time!
                DDLogWrapper.logVerbose(NSString(format: "Manually found speed: %f", speed))
                
                if (speed > 3 && speed < 20) {
                    DDLogWrapper.logVerbose("Found movement while in low power state via manual speed!")
                    foundMovement = true
                }
            }
            
            self.lastLowPowerLocation = newLocation
            
            if (foundMovement) {
                self.startActiveTracking()
                
                for location in locations {
                    if (location.horizontalAccuracy <= self.acceptableLocationAccuracy) {
                        Location(location: location as CLLocation, trip: self.currentTrip!)
                    }
                }
            } else {
                DDLogWrapper.logVerbose("Did NOT find movement while in low power state")
                if (self.lowPowerReadingsCount > 10) {
                    DDLogWrapper.logVerbose("Max low power readings exceeded, stopping!")
                    self.locationManager.stopUpdatingLocation()
                } else {
                    DDLogWrapper.logVerbose("Taking more low power readings.")
                }
            }
        } else {
            DDLogWrapper.logVerbose("Got significant location update, entering low power state.")
            self.enterLowPowerState()
        }
    }
    
    func queryMotionActivity(starting: NSDate!, toDate: NSDate!, withHandler handler: CMMotionActivityQueryHandler!) {
        self.motionActivityManager.queryActivityStartingFromDate(starting, toDate: toDate, toQueue: self.motionQueue, withHandler: handler)
    }
}