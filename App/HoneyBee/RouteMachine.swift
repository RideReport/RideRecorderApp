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
    let locationTrackingDeferralTimeout : NSTimeInterval = 60
    let acceptableLocationAccuracy = kCLLocationAccuracyNearestTenMeters * 3
    let minimumBatteryForTracking : Float = 0.2
    
    var startedInBackground = false
    
    private var shouldDeferUpdates = true
    private var isDefferringLocationUpdates : Bool = false

    private var locationManagerIsUpdating : Bool = false
    private var isInLowPowerState : Bool = false
    private var lowPowerReadingsCount = 0
    
    private var locationManager : CLLocationManager!
    private var lastLowPowerLocation :  CLLocation!
    private var lastMovingLocation :  CLLocation!
    
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
        super.init()
        
        self.locationManager = CLLocationManager()
        self.locationManager.activityType = CLActivityType.AutomotiveNavigation
        self.locationManager.pausesLocationUpdatesAutomatically = false
        
        self.motionQueue = NSOperationQueue()
        self.motionActivityManager = CMMotionActivityManager()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "appDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    func appDidBecomeActive() {
        if (self.currentTrip != nil && self.lastMovingLocation != nil && abs(self.lastMovingLocation.timestamp.timeIntervalSinceNow) > 100.0) {
            // if the app becomes active, check to see if we should wrap up a trip.
            DDLogWrapper.logVerbose("Ending trip after app became activate.")
            self.stopTripIfNeeded()
        }
    }
    
    func startup(startingFromBackground: Bool) {
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
                    NSUserDefaults.standardUserDefaults().synchronize()
                })
            })
        }
    }
    
    // MARK: - State Machine
    
    func startTripFromLocation(fromLocation: CLLocation) {
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
        self.currentTrip?.batteryAtStart = NSNumber(short: Int16(UIDevice.currentDevice().batteryLevel * 100))
        CoreDataController.sharedCoreDataController.saveContext()
        
        // initialize lastMovingLocation to fromLocation, where the movement started
        self.lastMovingLocation = fromLocation
        
        // set up the lastMovingLocation as the first location in the trip
        if (self.lastMovingLocation.horizontalAccuracy <= self.acceptableLocationAccuracy) {
            let newLocation = Location(location: self.lastMovingLocation!, trip: self.currentTrip!)
            
            // but give it a recent date.
            newLocation.date = NSDate()
        }
        
        CoreDataController.sharedCoreDataController.saveContext()
        
        self.enterHighPowerState()
    }
    
    func stopTripIfNeeded() {
        if (self.currentTrip == nil) {
            return
        }
        
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
            closingTrip!.batteryAtEnd = NSNumber(short: Int16(UIDevice.currentDevice().batteryLevel * 100))
            DDLogWrapper.logInfo(NSString(format: "Battery Life Used: %d", closingTrip!.batteryLifeUsed()))
            
            closingTrip!.closeTrip()
            closingTrip!.clasifyActivityType({ () -> Void in
                closingTrip!.sendTripCompletionNotification()
            })
        }
        
        self.currentTrip = nil
        self.enterLowPowerState()
    }
    
    func isPausedDueToBatteryLife() -> Bool {
        return UIDevice.currentDevice().batteryLevel < self.minimumBatteryForTracking
    }
    
    func isPaused() -> Bool {
        return self.isPausedDueToBatteryLife() || self.isPausedByUser()
    }
    
    func isPausedByUser() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey("RouteMachineIsPaused")
    }
    
    func pauseTracking() {
        if (isPaused()) {
            return
        }
        
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "RouteMachineIsPaused")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        DDLogWrapper.logInfo("Paused Tracking")
        self.stopActiveTracking()
        self.locationManager.stopMonitoringSignificantLocationChanges()
    }
    
    func resumeTracking() {
        if (!isPaused()) {
            return
        }
        
        NSUserDefaults.standardUserDefaults().setBool(false, forKey: "RouteMachineIsPaused")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        DDLogWrapper.logInfo("Resume Tracking")
        self.enterLowPowerState()
        self.locationManager.startMonitoringSignificantLocationChanges()
    }
    
    func stopActiveTracking() {
        DDLogWrapper.logInfo("Stopping Tracking")

        self.locationManagerIsUpdating = false
        self.locationManager.stopUpdatingLocation()
    }
    
    func enterLowPowerState() {
        if (isPaused()) {
            DDLogWrapper.logInfo("Tracking is Paused, not enterign low power state")
            
            return
        } else if (!self.locationManagerIsUpdating) {
            self.locationManagerIsUpdating = true
            self.locationManager.startUpdatingLocation()
        }
        
        DDLogWrapper.logInfo("Entering low power state")
        
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
            
            return
        } else if (!self.locationManagerIsUpdating) {
            self.locationManagerIsUpdating = true
            self.locationManager.startUpdatingLocation()
        }
        
        DDLogWrapper.logInfo("Entering HIGH power state")

        if (self.shouldDeferUpdates) {
            DDLogWrapper.logInfo("Deferring updates!")
            self.locationManager.distanceFilter = kCLDistanceFilterNone
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            
            self.isDefferringLocationUpdates = true
            self.locationManager.allowDeferredLocationUpdatesUntilTraveled(CLLocationDistanceMax, timeout: self.locationTrackingDeferralTimeout)
        } else {
            DDLogWrapper.logInfo("Not deferring updates")
            self.locationManager.distanceFilter = 20
            self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }
        
        self.isInLowPowerState = false
    }

    // MARK: - CLLocationManger
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        DDLogWrapper.logVerbose("Did change authorization status")
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.Authorized) {
            self.enterLowPowerState()
            self.locationManager.startMonitoringSignificantLocationChanges()
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
        DDLogWrapper.logVerbose("Finished deferring updates!")
        if (error != nil) {
            DDLogWrapper.logVerbose(NSString(format: "Error deferring: %@", error))
        }

        self.isDefferringLocationUpdates = false
        if (self.shouldDeferUpdates && !self.isInLowPowerState && self.currentTrip != nil) {
            // if we are still tracking a route, continue deferring.
            DDLogWrapper.logVerbose("Re-deferring updates")

            self.isDefferringLocationUpdates = true
            self.locationManager.allowDeferredLocationUpdatesUntilTraveled(CLLocationDistanceMax, timeout: self.locationTrackingDeferralTimeout)
        }
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [CLLocation]!) {
        if (UIDevice.currentDevice().batteryLevel < self.minimumBatteryForTracking)  {
            if (self.locationManagerIsUpdating) {
                // if we are currently updating, send the user a push and stop.
                let notif = UILocalNotification()
                notif.alertBody = "Whoa, your battery is pretty low. Ride will stop running until you get a charge!"
                UIApplication.sharedApplication().presentLocalNotificationNow(notif)
                
                DDLogWrapper.logInfo("Paused Tracking due to battery life")
                
                self.stopActiveTracking()
            }

            return
        }
        
        DDLogWrapper.logVerbose("Received location updates.")
        
        if (self.currentTrip != nil) {
            
            var foundNonNegativeSpeed = false
            
            for location in locations {
                DDLogWrapper.logVerbose(NSString(format: "Location found for trip. Speed: %f", location.speed))
                if (location.speed > 0) {
                    foundNonNegativeSpeed = true
                }
                
                if (location.speed > 3) {
                    // if the speed is above 3 meters per second, keep tracking
                    
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
                self.stopTripIfNeeded()
            } else if (foundNonNegativeSpeed == false) {
                if (self.lastMovingLocation != nil && abs(self.lastMovingLocation.timestamp.timeIntervalSinceNow) > 100.0) {
                    DDLogWrapper.logVerbose("Went too long with negative speeds.")
                    self.stopTripIfNeeded()
                } else {
                    if (self.lastMovingLocation == nil) {
                        DDLogWrapper.logVerbose("lastMovingLocation is nil, should not be!")
                    }
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
                DDLogWrapper.logVerbose(NSString(format: "Location found in low power mode. Speed: %f", location.speed))
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
                self.startTripFromLocation(self.lastLowPowerLocation)
                
                for location in locations {
                    if (location.horizontalAccuracy <= self.acceptableLocationAccuracy) {
                        Location(location: location as CLLocation, trip: self.currentTrip!)
                    }
                }
            } else {
                DDLogWrapper.logVerbose("Did NOT find movement while in low power state")
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