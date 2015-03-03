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
    var backgroundTaskID : UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    var minimumSpeedToContinueMonitoring : CLLocationSpeed = 3.0 // ~6.7mph
    var minimumSpeedToStartMonitoring : CLLocationSpeed = 3.0 // ~6.7mph
    
    let locationTrackingDeferralTimeout : NSTimeInterval = 120
    let routeResumeTimeout : NSTimeInterval = 240
    let acceptableLocationAccuracy = kCLLocationAccuracyNearestTenMeters * 3
    
    let geofenceSleepRegionRadius : Double = 30
    private var geofenceSleepRegion :  CLCircularRegion!
    
    let maximumTimeIntervalBetweenMovements : NSTimeInterval = 60
    let maximumTimeIntervalBetweenUsuableSpeedReadings : NSTimeInterval = 180 // must be larger than the deferral timeout

    let minimumMotionMonitoringReadingsCountWithManualMovementToTriggerTrip = 3
    let minimumMotionMonitoringReadingsCountWithGPSMovementToTriggerTrip = 2
    let maximumMotionMonitoringReadingsCountWithoutMovement = 6
    
    let minimumBatteryForTracking : Float = 0.2
    
    private var isDefferringLocationUpdates : Bool = false
    private var locationManagerIsUpdating : Bool = false
    
    private var isInMotionMonitoringState : Bool = false
    private var motionMonitoringReadingsWithManualMotion = 0
    private var motionMonitoringReadingsWithGPSMotion = 0
    private var motionMonitoringReadingsWithoutMotionCount = 0
    
    private var lastMotionMonitoringLocation :  CLLocation?
    private var lastActiveMonitoringLocation :  CLLocation?
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
    // MARK: - Active Trip Tracking methods
    // We are in the active trip tracking while a route is ongoing.
    // If we see sufficient motion of the right kind, we keep tracking. Otherwise, we end the trip.
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
        self.lastActiveMonitoringLocation = fromLocation
        
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
            // if we can't defer, try to use a distance filter and lower accuracy instead.
            DDLogWrapper.logInfo("Not deferring updates")
            self.locationManager.distanceFilter = 20
            self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }
        
        self.isInMotionMonitoringState = false
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
                
                self.backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
                    closingTrip!.sendTripCompletionNotificationImmediately()
                })
                closingTrip!.sendTripCompletionNotification() {
                    if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
                        UIApplication.sharedApplication().endBackgroundTask(self.backgroundTaskID)
                        self.backgroundTaskID = UIBackgroundTaskInvalid
                    }
                }
            }
        }
        
        self.stopActiveMonitoring(self.lastActiveMonitoringLocation)
        
        self.currentTrip = nil
        self.lastActiveMonitoringLocation = nil
        self.lastMovingLocation = nil
    }
    
    private func processActiveTrackingLocations(locations: [CLLocation]!) {
        var foundUsableSpeed = false
        
        for location in locations {
            DDLogWrapper.logVerbose(NSString(format: "Location found for trip. Speed: %f", location.speed))
            
            var manualSpeed : CLLocationSpeed = 0
            
            if (location.speed > 0) {
                foundUsableSpeed = true
            } else if (location.speed < 0 && self.lastActiveMonitoringLocation != nil) {
                // Some times locations given will not have a speed (or a negative speed).
                // Hence, we also calculate a 'manual' speed from the current location to the last one
                
                foundUsableSpeed = true
                manualSpeed = self.lastActiveMonitoringLocation!.calculatedSpeedFromLocation(location)
                DDLogWrapper.logVerbose(NSString(format: "Manually found speed: %f", manualSpeed))
            }
            
            if (location.speed >= self.minimumSpeedToContinueMonitoring ||
                (manualSpeed >= self.minimumSpeedToContinueMonitoring && manualSpeed < 20.0)) {
                if (abs(location.timestamp.timeIntervalSinceNow) < abs(self.lastMovingLocation!.timestamp.timeIntervalSinceNow)) {
                    // if the event is more recent than the one we already have
                    self.lastMovingLocation = location
                }
                if (location.horizontalAccuracy <= self.acceptableLocationAccuracy) {
                    Location(location: location as CLLocation, trip: self.currentTrip!)
                }
            }
            
            self.lastActiveMonitoringLocation = location
        }
        
        if (foundUsableSpeed == true && abs(self.lastMovingLocation!.timestamp.timeIntervalSinceNow) > self.maximumTimeIntervalBetweenMovements){
            DDLogWrapper.logVerbose("Moving too slow for too long")
            self.stopTrip()
        } else if (foundUsableSpeed == false) {
            if (abs(self.lastMovingLocation!.timestamp.timeIntervalSinceNow) > self.maximumTimeIntervalBetweenUsuableSpeedReadings) {
                DDLogWrapper.logVerbose("Went too long with unusable speeds.")
                self.stopTrip()
            } else {
                DDLogWrapper.logVerbose("Nothing but unusable speeds. Awaiting next update")
            }
        } else {
            CoreDataController.sharedCoreDataController.saveContext()
            NSNotificationCenter.defaultCenter().postNotificationName("RouteMachineDidUpdatePoints", object: nil)
        }
    }
    
    //
    // MARK: - Intermediary Monitoring State methods
    // We are in the monitoring state while considering starting a trip
    // If we see sufficient motion of the right kind, we start it. Otherwise, we exit.
    //
    
    private func startMotionMonitoring() {
        if (isPaused()) {
            DDLogWrapper.logInfo("Tracking is Paused, not enterign Motion Monitoring state")
            
            return
        } else if (!self.locationManagerIsUpdating) {
            self.locationManagerIsUpdating = true
            self.locationManager.startUpdatingLocation()
        }
        
        #if DEBUG
            let notif = UILocalNotification()
            notif.alertBody = "Entered Motion Monitoring state!"
            notif.category = "RIDE_COMPLETION_CATEGORY"
            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
        #endif
        DDLogWrapper.logInfo("Entering Motion Monitoring state")
        
        self.locationManager.distanceFilter = kCLDistanceFilterNone
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.disallowDeferredLocationUpdates()
        
        if (!self.isInMotionMonitoringState) {
            self.motionMonitoringReadingsWithManualMotion = 0
            self.motionMonitoringReadingsWithGPSMotion = 0
            self.motionMonitoringReadingsWithoutMotionCount = 0
            self.isInMotionMonitoringState = true
        }
        self.lastMotionMonitoringLocation = nil
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
        
        self.isInMotionMonitoringState = false
        self.locationManagerIsUpdating = false
        self.locationManager.disallowDeferredLocationUpdates()
        self.locationManager.stopUpdatingLocation()
    }
    
    private func processMotionMonitoringLocations(locations: [CLLocation]!) {
        var foundSufficientMovement = false
        
        for location in locations {
            DDLogWrapper.logVerbose(NSString(format: "Location found in motion monitoring mode. Speed: %f", location.speed))
            if (location.speed >= self.minimumSpeedToStartMonitoring) {
                DDLogWrapper.logVerbose("Found movement while in motion monitoring state")
                self.motionMonitoringReadingsWithGPSMotion += 1
                foundSufficientMovement = true
                break
            }
            
            // Some times locations given will not have a speed (or a negative speed).
            // Hence, we also calculate a 'manual' speed from the current location to the last one
            if (location.speed < 0 && self.lastMotionMonitoringLocation != nil) {
                let speed = self.lastMotionMonitoringLocation!.calculatedSpeedFromLocation(location)
                DDLogWrapper.logVerbose(NSString(format: "Manually found speed: %f", speed))
                
                if (speed >= self.minimumSpeedToStartMonitoring && speed < 20.0) {
                    // We ignore really large speeds that may be the result of location inaccuracy
                    DDLogWrapper.logVerbose("Found movement while in motion monitoring state via manual speed!")
                    self.motionMonitoringReadingsWithManualMotion += 1
                    foundSufficientMovement = true
                }
            }
        }
        
        self.lastMotionMonitoringLocation = locations.first
        
        if (foundSufficientMovement) {
            if(self.motionMonitoringReadingsWithManualMotion >= self.minimumMotionMonitoringReadingsCountWithManualMovementToTriggerTrip ||
                self.motionMonitoringReadingsWithGPSMotion >= self.minimumMotionMonitoringReadingsCountWithGPSMovementToTriggerTrip) {
                    DDLogWrapper.logVerbose("Found enough motion in motion monitoring mode, triggering trip…")
                    self.startTripFromLocation(self.lastMotionMonitoringLocation!)
                    
                    for location in locations {
                        if (location.horizontalAccuracy <= self.acceptableLocationAccuracy) {
                            Location(location: location as CLLocation, trip: self.currentTrip!)
                        }
                    }
            } else {
                DDLogWrapper.logVerbose("Found motion in motion monitoring mode, awaiting further reads…")
            }
        } else {
            DDLogWrapper.logVerbose("Did NOT find movement while in motion monitoring state")
            self.motionMonitoringReadingsWithoutMotionCount += 1
            
            if (self.motionMonitoringReadingsWithoutMotionCount > self.maximumMotionMonitoringReadingsCountWithoutMovement) {
                DDLogWrapper.logVerbose("Max motion monitoring readings exceeded, stopping!")
                self.stopActiveMonitoring(self.lastMotionMonitoringLocation)
            }
        }
    }
    
    //
    // MARK: - Helper methods
    //
    
    
    private func disableAllGeofences() {
        for region in self.locationManager.monitoredRegions {
            self.locationManager.stopMonitoringForRegion(region as CLRegion)
        }
        
        self.geofenceSleepRegion = nil
    }
    
    
    private func beginDeferringUpdatesIfAppropriate() {
        if (CLLocationManager.deferredLocationUpdatesAvailable() && !self.isDefferringLocationUpdates && !self.isInMotionMonitoringState && self.currentTrip != nil) {
            DDLogWrapper.logVerbose("Re-deferring updates")
            
            self.isDefferringLocationUpdates = true
            self.locationManager.allowDeferredLocationUpdatesUntilTraveled(CLLocationDistanceMax, timeout: self.locationTrackingDeferralTimeout)
        }
    }
    
    //
    // MARK: - Pause/Resuming Route Machine
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
            self.startMotionMonitoring()
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
    
    func locationManager(manager: CLLocationManager!, didExitRegion region: CLRegion!) {
        // Enter a to monitor for user movement
        if (self.currentTrip == nil && !self.isInMotionMonitoringState) {
            DDLogWrapper.logVerbose("Got geofence exit, entering Motion Monitoring state.")
            self.startMotionMonitoring()
        } else {
            DDLogWrapper.logVerbose("Got geofence exit but already in Motion Monitoring or active tracking state.")
        }
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [CLLocation]!) {
        DDLogWrapper.logVerbose("Received location updates.")

        if (UIDevice.currentDevice().batteryLevel < self.minimumBatteryForTracking)  {
            self.pauseTrackingDueToLowBatteryLife()
            return
        }
        
        self.beginDeferringUpdatesIfAppropriate()
        
        if (self.currentTrip != nil) {
            self.processActiveTrackingLocations(locations)
        } else if (self.isInMotionMonitoringState) {
            self.processMotionMonitoringLocations(locations)
        } else {
            // We are currently in background mode and got significant location change movement.
            // We now enter a state to monitor for user movement
            DDLogWrapper.logVerbose("Got significant location update, entering motion monitoring state.")
            self.startMotionMonitoring()
        }
    }
}