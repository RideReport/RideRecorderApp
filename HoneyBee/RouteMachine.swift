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
    let activeMotionTimeoutInterval : Double = 60
    let geofenceSleepRegionRadius : Double = 50
    let distanceFilter : Double = 30
    
    private var isActivelyTracking : Bool = false
    
    private var locationManager : CLLocationManager!
    public private(set) var geofenceSleepRegion :  CLCircularRegion!
    private(set) var geofenceSleepLocation :  CLLocation!
    
    private var motionActivityManager : CMMotionActivityManager!
    private var motionQueue : NSOperationQueue!
    private var lastMotionActivity : CMMotionActivity!
    
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
        self.locationManager.distanceFilter = self.distanceFilter
        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        self.locationManager.activityType = CLActivityType.AutomotiveNavigation
        
        self.motionQueue = NSOperationQueue()
        self.motionActivityManager = CMMotionActivityManager()

        super.init()
    }
    
    func startup () {
        self.locationManager.delegate = self;
        self.locationManager.requestAlwaysAuthorization()
        
        self.startActivelyTrackingIfNeeded()
    }
    
    // MARK: - State Machine
    
    func startActivelyTrackingIfNeeded() {
        if (self.isActivelyTracking) {
            return
        }
        
        DDLogWrapper.logInfo("Starting Active Tracking")
        
        self.isActivelyTracking = true
        self.currentTrip = Trip()
        CoreDataController.sharedCoreDataController.saveContext()
        
        self.checkForMotionActivity()
        self.locationManager.startUpdatingLocation()
    }
    
    func stopActivelyTrackingIfNeeded() {
        if (!self.isActivelyTracking) {
            return
        }
        
        DDLogWrapper.logInfo("Stopping Active Tracking")
        
        self.isActivelyTracking = false
        
        if (self.currentTrip != nil && self.currentTrip.locations.count == 0) {
            // if it is an empty trip, don't save it.
            CoreDataController.sharedCoreDataController.currentManagedObjectContext().deleteObject(self.currentTrip)
        }
        self.currentTrip = nil
        
        self.lastMotionActivity = nil
        self.motionActivityManager.stopActivityUpdates()
        
        self.enterGeofenceSleep()
    }
    
    func enterGeofenceSleep() {
        DDLogWrapper.logInfo("Entering geofence sleep")
        
        self.geofenceSleepRegion = nil
        self.geofenceSleepLocation = nil
        
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.Authorized) {
            // acquire a location to base the geofence on
            self.locationManager.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManger
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        DDLogWrapper.logError(NSString(format: "Got active tracking location error! %@", error))
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [CLLocation]!) {
        if (self.isActivelyTracking) {
            // TODO : For the first location, extrapolate back to the geofence
            
            // add the location
            DDLogWrapper.logVerbose("Got new active tracking location")

            if (self.lastMotionActivity != nil) {
                let newLocation = Location(location: locations.first!, motionActivity: self.lastMotionActivity, trip: self.currentTrip)
                CoreDataController.sharedCoreDataController.saveContext()
                
                NSNotificationCenter.defaultCenter().postNotificationName("RouteMachineDidUpdatePoints", object: nil)
            } else {
                DDLogWrapper.logVerbose("No motion activity yet, waiting.")
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
        }
    }
    
    func locationManager(manager: CLLocationManager!, didExitRegion region: CLRegion!) {
        if (self.geofenceSleepRegion! == region) {
            DDLogWrapper.logVerbose("Exited geofence")
            
            // we moved out of the region, so check and see what activity type we are engaging in
            self.startActivelyTrackingIfNeeded()
        }
    }
    
    // MARK: - CMMotionActivityManager
    
    func checkForMotionActivity() {
        #if (arch(i386) || arch(x86_64)) && os(iOS)
            // simulator.
            self.lastMotionActivity = CMMotionActivity()
            self.startActivelyTrackingIfNeeded()
        #endif
        
        if (CMMotionActivityManager.isActivityAvailable()) {
            self.motionActivityManager.startActivityUpdatesToQueue(self.motionQueue, withHandler: { (activity: CMMotionActivity!) -> Void in
                self.processMotionActivity(activity)
            })
        }
    }
    
    func processMotionActivity(activity: CMMotionActivity!) {
        if (activity.walking || activity.running || activity.cycling || activity.automotive) {
            if (self.lastMotionActivity == nil && self.geofenceSleepLocation != nil) {
                // if this is our first motion activity in the trip, set up the first point at the geofence exit
                let newLocation = Location(location: self.geofenceSleepLocation!, motionActivity: activity, trip: self.currentTrip)
                CoreDataController.sharedCoreDataController.saveContext()
            }
            
            self.lastMotionActivity = activity
            DDLogWrapper.logVerbose("Found active motion")
        } else if (self.lastMotionActivity != nil && (activity.timestamp - self.lastMotionActivity!.timestamp) < self.activeMotionTimeoutInterval) {
            DDLogWrapper.logVerbose("Found stationary motion within timeout interval, ignoring")
        } else {
            DDLogWrapper.logVerbose("Found stationary motion")
            // TODO: some sort of timeout here?
            self.stopActivelyTrackingIfNeeded()
        }
    }
}

