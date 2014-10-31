//
//  RouteMachine.swift
//  HoneyBee
//
//  Created by William Henderson on 10/27/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//
// The basic strategy for this approach is as follows:

//  INITIAL STATE: Wake up due to background app refresh and/or geofence exit
//
//  - check motion activity. are we cycling?
//      - NO
//          - Are stationary?
//              - YES: set a geofence, go to sleep, back to begining
//      - NO
//          - how long have we been moving? add time stamp to map. guess starting location my extrapolating in a straight line based on distance, speed and heading
//  - turn on location tracking, motion tracking
//      - get a location update
//      - add location to current route
//  - get a motion update
//      - are we still moving?
//      - NO: end route, go to sleep, back to begining

import Foundation
import CoreLocation
import CoreMotion

class RouteMachine : NSObject, CLLocationManagerDelegate {
    let geofenceSleepRegionRadius : Double = 50
    let distanceFilter : Double = 30
    let locationTrackingDeferralTimeout : NSTimeInterval = 120
    
    private var isDefferringLocationUpdates : Bool = false
    private var shouldEndTripAfterReceivingDeferredUpdates : Bool = false
    
    private var locationManager : CLLocationManager!
    public private(set) var geofenceSleepRegion :  CLCircularRegion!
    private(set) var geofenceSleepLocation :  CLLocation!
    private var shouldStopTrackingAfterNextLocationUpdate : Bool = false
    
    private var motionActivityManager : CMMotionActivityManager!
    private var motionQueue : NSOperationQueue!
    private var motionCheckStartDate : NSDate!;
    let motionStartTimeoutInterval : NSTimeInterval = 30
    let motionContinueTimeoutInterval : NSTimeInterval = 60
    
    
    public private(set) var currentTrip : Trip!
    
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
        self.locationManager.distanceFilter = kCLDistanceFilterNone // must be set to none for deferred location updates
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest // // must be set to best for deferred location updates
        self.locationManager.activityType = CLActivityType.AutomotiveNavigation
        
        self.motionQueue = NSOperationQueue()
        self.motionActivityManager = CMMotionActivityManager()

        super.init()
    }
    
    func startup () {
        self.locationManager.delegate = self;
        self.locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - State Machine
    
    func startActivelyTrackingWithActivityType(activityType: Trip.ActivityType) {
        if (self.currentTrip != nil) {
            return
        }
        
        DDLogWrapper.logInfo("Starting Active Tracking")
        
        self.currentTrip = Trip(activityType: activityType)
        CoreDataController.sharedCoreDataController.saveContext()
        
        if (self.geofenceSleepLocation != nil) {
            // set up the first point at the geofence exit as the first location in thr trip
            let newLocation = Location(location: self.geofenceSleepLocation!, trip: self.currentTrip)
        }
        
        CoreDataController.sharedCoreDataController.saveContext()
        
        // acquire a location to base the geofence on
        self.locationManager.startUpdatingLocation()
    }
    
    func stopActivelyTrackingIfNeeded() {
        if (self.currentTrip == nil || self.shouldEndTripAfterReceivingDeferredUpdates) {
            return
        }
        
        DDLogWrapper.logInfo("Stopping Active Tracking")
        
        if (self.currentTrip != nil && self.currentTrip.locations.count == 0) {
            // if it is an empty trip, don't save it.
            CoreDataController.sharedCoreDataController.currentManagedObjectContext().deleteObject(self.currentTrip)
        }
        
        // wait for the last locations for the trip to come in before closing it out.
        self.locationManager.disallowDeferredLocationUpdates()
        self.shouldStopTrackingAfterNextLocationUpdate = true
    }
    
    func enterGeofenceSleep() {
        DDLogWrapper.logInfo("Entering geofence sleep")
        
        self.geofenceSleepRegion = nil
        self.geofenceSleepLocation = nil
        
        // acquire a location to base the geofence on
        self.locationManager.startUpdatingLocation()
    }

    // MARK: - CLLocationManger
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        DDLogWrapper.logVerbose("Did change authorization status")
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.Authorized) {
            self.checkMotionToStartActiveTracking()
            #if (arch(i386) || arch(x86_64)) && os(iOS)
                // simulator.
            #endif
        } else {
            // tell the user they need to give us access to the zion mainframes
        }
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        DDLogWrapper.logError(NSString(format: "Got active tracking location error! %@", error))
    }
    
    func locationManager(manager: CLLocationManager!, didFinishDeferredUpdatesWithError error: NSError!) {
        DDLogWrapper.logVerbose("Finished deferring updates")

        self.isDefferringLocationUpdates = false
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [CLLocation]!) {
        if (!self.isDefferringLocationUpdates) {
            DDLogWrapper.logVerbose("Started deferring updates")
            
            self.isDefferringLocationUpdates = true
            self.locationManager.allowDeferredLocationUpdatesUntilTraveled(CLLocationDistanceMax, timeout: self.locationTrackingDeferralTimeout)
        }
        
        if (self.currentTrip != nil) {
            // TODO : For the first location, extrapolate back to the geofence
            
            // add the location
            DDLogWrapper.logVerbose("Got new active tracking location")

            for location in locations {
                Location(location: location as CLLocation, trip: self.currentTrip)
            }
            CoreDataController.sharedCoreDataController.saveContext()
            
            NSNotificationCenter.defaultCenter().postNotificationName("RouteMachineDidUpdatePoints", object: nil)
            
            if (self.shouldStopTrackingAfterNextLocationUpdate) {
                // last locations for the trip have come in, close it out.
                self.currentTrip = nil
                self.enterGeofenceSleep()
            } else {
                self.checkMotionToContinueActiveTracking()
            }
        } else if (self.geofenceSleepRegion == nil) {
            // we've got a location base the geofence sleep region on now
            DDLogWrapper.logVerbose("Got geofence sleep region location")
            
            // TODO: we just use the first location we get. should we check the accuracy first?
            for location in locations {
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
        if (self.geofenceSleepRegion! == region) {
            DDLogWrapper.logVerbose("Exited geofence")
            
            self.checkMotionToStartActiveTracking()
        }
    }
    
    // MARK: - CMMotionActivityManager
    
    func checkMotionToStartActiveTracking() {
        self.motionCheckStartDate = NSDate()
        DDLogWrapper.logVerbose("Checkign motin to start active tracking…")
        
        self.motionActivityManager.startActivityUpdatesToQueue(self.motionQueue, withHandler: { (activity) in
            if (activity.confidence != CMMotionActivityConfidence.Low &&
                (activity.walking || activity.running || activity.cycling || activity.automotive)) {
                var activityType = Trip.ActivityType.Unknown

                if (activity.walking) {
                    activityType = Trip.ActivityType.Walking
                } else if (activity.running) {
                    activityType = Trip.ActivityType.Running
                } else if (activity.cycling) {
                    activityType = Trip.ActivityType.Cycling
                } else if (activity.automotive) {
                    activityType = Trip.ActivityType.Running
                } else {
                    activityType = Trip.ActivityType.Unknown
                }
                
                DDLogWrapper.logVerbose("Found matching activity for starting active tracking")
                self.motionActivityManager.stopActivityUpdates()
                self.startActivelyTrackingWithActivityType(activityType)
            } else {
                if (abs(self.motionCheckStartDate!.timeIntervalSinceNow) > self.motionStartTimeoutInterval) {
                    DDLogWrapper.logVerbose("Did NOT find matching activity for starting active tracking")
                    self.motionActivityManager.stopActivityUpdates()
                    self.enterGeofenceSleep()
                }
            }
        })
    }
    
    func checkMotionToContinueActiveTracking() {
        self.motionCheckStartDate = NSDate()
        DDLogWrapper.logVerbose("Checkign motin to continue active tracking…")
        
        self.motionActivityManager.startActivityUpdatesToQueue(self.motionQueue, withHandler: { (activity) in
            if ((activity.confidence != CMMotionActivityConfidence.Low) &&
                ((activity.walking && self.currentTrip.activityType.shortValue == Trip.ActivityType.Walking.rawValue) ||
                (activity.running && self.currentTrip.activityType.shortValue == Trip.ActivityType.Running.rawValue) ||
                (activity.cycling && self.currentTrip.activityType.shortValue == Trip.ActivityType.Cycling.rawValue) ||
                (activity.automotive  && self.currentTrip.activityType.shortValue == Trip.ActivityType.Automotive.rawValue))) {
                    // continue tracking
                    DDLogWrapper.logVerbose("Found matching activity for continuing active tracking")
                    self.motionActivityManager.stopActivityUpdates()
            } else {
                if (abs(self.motionCheckStartDate!.timeIntervalSinceNow) > self.motionContinueTimeoutInterval) {
                    DDLogWrapper.logVerbose("Did NOT find matching activity for continuing active tracking")
                    self.motionActivityManager.stopActivityUpdates()
                    self.stopActivelyTrackingIfNeeded()
                }
            }
        })
    }
}