//
//  RouteMachine.swift
//  Ride
//
//  Created by William Henderson on 10/27/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreLocation
import CoreMotion

class RouteMachine : NSObject, CLLocationManagerDelegate {
    var minimumSpeedToContinueMonitoring : CLLocationSpeed = 3.0 // ~6.7mph
    var minimumSpeedToStartMonitoring : CLLocationSpeed = 4.4 // ~10mph
    
    let locationTrackingDeferralTimeout : NSTimeInterval = 120
    let routeResumeTimeout : NSTimeInterval = 240
    let acceptableLocationAccuracy = kCLLocationAccuracyNearestTenMeters * 3
    
    let geofenceSleepRegionRadius : Double = 80
    private var geofenceSleepRegion :  CLCircularRegion!
    
    let maximumTimeIntervalBetweenMovements : NSTimeInterval = 60
    let maximumTimeIntervalBetweenPositiveSpeedReadings : NSTimeInterval = 60

    let minimumLowPowerReadingsCountWithMovementToTriggerTrip = 3
    let maximumLowPowerReadingsCountWithoutMovement = 10
    
    let minimumBatteryForTracking : Float = 0.2
    
    private var isDefferringLocationUpdates : Bool = false
    private var locationManagerIsUpdating : Bool = false
    private var isInLowPowerState : Bool = false
    private var lowPowerReadingsWithMotion = 0
    private var lowPowerReadingsWithoutMotionCount = 0
    
    private var lastLowPowerLocation :  CLLocation?
    private var lastMovingLocation :  CLLocation?
    
    private var locationManager : CLLocationManager!
    
    internal private(set) var currentTrip : Trip?
    
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedMachine : RouteMachine?
    }
    
    //
    // MARK: - Initializers
    //
    
    class var sharedMachine:RouteMachine {
        dispatch_once(&Static.onceToken) {
            Static.sharedMachine = RouteMachine()
        }
        
        return Static.sharedMachine!
    }
    
    override init () {
        super.init()
        
        UIDevice.currentDevice().batteryMonitoringEnabled = true
        
        self.locationManager = CLLocationManager()
        self.locationManager.activityType = CLActivityType.Fitness
        self.locationManager.pausesLocationUpdatesAutomatically = false
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "appDidBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    func appDidBecomeActive() {
        if (self.currentTrip != nil && abs(self.lastMovingLocation!.timestamp.timeIntervalSinceNow) > 100.0) {
            // if the app becomes active, check to see if we should wrap up a trip.
            DDLogWrapper.logVerbose("Ending trip after app became activate.")
            self.stopTrip()
        }
    }
    
    func startup() {
        self.locationManager.delegate = self
        self.locationManager.requestAlwaysAuthorization()
    }
    
    //
    // MARK: - Private state machine methods
    //
    
    private func startTripFromLocation(fromLocation: CLLocation) {
        if (self.currentTrip != nil) {
            return
        }
        
        if (isPaused()) {
            DDLogWrapper.logInfo("Tracking is Paused, not starting trip")
            
            return
        }
        
        DDLogWrapper.logInfo("Starting Active Tracking")
        
        let mostRecentTrip = Trip.mostRecentTrip()
        
        // Resume the most recent trip if it was recent enough
        if (mostRecentTrip != nil && abs(mostRecentTrip.endDate.timeIntervalSinceNow) < self.routeResumeTimeout) {
            DDLogWrapper.logInfo("Resuming ride")
            #if DEBUG
                let notif = UILocalNotification()
                notif.alertBody = "Resumed Ride!"
                notif.category = "RIDE_COMPLETION_CATEGORY"
                UIApplication.sharedApplication().presentLocalNotificationNow(notif)
            #endif
            self.currentTrip = mostRecentTrip
            self.currentTrip?.reopen()
        } else {
            self.currentTrip = Trip()
            self.currentTrip?.batteryAtStart = NSNumber(short: Int16(UIDevice.currentDevice().batteryLevel * 100))
        }
        
        // initialize lastMovingLocation to fromLocation, where the movement started
        self.lastMovingLocation = fromLocation
        
        // Include lastMovingLocation in the trip if it's accurate enough
        if (self.lastMovingLocation!.horizontalAccuracy <= self.acceptableLocationAccuracy) {
            let newLocation = Location(location: self.lastMovingLocation!, trip: self.currentTrip!)
        }
        CoreDataController.sharedCoreDataController.saveContext()
        
        self.currentTrip?.sendTripStartedNotification()
        
        if (!self.locationManagerIsUpdating) {
            self.locationManagerIsUpdating = true
            self.locationManager.startUpdatingLocation()
        }
        
        if (CLLocationManager.deferredLocationUpdatesAvailable()) {
            DDLogWrapper.logInfo("Deferring updates!")
            self.locationManager.distanceFilter = kCLDistanceFilterNone
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        } else {
            DDLogWrapper.logInfo("Not deferring updates")
            self.locationManager.distanceFilter = 20
            self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }
        
        self.isInLowPowerState = false
    }
    
    private func stopTrip() {
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
            
            closingTrip!.close() {
                // don't sync it yet. wait until the user has rated the trip.
                CoreDataController.sharedCoreDataController.saveContext()
                closingTrip!.sendTripCompletionNotification()
            }
        }
        
        self.stopActiveMonitoring(self.lastMovingLocation)
        
        self.currentTrip = nil
        self.lastMovingLocation = nil
    }
    
    private func startLowPowerMonitoring() {
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
        self.locationManager.disallowDeferredLocationUpdates()
        
        if (!self.isInLowPowerState) {
            self.lowPowerReadingsWithMotion = 0
            self.lowPowerReadingsWithoutMotionCount = 0
            self.isInLowPowerState = true
        }
        self.lastLowPowerLocation = nil
    }
    
    private func disableAllGeofences() {
        for region in self.locationManager.monitoredRegions {
            self.locationManager.stopMonitoringForRegion(region as CLRegion)
        }
        
        self.geofenceSleepRegion = nil
    }
    
    private func stopActiveMonitoring(finalLocation: CLLocation?) {
        DDLogWrapper.logInfo("Stopping active monitoring")
        
        self.disableAllGeofences()
        
        if (finalLocation != nil) {
            #if DEBUG
                let notif = UILocalNotification()
                notif.alertBody = "Geofenced!"
                notif.category = "RIDE_COMPLETION_CATEGORY"
                UIApplication.sharedApplication().presentLocalNotificationNow(notif)
            #endif
            self.geofenceSleepRegion = CLCircularRegion(center:finalLocation!.coordinate, radius:self.geofenceSleepRegionRadius, identifier: "Movement Geofence")
            self.locationManager.startMonitoringForRegion(self.geofenceSleepRegion)
            DDLogWrapper.logInfo(NSString(format: "Set up geofence: %@!", self.geofenceSleepRegion))
        } else {
            DDLogWrapper.logInfo("Did not setup new geofence!")
        }
        
        self.locationManagerIsUpdating = false
        self.locationManager.disallowDeferredLocationUpdates()
        self.locationManager.stopUpdatingLocation()
    }
    
    
    private func beginDeferringUpdatesIfAppropriate() {
        if (CLLocationManager.deferredLocationUpdatesAvailable() && !self.isDefferringLocationUpdates && !self.isInLowPowerState && self.currentTrip != nil) {
            DDLogWrapper.logVerbose("Re-deferring updates")
            
            self.isDefferringLocationUpdates = true
            self.locationManager.allowDeferredLocationUpdatesUntilTraveled(CLLocationDistanceMax, timeout: self.locationTrackingDeferralTimeout)
        }
    }
    
    //
    // MARK: - Pause/Resuming Machine
    //
    
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
        self.disableAllGeofences()
        self.locationManager.stopMonitoringSignificantLocationChanges()
    }
    
    private func pauseTrackingDueToLowBatteryLife() {
        if (self.locationManagerIsUpdating) {
            // if we are currently updating, send the user a push and stop.
            let notif = UILocalNotification()
            notif.alertBody = "Whoa, your battery is pretty low. Ride will stop running until you get a charge!"
            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
            
            DDLogWrapper.logInfo("Paused Tracking due to battery life")
            
            self.stopActiveMonitoring(nil)
        }
    }
    
    func resumeTracking() {
        if (!isPaused()) {
            return
        }
        
        NSUserDefaults.standardUserDefaults().setBool(false, forKey: "RouteMachineIsPaused")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        DDLogWrapper.logInfo("Resume Tracking")
        self.locationManager.startMonitoringSignificantLocationChanges()
    }

    //
    // MARK: - CLLocationManger Delegate Methods
    //
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        DDLogWrapper.logVerbose("Did change authorization status")
        
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.Authorized) {
            self.locationManager.startMonitoringSignificantLocationChanges()
            self.startLowPowerMonitoring()
        } else {
            // tell the user they need to give us access to the zion mainframes
            DDLogWrapper.logVerbose("Not authorized for location access!")
        }
    }
    
    func locationManagerDidPauseLocationUpdates(manager: CLLocationManager!) {
        // Should never happen
        DDLogWrapper.logError("Did Pause location updates!")
    }
    
    func locationManagerDidResumeLocationUpdates(manager: CLLocationManager!) {
        // Should never happen
        DDLogWrapper.logError("Did Resume location updates!")
    }
    
    func locationManager(manager: CLLocationManager!, monitoringDidFailForRegion region: CLRegion!, withError error: NSError!) {
        DDLogWrapper.logError(NSString(format: "Got location monitoring error! %@", error))
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        DDLogWrapper.logError(NSString(format: "Got active tracking location error! %@", error))
        
        if (error.code == CLError.Denied.rawValue) {
            // alert the user and pause tracking.
        }
    }
    
    func locationManager(manager: CLLocationManager!, didFinishDeferredUpdatesWithError error: NSError!) {
        self.isDefferringLocationUpdates = false
        
        if (error != nil) {
            DDLogWrapper.logVerbose(NSString(format: "Error deferring updates: %@", error))
            return
        }

        DDLogWrapper.logVerbose("Finished deferring updates, redeffering.")

        // start deferring updates again.
        self.beginDeferringUpdatesIfAppropriate()
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [CLLocation]!) {
        DDLogWrapper.logVerbose("Received location updates.")

        if (UIDevice.currentDevice().batteryLevel < self.minimumBatteryForTracking)  {
            self.pauseTrackingDueToLowBatteryLife()
            return
        }
        
        self.beginDeferringUpdatesIfAppropriate()
        
        if (self.currentTrip != nil) {
            // We are current tracking a trip in high power mode
            
            var foundPositiveSpeed = false
            
            for location in locations {
                DDLogWrapper.logVerbose(NSString(format: "Location found for trip. Speed: %f", location.speed))
                if (location.speed > 0) {
                    foundPositiveSpeed = true
                }
                
                if (location.speed >= self.minimumSpeedToContinueMonitoring) {
                    self.lastMovingLocation = location
                    if (location.horizontalAccuracy <= self.acceptableLocationAccuracy) {
                        Location(location: location as CLLocation, trip: self.currentTrip!)
                    }
                }
            }
            
            if (foundPositiveSpeed == true && abs(self.lastMovingLocation!.timestamp.timeIntervalSinceNow) > self.maximumTimeIntervalBetweenMovements){
                DDLogWrapper.logVerbose("Moving too slow for too long")
                self.stopTrip()
            } else if (foundPositiveSpeed == false) {
                if (abs(self.lastMovingLocation!.timestamp.timeIntervalSinceNow) > self.maximumTimeIntervalBetweenPositiveSpeedReadings) {
                    DDLogWrapper.logVerbose("Went too long with non-positive speeds.")
                    self.stopTrip()
                } else {
                    DDLogWrapper.logVerbose("Nothing but non-positive speeds. Awaiting next update")
                }
            } else {
                CoreDataController.sharedCoreDataController.saveContext()
                NSNotificationCenter.defaultCenter().postNotificationName("RouteMachineDidUpdatePoints", object: nil)
            }
        } else if (self.isInLowPowerState) {
            // We are current considering starting a trip in low power mode
            
            var foundSufficientMovement = false
            
            for location in locations {
                DDLogWrapper.logVerbose(NSString(format: "Location found in low power mode. Speed: %f", location.speed))
                if (location.speed >= self.minimumSpeedToStartMonitoring) {
                    DDLogWrapper.logVerbose("Found movement while in low power state")
                    foundSufficientMovement = true
                    break
                }
                
                // Many times locations given in low power mode will not have a speed.
                // Hence, we also calculate a 'manual' speed from the current location to the last one
                if (self.lastLowPowerLocation != nil) {
                    let distance = self.lastLowPowerLocation!.distanceFromLocation(location)
                    let time = abs(location.timestamp.timeIntervalSinceDate(self.lastLowPowerLocation!.timestamp))
                    
                    let speed = distance/time
                    DDLogWrapper.logVerbose(NSString(format: "Manually found speed: %f", speed))
                    if (speed >= self.minimumSpeedToStartMonitoring && speed < 20.0) {
                        // We ignore really large speeds that may be the result of location inaccuracy
                        DDLogWrapper.logVerbose("Found movement while in low power state via manual speed!")
                        foundSufficientMovement = true
                    }
                }
            }
            
            self.lastLowPowerLocation = locations.first

            if (foundSufficientMovement) {
                self.lowPowerReadingsWithMotion += 1
                
                if(self.lowPowerReadingsWithMotion >= self.minimumLowPowerReadingsCountWithMovementToTriggerTrip) {
                    DDLogWrapper.logVerbose("Found enough motion in low power mode, triggers trip…")
                    self.startTripFromLocation(self.lastLowPowerLocation!)
                    
                    for location in locations {
                        if (location.horizontalAccuracy <= self.acceptableLocationAccuracy) {
                            Location(location: location as CLLocation, trip: self.currentTrip!)
                        }
                    }
                } else {
                    DDLogWrapper.logVerbose("Found motion in low power mode, awaiting further reads…")
                }
            } else {
                DDLogWrapper.logVerbose("Did NOT find movement while in low power state")
                self.lowPowerReadingsWithoutMotionCount += 1

                if (self.lowPowerReadingsWithoutMotionCount > self.maximumLowPowerReadingsCountWithoutMovement) {
                    DDLogWrapper.logVerbose("Max low power readings exceeded, stopping!")
                    self.stopActiveMonitoring(self.lastLowPowerLocation)
                }
            }
        } else {
            // We are currently in background mode and got course-scale movement.
            // We now enter a low power state to monitor for user movement
            DDLogWrapper.logVerbose("Got significant location update, entering low power state.")
            self.startLowPowerMonitoring()
        }
    }
}