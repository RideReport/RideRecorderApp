//
//  RouteManager.swift
//  Ride Report
//
//  Created by William Henderson on 10/27/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreLocation
import CoreMotion

class RouteManager : NSObject, CLLocationManagerDelegate {
    var backgroundTaskID : UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    var minimumSpeedToContinueMonitoring : CLLocationSpeed = 3.0 // ~6.7mph
    var minimumSpeedToStartMonitoring : CLLocationSpeed = 3.0 // ~6.7mph
    
    let locationTrackingDeferralTimeout : NSTimeInterval = 120
    let routeResumeTimeout : NSTimeInterval = 240
    let longerRouteThresholdMiles : Float = 15.0
    let longerRouteResumeTimeout : NSTimeInterval = 900

    // surround our center with [numberOfGeofenceSleepRegions] regions, each [geofenceSleepRegionDistanceToCenter] away from
    // the center with a radius of [geofenceSleepRegionRadius]. In this way, we can watch entrance events the geofences
    // surrounding our center, instead of an exit event on a geofence around our center.
    // we do this because exit events tend to perform worse than enter events.
    let numberOfGeofenceSleepRegions = 9
    let geofenceSleepRegionDistanceToCenter : CLLocationDegrees = 0.0035
    let backupGeofenceSleepRegionRadius : CLLocationDistance = 80
    let backupGeofenceIdentifier = "com.Knock.RideReport.backupGeofence"
    let geofenceSleepRegionRadius : CLLocationDistance = 80
    let geofenceIdentifierPrefix = "com.Knock.RideReport.geofence"
    var geofenceSleepRegions :  [CLCircularRegion] = []
    
    let maximumTimeIntervalBetweenGPSBasedMovement : NSTimeInterval = 60
    let maximumTimeIntervalBetweenUsuableSpeedReadings : NSTimeInterval = 60

    let minimumMotionMonitoringReadingsCountWithManualMovementToTriggerTrip = 12
    let minimumMotionMonitoringReadingsCountWithGPSMovementToTriggerTrip = 2
    let maximumMotionMonitoringReadingsCountWithoutGPSFix = 12 // Give extra time for a GPS fix.
    let maximumMotionMonitoringReadingsCountWithoutGPSMovement = 5
    
    let minimumBatteryForTracking : Float = 0.2
    
    private var isGettingInitialLocationForGeofence : Bool = false
    private var didStartFromBackground : Bool = false
    
    private var isDefferringLocationUpdates : Bool = false
    private var locationManagerIsUpdating : Bool = false
    
    private var motionMonitoringReadingsWithNonGPSMotion = 0
    private var motionMonitoringReadingsWithGPSMotion = 0
    private var motionMonitoringReadingsWithoutGPSMotionCount = 0
    private var motionMonitoringReadingsWithoutGPSFix = 0
    
    private var lastMotionMonitoringLocation :  CLLocation?
    private var lastActiveMonitoringLocation :  CLLocation?
    private var lastMovingLocation :  CLLocation?
    
    private var locationManager : CLLocationManager!
    
    var isTrackingDeviceMotionUpdates : Bool = false
    
    private var currentPrototrip : Prototrip?
    internal private(set) var currentTrip : Trip?
    
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var sharedManager : RouteManager?
        static var authorizationStatus : CLAuthorizationStatus = CLAuthorizationStatus.NotDetermined
        static let acceptableLocationAccuracy = kCLLocationAccuracyNearestTenMeters * 3
    }
    
    //
    // MARK: - Initializers
    //
    
    class var acceptableLocationAccuracy:CLLocationAccuracy {
        return Static.acceptableLocationAccuracy
    }
    
    class var sharedManager:RouteManager {
        return Static.sharedManager!
    }
    
    class var authorizationStatus: CLAuthorizationStatus {
        get {
        return Static.authorizationStatus
        }
        
        set {
            Static.authorizationStatus = newValue
        }
    }
    
    class func hasStarted()->Bool {
        return (Static.sharedManager != nil)
    }
    
    class func startup(fromBackground: Bool) {
        if (Static.sharedManager == nil) {
            Static.sharedManager = RouteManager()
            Static.sharedManager?.startup(fromBackground)
        }
    }
    
    override init () {
        super.init()
        
        UIDevice.currentDevice().batteryMonitoringEnabled = true
        
        self.locationManager = CLLocationManager()
        self.locationManager.activityType = CLActivityType.Fitness
        self.locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    private func startup(fromBackground: Bool) {
        self.locationManager.delegate = self
        self.locationManager.requestAlwaysAuthorization()
        if (fromBackground) {
            self.didStartFromBackground = true
        }
    }
    
    var location: CLLocation? {
        get {
            return self.locationManager.location
        }
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
            DDLogInfo("Tracking is Paused, not starting trip")
            
            return
        }
        
        DDLogInfo("Starting Active Tracking")
        
        var firstLocationOfNewTrip = fromLocation
        if let prototrip = self.currentPrototrip,
            firstLocation = prototrip.firstNonGeofencedLocation() {
            // if there is a prototrip, use the first location of that to determine whether or not to resume the trip
            firstLocationOfNewTrip = firstLocation.clLocation()
        }
        
        // Resume the most recent trip if it was recent enough
        if let mostRecentBikeTrip = Trip.mostRecentBikeTrip() where
            abs(mostRecentBikeTrip.endDate.timeIntervalSinceDate(firstLocationOfNewTrip.timestamp)) < self.routeResumeTimeout ||
            (mostRecentBikeTrip.lengthMiles >= self.longerRouteThresholdMiles && abs(mostRecentBikeTrip.endDate.timeIntervalSinceDate(firstLocationOfNewTrip.timestamp)) < self.longerRouteResumeTimeout) {
            DDLogInfo("Resuming ride")
            #if DEBUG
                let notif = UILocalNotification()
                notif.alertBody = "🐞 Resumed Ride Report!"
                notif.category = "RIDE_COMPLETION_CATEGORY"
                UIApplication.sharedApplication().presentLocalNotificationNow(notif)
            #endif
            self.currentTrip = mostRecentBikeTrip
            self.currentTrip?.reopen(withPrototrip: self.currentPrototrip)
            self.currentTrip?.cancelTripStateNotification()
        } else {
            self.currentTrip = Trip(prototrip: self.currentPrototrip)
            self.currentTrip?.batteryAtStart = NSNumber(short: Int16(UIDevice.currentDevice().batteryLevel * 100))
        }
        if let prototrip = self.currentPrototrip {
            prototrip.managedObjectContext?.deleteObject(prototrip)
            
            self.currentPrototrip = nil
        }
        
        // initialize lastMovingLocation to fromLocation, where the movement started
        self.lastMovingLocation = fromLocation
        self.lastActiveMonitoringLocation = fromLocation
        
        self.currentTrip?.saveAndMarkDirty()
        
        self.startLocationTrackingIfNeeded()
        
        if (CLLocationManager.deferredLocationUpdatesAvailable()) {
            DDLogInfo("Deferring updates!")
            self.locationManager.distanceFilter = kCLDistanceFilterNone
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        } else {
            // if we can't defer, try to use a distance filter and lower accuracy instead.
            DDLogInfo("Not deferring updates")
            self.locationManager.distanceFilter = 20
            self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }
    }
    
    private func stopTrip() {
        guard let stoppedTrip = self.currentTrip else {
            return
        }
        
        
        self.stopMotionMonitoring(self.lastActiveMonitoringLocation)
        self.currentTrip = nil
        self.lastActiveMonitoringLocation = nil
        self.lastMovingLocation = nil
        
        if (stoppedTrip.locations.count <= 6) {
            // if it doesn't more than 6 points, toss it.
            #if DEBUG2
                let notif = UILocalNotification()
                notif.alertBody = "Canceled Trip"
                notif.category = "RIDE_COMPLETION_CATEGORY"
                UIApplication.sharedApplication().presentLocalNotificationNow(notif)
            #endif
            stoppedTrip.cancel()
        } else {
            stoppedTrip.batteryAtEnd = NSNumber(short: Int16(UIDevice.currentDevice().batteryLevel * 100))
            DDLogInfo(String(format: "Battery Life Used: %d", stoppedTrip.batteryLifeUsed()))
            
            self.backgroundTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
                DDLogInfo("Background task expired!")
            })
            
            if (!UIDevice.currentDevice().wifiEnabled && !NSUserDefaults.standardUserDefaults().boolForKey("HasWarnedUserAboutWifi")) {
                let notif = UILocalNotification()
                notif.alertBody = "Just FYI, Ride Report works best if WiFi is enabled when you hop on your bike."
                UIApplication.sharedApplication().presentLocalNotificationNow(notif)
                
                NSUserDefaults.standardUserDefaults().setBool(true, forKey: "HasWarnedUserAboutWifi")
                NSUserDefaults.standardUserDefaults().synchronize()
            }
            
            stoppedTrip.close() {
                stoppedTrip.sendTripCompletionNotificationLocally(forFutureDate: NSDate().secondsFrom(10))
                APIClient.sharedClient.syncTrip(stoppedTrip, includeLocations: false).apiResponse() { (response) -> Void in
                    switch response.result {
                    case .Success(_):
                        DDLogInfo("Trip summary was successfully sync'd.")
                    case .Failure(_):
                        DDLogInfo("Trip summary failed to sync.")
                    }

                    if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
                        DDLogInfo("Ending background task.")
                        
                        UIApplication.sharedApplication().endBackgroundTask(self.backgroundTaskID)
                        self.backgroundTaskID = UIBackgroundTaskInvalid
                    }
               }
            }
        }
    }
    
    private func processActiveTrackingLocations(locations: [CLLocation]) {
        var foundGPSSpeed = false
        
        for location in locations {
            DDLogVerbose(String(format: "Location found for trip. Speed: %f, Accuracy: %f", location.speed, location.horizontalAccuracy))
            
            var manualSpeed : CLLocationSpeed = 0
            if (location.speed >= 0) {
                foundGPSSpeed = true
            } else if (location.speed < 0 && self.lastActiveMonitoringLocation != nil) {
                // Some times locations given will not have a speed (a negative speed).
                // Hence, we also calculate a 'manual' speed from the current location to the last one
                
                manualSpeed = self.lastActiveMonitoringLocation!.calculatedSpeedFromLocation(location)
                DDLogVerbose(String(format: "Manually found speed: %f", manualSpeed))
            }
            
            if (location.speed >= self.minimumSpeedToContinueMonitoring ||
                (manualSpeed >= self.minimumSpeedToContinueMonitoring && manualSpeed < 20.0)) {
                if (location.horizontalAccuracy <= RouteManager.acceptableLocationAccuracy) {
                    if (abs(location.timestamp.timeIntervalSinceNow) < abs(self.lastMovingLocation!.timestamp.timeIntervalSinceNow)) {
                        // if the event is more recent than the one we already have
                        self.lastMovingLocation = location
                    }
                }
                    
                Location(location: location as CLLocation, trip: self.currentTrip!)
            }
            
            if (abs(location.timestamp.timeIntervalSinceNow) < abs(self.lastActiveMonitoringLocation!.timestamp.timeIntervalSinceNow)) {
                // if the event is more recent than the one we already have
                self.lastActiveMonitoringLocation = location
            }
        }
        
        if (foundGPSSpeed == true && abs(self.lastMovingLocation!.timestamp.timeIntervalSinceDate(self.lastActiveMonitoringLocation!.timestamp)) > self.maximumTimeIntervalBetweenGPSBasedMovement){
            DDLogVerbose("Moving too slow for too long")
            self.stopTrip()
        } else if (foundGPSSpeed == false) {
            let timeIntervalSinceLastGPSMovement = abs(self.lastMovingLocation!.timestamp.timeIntervalSinceDate(self.lastActiveMonitoringLocation!.timestamp))
            var maximumTimeIntervalBetweenGPSMovements = self.maximumTimeIntervalBetweenUsuableSpeedReadings
            if (self.isDefferringLocationUpdates) {
                // if we are deferring, give extra time. this is because we will sometime get
                // bad locations (ie from startMonitoringSignificantLocationChanges) during our deferral period.
                maximumTimeIntervalBetweenGPSMovements += self.locationTrackingDeferralTimeout
            }
            if (timeIntervalSinceLastGPSMovement > maximumTimeIntervalBetweenGPSMovements) {
                DDLogVerbose("Went too long with unusable speeds.")
                self.stopTrip()
            } else {
                DDLogVerbose("Nothing but unusable speeds. Awaiting next update")
            }
        } else {
            self.currentTrip?.saveAndMarkDirty()
            NSNotificationCenter.defaultCenter().postNotificationName("RouteManagerDidUpdatePoints", object: nil)
        }
    }
    
    //
    // MARK: - Intermediary Monitoring State methods
    // We are in the monitoring state while considering starting a trip
    // If we see sufficient motion of the right kind, we start it. Otherwise, we exit.
    //
    
    private func startMotionMonitoring() {
        if (isPaused()) {
            let pausedUntilDate = self.pausedUntilDate()
            if (pausedUntilDate != nil && pausedUntilDate?.timeIntervalSinceNow <= 0) {
                #if DEBUG
                    let notif = UILocalNotification()
                    notif.alertBody = "🐞 Automatically unpausing Ride Report!"
                    notif.category = "RIDE_COMPLETION_CATEGORY"
                    UIApplication.sharedApplication().presentLocalNotificationNow(notif)
                #endif
                DDLogInfo("Auto-resuming tracking!")
                self.resumeTracking()
            } else {
                DDLogInfo("Tracking is Paused, not enterign Motion Monitoring state")
                return
            }
        }
        
        self.startLocationTrackingIfNeeded()
        
        #if DEBUG2
            let notif = UILocalNotification()
            notif.alertBody = "🐞 Entered Motion Monitoring state!"
            notif.category = "RIDE_COMPLETION_CATEGORY"
            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
        #endif
        DDLogInfo("Entering Motion Monitoring state")
        
        self.locationManager.distanceFilter = kCLDistanceFilterNone
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.disallowDeferredLocationUpdates()
        
        if (self.currentPrototrip == nil) {
            self.motionMonitoringReadingsWithNonGPSMotion = 0
            self.motionMonitoringReadingsWithGPSMotion = 0
            self.motionMonitoringReadingsWithoutGPSFix = 0
            self.motionMonitoringReadingsWithoutGPSMotionCount = 0
            self.currentPrototrip = Prototrip()
            if let currentGeofenceLocation = Profile.profile().lastGeofencedLocation {
                let _ = Location(byCopyingLocation: currentGeofenceLocation, prototrip: self.currentPrototrip!)
            }
            CoreDataManager.sharedManager.saveContext()
        }
        Profile.profile().setGeofencedLocation(nil)
        self.lastMotionMonitoringLocation = nil
    }
    
    private func stopMotionMonitoring(finalLocation: CLLocation?) {
        DDLogInfo("Stopping active monitoring")
        
        self.disableAllGeofences()
        
        if (finalLocation != nil) {
            #if DEBUG2
                let notif = UILocalNotification()
                notif.alertBody = "🐞 Geofenced!"
                notif.category = "RIDE_COMPLETION_CATEGORY"
                UIApplication.sharedApplication().presentLocalNotificationNow(notif)
            #endif
            self.setupGeofencesAroundCenter(finalLocation!)
        } else {
            DDLogInfo("Did not setup new geofence!")
        }
        
        if let prototrip = self.currentPrototrip {
            prototrip.managedObjectContext?.deleteObject(prototrip)
            CoreDataManager.sharedManager.saveContext()
            
            self.currentPrototrip = nil
        }
        
        self.locationManagerIsUpdating = false
        self.locationManager.disallowDeferredLocationUpdates()
        self.locationManager.stopUpdatingLocation()
        
        if (self.isTrackingDeviceMotionUpdates) {
            self.isTrackingDeviceMotionUpdates = false
            MotionManager.sharedManager.stopDeviceMotionUpdates()
        }
    }
    
    private func processMotionMonitoringLocations(locations: [CLLocation]) {
        var foundSufficientMovement = false
        var foundGPSFix = false
        
        guard locations.count > 0 else {
            return
        }
        
        for location in locations {
            DDLogVerbose(String(format: "Location found in motion monitoring mode. Speed: %f, Accuracy: %f", location.speed, location.horizontalAccuracy))
            
            let _ = Location(location: location, prototrip: self.currentPrototrip!)
            CoreDataManager.sharedManager.saveContext()
            
            if (location.speed >= self.minimumSpeedToStartMonitoring) {
                DDLogVerbose("Found movement while in motion monitoring state")
                if (location.horizontalAccuracy <= kCLLocationAccuracyBest) {
                    self.motionMonitoringReadingsWithoutGPSMotionCount = 0
                    self.motionMonitoringReadingsWithGPSMotion += 1
                } else {
                    self.motionMonitoringReadingsWithNonGPSMotion += 1
                }
                foundSufficientMovement = true
            } else if (location.speed >= 0 && location.horizontalAccuracy <= kCLLocationAccuracyBest) {
                // we have a GPS fix but insufficient speeds
                foundGPSFix = true
            } else if (location.speed < 0 && self.lastMotionMonitoringLocation != nil) {
                // Some times locations given will not have a speed (or a negative speed).
                // Hence, we also calculate a 'manual' speed from the current location to the last one
                
                let speed = self.lastMotionMonitoringLocation!.calculatedSpeedFromLocation(location)
                DDLogVerbose(String(format: "Manually found speed: %f", speed))
                
                if (speed >= self.minimumSpeedToStartMonitoring && speed < 12.0) {
                    // We ignore really large speeds that may be the result of location inaccuracy
                    DDLogVerbose("Found movement while in motion monitoring state via manual speed!")
                    self.motionMonitoringReadingsWithNonGPSMotion += 1
                    foundSufficientMovement = true
                }
            }
        }
        
        self.lastMotionMonitoringLocation = locations.first
        
        if (self.isGettingInitialLocationForGeofence == true && self.lastActiveMonitoringLocation?.horizontalAccuracy <= RouteManager.acceptableLocationAccuracy) {
            self.isGettingInitialLocationForGeofence = false
            if (!self.didStartFromBackground) {
                DDLogVerbose("Got intial location for geofence. Stopping!")
                self.stopMotionMonitoring(self.lastMotionMonitoringLocation)
            }
        } else if (foundSufficientMovement) {
            if(self.motionMonitoringReadingsWithNonGPSMotion >= self.minimumMotionMonitoringReadingsCountWithManualMovementToTriggerTrip ||
                self.motionMonitoringReadingsWithGPSMotion >= self.minimumMotionMonitoringReadingsCountWithGPSMovementToTriggerTrip) {
                    DDLogVerbose("Found enough motion in motion monitoring mode, triggering trip…")
                    self.startTripFromLocation(locations.first!)
            } else {
                DDLogVerbose("Found motion in motion monitoring mode, awaiting further reads…")
            }
        } else {
            DDLogVerbose("Did NOT find movement while in motion monitoring state")
            
            if (foundGPSFix) {
              self.motionMonitoringReadingsWithoutGPSMotionCount += 1
            } else {
              self.motionMonitoringReadingsWithoutGPSFix += 1
            }
            
            if (self.motionMonitoringReadingsWithoutGPSFix > self.maximumMotionMonitoringReadingsCountWithoutGPSFix ||
                self.motionMonitoringReadingsWithoutGPSMotionCount > self.maximumMotionMonitoringReadingsCountWithoutGPSMovement) {
                DDLogVerbose("Max motion monitoring readings exceeded, stopping!")
                self.stopMotionMonitoring(self.lastMotionMonitoringLocation)
            }
        }
    }
    
    //
    // MARK: - Helper methods
    //
    
    private func setupGeofencesAroundCenter(center: CLLocation) {
        DDLogInfo("Setting up geofences!")
        
        Profile.profile().setGeofencedLocation(center)
        
        // first we put a geofence in the middle as a fallback (exit event)
        let region = CLCircularRegion(center:center.coordinate, radius:self.backupGeofenceSleepRegionRadius, identifier: self.backupGeofenceIdentifier)
        self.geofenceSleepRegions.append(region)
        self.locationManager.startMonitoringForRegion(region)
        
        // the rest of our geofences are for looking at enter events
        // our first geofence will be directly north of our center
        let locationOfFirstGeofenceCenter = CLLocationCoordinate2DMake(center.coordinate.latitude + self.geofenceSleepRegionDistanceToCenter, center.coordinate.longitude)
        
        let theta = 2*M_PI/Double(self.numberOfGeofenceSleepRegions)
        // after that, we go around in a circle, measuring an angles of index*theta away from the last geofence and then planting a geofence there
        for index in 0..<self.numberOfGeofenceSleepRegions {
            let dx = 2 * self.geofenceSleepRegionDistanceToCenter * sin(Double(index) * theta/2) * cos(Double(index) * theta/2)
            let dy = 2 * self.geofenceSleepRegionDistanceToCenter * sin(Double(index) * theta/2) * sin(Double(index) * theta/2)
            let locationOfNextGeofenceCenter = CLLocationCoordinate2DMake(locationOfFirstGeofenceCenter.latitude - dy, locationOfFirstGeofenceCenter.longitude - dx)

            let region = CLCircularRegion(center:locationOfNextGeofenceCenter, radius:self.geofenceSleepRegionRadius, identifier: String(format: "%@%i",self.geofenceIdentifierPrefix, index))
            self.geofenceSleepRegions.append(region)
            self.locationManager.startMonitoringForRegion(region)
        }
    }
    
    
    private func disableAllGeofences() {
        for region in self.locationManager.monitoredRegions {
            self.locationManager.stopMonitoringForRegion(region )
        }
        
        Profile.profile().setGeofencedLocation(nil)
        self.geofenceSleepRegions = []
    }
    
    
    private func beginDeferringUpdatesIfAppropriate() {
        if (CLLocationManager.deferredLocationUpdatesAvailable() && !self.isDefferringLocationUpdates && self.currentPrototrip == nil && self.currentTrip != nil) {
            DDLogVerbose("Re-deferring updates")
            
            self.isDefferringLocationUpdates = true
            self.locationManager.allowDeferredLocationUpdatesUntilTraveled(CLLocationDistanceMax, timeout: self.locationTrackingDeferralTimeout)
        }
    }
    
    //
    // MARK: - Pause/Resuming Route Manager
    //
    
    func isPausedDueToBatteryLife() -> Bool {
#if (arch(i386) || arch(x86_64)) && os(iOS)
    return false
#endif
        return UIDevice.currentDevice().batteryLevel < self.minimumBatteryForTracking
    }
    
    func isPaused() -> Bool {
        return self.isPausedDueToBatteryLife() || self.isPausedByUser() || isPausedDueToUnauthorized()
    }
    
    func isPausedByUser() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey("RouteManagerIsPaused")
    }
    
    func isPausedDueToUnauthorized() -> Bool {
        return (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.AuthorizedAlways)
    }
    
    private func cancelScheduledAppResumeReminderNotifications() {
        for notif in UIApplication.sharedApplication().scheduledLocalNotifications! {
            let notification = notif 
            if (notification.category == "APP_PAUSED_CATEGORY") {
                UIApplication.sharedApplication().cancelLocalNotification(notification)
            }
        }
    }
    
    func pausedUntilDate() -> NSDate? {
        return NSUserDefaults.standardUserDefaults().objectForKey("RouteManagerIsPausedUntilDate") as! NSDate?
    }
    
    func pauseTracking(untilDate: NSDate! = nil) {
        if (isPaused()) {
            return
        }
        
        self.cancelScheduledAppResumeReminderNotifications()
        
        if (untilDate != nil) {
            NSUserDefaults.standardUserDefaults().setObject(untilDate, forKey: "RouteManagerIsPausedUntilDate")
        } else {
            let reminderNotification = UILocalNotification()
            reminderNotification.alertBody = "Ride Report is paused! Would you like to resume logging your bike rides?"
            reminderNotification.category = "APP_PAUSED_CATEGORY"
            reminderNotification.fireDate = NSDate.tomorrow()
            UIApplication.sharedApplication().scheduleLocalNotification(reminderNotification)
        }
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "RouteManagerIsPaused")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        DDLogInfo("Paused Tracking")
        self.disableAllGeofences()
    }
    
    private func pauseTrackingDueToLowBatteryLife() {
        if (self.locationManagerIsUpdating) {
            // if we are currently updating, send the user a push and stop.
            let notif = UILocalNotification()
            notif.alertBody = "Whoa, your battery is pretty low. Ride Report will stop running until you get a charge!"
            UIApplication.sharedApplication().presentLocalNotificationNow(notif)
            
            DDLogInfo("Paused Tracking due to battery life")
            
            self.stopMotionMonitoring(nil)
        }
    }
    
    func resumeTracking() {
        if (!isPaused()) {
            return
        }
        
        self.cancelScheduledAppResumeReminderNotifications()
        
        NSUserDefaults.standardUserDefaults().setBool(false, forKey: "RouteManagerIsPaused")
        NSUserDefaults.standardUserDefaults().setObject(nil, forKey: "RouteManagerIsPausedUntilDate")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        DDLogInfo("Resume Tracking")
        self.startTrackingMachine()
    }
    
    private func startTrackingMachine() {
        self.locationManager.startMonitoringSignificantLocationChanges()
        
        if (!self.locationManagerIsUpdating) {
            // if we are not already getting location updates, get a single update for our geofence.
            self.isGettingInitialLocationForGeofence = true
            self.startMotionMonitoring()
        }
    }
    
    private func startLocationTrackingIfNeeded() {
        if (!self.locationManagerIsUpdating) {
            self.locationManagerIsUpdating = true
            self.locationManager.startUpdatingLocation()
            if (self.locationManager.respondsToSelector("allowsBackgroundLocationUpdates")) {
                self.locationManager.setValue(true, forKey: "allowsBackgroundLocationUpdates")
            }
        }
        
        if (!self.isTrackingDeviceMotionUpdates) {
            self.isTrackingDeviceMotionUpdates = true
            MotionManager.sharedManager.startDeviceMotionUpdates(withHandler: {(motion, error) -> Void in
                guard let deviceMotion = motion else {
                    return
                }
                
                dispatch_async(dispatch_get_main_queue(), { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if let trip = strongSelf.currentTrip {
                        _ = DeviceMotion(deviceMotion: deviceMotion, trip: trip)
                    } else if let prototrip = strongSelf.currentPrototrip {
                        _ = DeviceMotion(deviceMotion: deviceMotion, prototrip: prototrip)
                    }
                })
            })
        }
    }

    //
    // MARK: - CLLocationManger Delegate Methods
    //
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        DDLogVerbose("Did change authorization status")
        
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedAlways) {
            self.startTrackingMachine()
        } else {
            // tell the user they need to give us access to the zion mainframes
            DDLogVerbose("Not authorized for location access!")
        }
        
        RouteManager.authorizationStatus = status
        NSNotificationCenter.defaultCenter().postNotificationName("appDidChangeManagerAuthorizationStatus", object: self)
    }
    
    func locationManagerDidPauseLocationUpdates(manager: CLLocationManager) {
        // Should never happen
        DDLogWarn("Did Pause location updates!")
    }
    
    func locationManagerDidResumeLocationUpdates(manager: CLLocationManager) {
        // Should never happen
        DDLogWarn("Did Resume location updates!")
    }
    
    func locationManager(manager: CLLocationManager, monitoringDidFailForRegion region: CLRegion?, withError error: NSError) {
        DDLogWarn(String(format: "Got location monitoring error! %@", error))
        
        if (error.code == CLError.RegionMonitoringFailure.rawValue) {
            // exceeded max number of geofences
        }
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        DDLogWarn(String(format: "Got active tracking location error! %@", error))
        
        if (error.code == CLError.Denied.rawValue) {
            // alert the user and pause tracking.
        }
    }
    
    func locationManager(manager: CLLocationManager, didFinishDeferredUpdatesWithError error: NSError?) {
        self.isDefferringLocationUpdates = false
        
        if (error != nil) {
            DDLogVerbose(String(format: "Error deferring updates: %@", error!))
            return
        }

        DDLogVerbose("Finished deferring updates, redeffering.")

        // start deferring updates again.
        self.beginDeferringUpdatesIfAppropriate()
    }
    
    func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if (!region.identifier.hasPrefix(self.geofenceIdentifierPrefix)) {
            DDLogVerbose("Got geofence enter for backup or other irrelevant geofence. Skipping.")
            return;
        }
        
        if (self.currentTrip == nil && self.currentPrototrip == nil) {
            DDLogVerbose("Got geofence enter, entering Motion Monitoring state.")
            self.startMotionMonitoring()
        } else {
            DDLogVerbose("Got geofence enter but already in Motion Monitoring or active tracking state.")
        }
    }
    
    func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        if (region.identifier != self.backupGeofenceIdentifier) {
            DDLogVerbose("Got geofence exit for irrelevant geofence. Skipping.")
            return;
        }
        
        if (self.currentTrip == nil && self.currentPrototrip == nil) {
            DDLogVerbose("Got geofence exit, entering Motion Monitoring state.")
            self.startMotionMonitoring()
        } else {
            DDLogVerbose("Got geofence exit but already in Motion Monitoring or active tracking state.")
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DDLogVerbose("Received location updates.")
        
#if (arch(i386) || arch(x86_64)) && os(iOS)
        // skip this check
#else
        if (UIDevice.currentDevice().batteryLevel < self.minimumBatteryForTracking)  {
            self.pauseTrackingDueToLowBatteryLife()
            return
        }
#endif
        self.beginDeferringUpdatesIfAppropriate()
        
        if (self.currentTrip != nil) {
            self.processActiveTrackingLocations(locations)
        } else if (self.currentPrototrip != nil) {
            self.processMotionMonitoringLocations(locations)
        } else {
            // We are currently in background mode and got significant location change movement.
            
            if (self.currentTrip == nil && self.currentPrototrip == nil) {
                DDLogVerbose("Got significant location, entering Motion Monitoring state.")
                self.startMotionMonitoring()
            } else {
                DDLogVerbose("Got significant location but already in Motion Monitoring or active tracking state.")
            }
        }
    }
}