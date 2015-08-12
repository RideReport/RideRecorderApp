//
//  SimpleRouteManager.swift
//  Ride Report
//
//  Created by William Henderson on 2/2/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit

class SimpleRouteManager: NSObject, CLLocationManagerDelegate {
    private var isDefferringLocationUpdates : Bool = false
    private var locationManager : CLLocationManager!
    private var lastLocDate : NSDate = NSDate()

    override init () {
        super.init()
        
        self.locationManager = CLLocationManager()
        self.locationManager.activityType = CLActivityType.Fitness
        self.locationManager.pausesLocationUpdatesAutomatically = false
        
        self.locationManager.delegate = self
        self.locationManager.requestAlwaysAuthorization()

    }
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        NSLog("Did change authorization status")
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.Authorized) {
            self.locationManager.distanceFilter = kCLDistanceFilterNone
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation

            self.locationManager.startUpdatingLocation()
        } else {
            // tell the user they need to give us access to the zion mainframes
            NSLog("Not authorized for location access!")
        }
    }
    
    func locationManager(manager: CLLocationManager!, didFinishDeferredUpdatesWithError error: NSError!) {
        NSLog("Finished deferring updates")
        
        if (error != nil) {
            NSLog(String(format: "Error deferring: %@", error))
        }
        
        NSLog("Re-deferring updates")
        
        self.isDefferringLocationUpdates = true
        self.locationManager.allowDeferredLocationUpdatesUntilTraveled(CLLocationDistanceMax, timeout: 60)
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [CLLocation]!) {
        if (!self.isDefferringLocationUpdates) {
            NSLog("Deferring updates")
            self.isDefferringLocationUpdates = true
            self.locationManager.allowDeferredLocationUpdatesUntilTraveled(CLLocationDistanceMax, timeout: 60)
        }
        
        if (abs(self.lastLocDate.timeIntervalSinceNow) > 30.0) {
            let notif = UILocalNotification()
            notif.alertBody = "Woot!"
            notif.category = "RIDE_COMPLETION_CATEGORY"
            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
        }
        
        self.lastLocDate = NSDate()
        
        NSLog("Got location update")
    }

}