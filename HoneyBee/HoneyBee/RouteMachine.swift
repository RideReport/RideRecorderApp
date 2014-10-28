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
    private var isActivelyTracking : Bool
    
    private var locationManager : CLLocationManager!
    private var geofenceSleepRegion :  CLRegion!
    
    private var motionManager : CMMotionActivityManager!
    private var motionQueue : NSOperationQueue!
    private var lastMotionActivity : CMMotionActivity!
    
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
        self.isActivelyTracking = false
        super.init()
        
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self;
        
        self.locationManager.requestAlwaysAuthorization()
        if (CMMotionActivityManager.isActivityAvailable()) {
            self.motionQueue = NSOperationQueue()
            self.motionManager = CMMotionActivityManager()
            
            self.startMotionTracking()
        }
    }
    
    // MARK: - CLLocationManger
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
    }
    
    func enterGeofenceSleep() {
        self.lastMotionActivity = nil
        self.isActivelyTracking = false
        self.motionManager.stopActivityUpdates()
        
        self.geofenceSleepRegion = nil
        
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.Authorized) {
            // unclear what we should do if not
            
            self.locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [CLLocation]!) {
        if (self.isActivelyTracking) {
            // TODO : For the first location, extrapolate back to the geofence
            
            // add the location
            let newLocation = Location(location: locations.first!, motionActivity: self.lastMotionActivity)
            CoreDataController.sharedCoreDataController.saveContext()
        } else if (self.geofenceSleepRegion == nil) {
            // we just use the first location we get. should we check the accuracy first?
            let geofenceCenter = locations.first!
            
            self.geofenceSleepRegion = CLCircularRegion(center: geofenceCenter.coordinate, radius: 100.0, identifier: "Movement Geofence")
            self.locationManager.startMonitoringForRegion(self.geofenceSleepRegion)
        }
        
        self.locationManager.stopUpdatingLocation()
    }
    
    func locationManager(manager: CLLocationManager!, didExitRegion region: CLRegion!) {
        if (self.geofenceSleepRegion == region) {
            // we moved out of the region, so check and see what activity type we are engaging in
            self.startMotionTracking()
        }
    }
    
    // MARK: - CMMotionActivityManager
    
    func startMotionTracking() {
        self.motionManager.startActivityUpdatesToQueue(self.motionQueue, withHandler: { (activity: CMMotionActivity!) -> Void in
            self.processMotionActivity(activity)
        })
    }
    
    func processMotionActivity(activity: CMMotionActivity!) {
        self.lastMotionActivity = activity
        
        if (activity.cycling || activity.running || activity.automotive) {
            self.isActivelyTracking = true
            self.startMotionTracking()
        } else {
            if (self.isActivelyTracking) {
                // end the route
            }
            // we are stationary and/or in an unknown state. go to sleep state
            self.enterGeofenceSleep()
        }
    }
}

