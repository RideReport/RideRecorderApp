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
    let geofenceSleepRegionRadius : Double = 30
    let distanceFilter : Double = 30
    let locationTrackingDeferralTimeout : NSTimeInterval = 120
    
    private var isDefferringLocationUpdates : Bool = false
    
    private var locationManager : CLLocationManager!
    internal private(set) var geofenceSleepRegion :  CLCircularRegion!
    private(set) var geofenceSleepLocation :  CLLocation!
    private var lastMovingLocation :  CLLocation!
    private var geofenceExitDate : NSDate!;
    
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
        self.locationManager.distanceFilter = 8
        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        self.locationManager.activityType = CLActivityType.AutomotiveNavigation
        self.locationManager.pausesLocationUpdatesAutomatically = false
        
        self.motionQueue = NSOperationQueue.mainQueue()
        self.motionActivityManager = CMMotionActivityManager()

        super.init()
    }
    
    func startup () {
        self.locationManager.delegate = self;
        self.locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - State Machine
    
    func startActivelyTracking() {
        if (self.currentTrip != nil) {
            return
        }
        
        #if DEBUG
            let notif = UILocalNotification()
            notif.alertBody = "Starting Active Tracking"
            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
        #endif
        
        DDLogWrapper.logInfo("Starting Active Tracking")
        
        self.currentTrip = Trip()
        CoreDataController.sharedCoreDataController.saveContext()
        
        if (self.geofenceSleepLocation != nil) {
            // set up the first point at the geofence exit as the first location in thr trip
            let newLocation = Location(location: self.geofenceSleepLocation!, trip: self.currentTrip)
        }
        
        CoreDataController.sharedCoreDataController.saveContext()
        
        self.lastMovingLocation = nil
        self.locationManager.startUpdatingLocation()
    }
    
    func stopActivelyTrackingIfNeeded() {
        if (self.currentTrip == nil) {
            return
        }
        
        #if DEBUG
            let notif = UILocalNotification()
            notif.alertBody = "Stopping Active Tracking"
            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
        #endif
        
        DDLogWrapper.logInfo("Stopping Active Tracking")
        
        if (self.currentTrip != nil && self.currentTrip.locations.count == 0) {
            // if it is an empty trip, don't save it.
            CoreDataController.sharedCoreDataController.currentManagedObjectContext().deleteObject(self.currentTrip)
        }
        
        self.currentTrip = nil
        self.enterGeofenceSleep()
    }
    
    func enterGeofenceSleep() {
        DDLogWrapper.logInfo("Entering geofence sleep")
        
        for region in self.locationManager.monitoredRegions {
            self.locationManager.stopMonitoringForRegion(region as CLRegion)
        }
        
        self.geofenceSleepRegion = nil
        self.geofenceSleepLocation = nil
        self.geofenceExitDate = nil
        
        // acquire a location to base the geofence on
        self.locationManager.startUpdatingLocation()
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
            
            if ((self.lastMovingLocation != nil && abs(self.lastMovingLocation.timestamp.timeIntervalSinceNow) > 40.0) ||
                (self.lastMovingLocation == nil && self.geofenceExitDate != nil && abs(self.geofenceExitDate.timeIntervalSinceNow) > 40.0)){
                // otherwise, check the acceleromtere for recent data
                DDLogWrapper.logVerbose("Moving too slow for too long")
                self.stopActivelyTrackingIfNeeded()
            } else {
                CoreDataController.sharedCoreDataController.saveContext()
                NSNotificationCenter.defaultCenter().postNotificationName("RouteMachineDidUpdatePoints", object: nil)
            }
        } else if (self.geofenceSleepRegion == nil) {
            // we've got a location base the geofence sleep region on now
            DDLogWrapper.logVerbose("Got geofence sleep region location")
            
            // TODO: we just use the first location we get. should we check the accuracy first?
            if (locations.count > 0) {
                self.geofenceSleepLocation = locations.first!
                
                self.geofenceSleepRegion = CLCircularRegion(center: self.geofenceSleepLocation.coordinate, radius: self.geofenceSleepRegionRadius, identifier: "Movement Geofence")
                self.locationManager.startMonitoringForRegion(self.geofenceSleepRegion)
                NSNotificationCenter.defaultCenter().postNotificationName("RouteMachineDidUpdateGeofence", object: nil)
                
                self.locationManager.stopUpdatingLocation()                
            }
        } else {
            DDLogWrapper.logVerbose("Skipped location update!")
        }
    }
    
    func locationManager(manager: CLLocationManager!, didExitRegion region: CLRegion!) {
        if (self.geofenceSleepRegion != nil && self.geofenceSleepRegion! == region) {
            DDLogWrapper.logVerbose("Exited geofence")
            self.geofenceExitDate = NSDate()
            self.startActivelyTracking()
        }
    }
    
    func queryMotionActivity(starting: NSDate!, toDate: NSDate!, withHandler handler: CMMotionActivityQueryHandler!) {
        self.motionActivityManager.queryActivityStartingFromDate(starting, toDate: toDate, toQueue: self.motionQueue, withHandler: handler)
    }
}