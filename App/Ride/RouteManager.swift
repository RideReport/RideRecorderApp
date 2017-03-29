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
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
private func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
private func <= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l <= r
  default:
    return !(rhs < lhs)
  }
}


class RouteManager : NSObject, CLLocationManagerDelegate {
    var backgroundTaskID : UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    var startedInBackgroundBackgroundTaskID : UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    var minimumSpeedToContinueMonitoring : CLLocationSpeed = 2.25 // ~5mph
    
    let locationTrackingDeferralTimeout : TimeInterval = 120

    // surround our center with [numberOfGeofenceSleepRegions] regions, each [geofenceSleepRegionDistanceToCenter] away from
    // the center with a radius of [geofenceSleepRegionRadius]. In this way, we can watch entrance events the geofences
    // surrounding our center, instead of an exit event on a geofence around our center.
    // we do this because exit events tend to perform worse than enter events.
    let numberOfGeofenceSleepRegions = 9
    let geofenceSleepRegionDistanceToCenter : CLLocationDegrees = 0.0035
    let backupGeofenceSleepRegionRadius : CLLocationDistance = 80
    let backupGeofenceIdentifier = "com.Knock.RideReport.backupGeofence"
    let geofenceSleepRegionRadius : CLLocationDistance = 90
    let geofenceIdentifierPrefix = "com.Knock.RideReport.geofence"
    var geofenceSleepRegions :  [CLCircularRegion] = []
    
    let maximumTimeIntervalBetweenGPSBasedMovement : TimeInterval = 60
    let maximumTimeIntervalBetweenUsuableSpeedReadings : TimeInterval = 60
    
    let minimumBatteryForTracking : Float = 0.2
    
    private var isGettingInitialLocationForGeofence : Bool = false
    private var didStartFromBackground : Bool = false
    
    private var isDefferringLocationUpdates : Bool = false
    private var locationManagerIsUpdating : Bool = false
    private var dateOfStoppingLastLocationManagerUpdates : Date?
    
    private var lastMotionMonitoringLocation :  CLLocation?
    private var lastActiveMonitoringLocation :  CLLocation?
    private var lastMovingLocation :  CLLocation?
    private var numberOfNonMovingContiguousGPSLocations = 0
    private var minimumNumberOfNonMovingContiguousGPSLocations = 3
    
    private var locationManager : CLLocationManager!
    
    var lastActiveTrackingActivityTypeQueryDate : Date?
    let numberOfActiveTrackingActivityTypeQueriesToTakeAtShorterInterval = 8
    let numberOfActiveTrackingActivityTypeQueriesToTakeAtNormalInterval = 20
    let shortenedTimeIntervalBetweenActiveTrackingActivityTypeQueries : TimeInterval = 15
    let normalTimeIntervalBetweenActiveTrackingActivityTypeQueries : TimeInterval = 60
    let extendedTimeIntervalBetweenActiveTrackingActivityTypeQueries : TimeInterval = 180
    
    var lastMotionMonitoringActivityTypeQueryDate : Date?
    let timeIntervalBetweenMotionMonitoringActivityTypeQueries : TimeInterval = 10
    let timeIntervalBeforeBailingOnStuckMotionMonitoringActivityTypeQuery : TimeInterval = 30
    var numberOfActivityTypeQueriesSinceLastSignificantLocationChange = 0
    let maximumNumberOfActivityTypeQueriesSinceLastSignificantLocationChange = 6 // ~60 seconds
    
    private var currentPrototrip : Prototrip?
    internal private(set) var currentTrip : Trip?
    private var currentMotionMonitoringSensorDataCollection : SensorDataCollection?
    private var currentActiveMonitoringSensorDataCollection : SensorDataCollection?
    
    
    static private(set) var shared: RouteManager!
    static var authorizationStatus : CLAuthorizationStatus = CLAuthorizationStatus.notDetermined
    
    //
    // MARK: - Initializers
    //
    
    class func startup(_ fromBackground: Bool) {
        if (RouteManager.shared == nil) {
            let startupBlock = {
                RouteManager.shared = RouteManager()
                RouteManager.shared.startup(fromBackground)
            }
            
            if !Thread.current.isMainThread {
                DispatchQueue.main.sync {
                    // it is important to run initialization of CLLocationManager on the main thread
                    startupBlock()
                }
            } else {
                startupBlock()
            }
            
        }
    }
    
    class var hasStarted: Bool {
        get {
            return (RouteManager.shared != nil)
        }
    }
    
    override init () {
        super.init()
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        self.locationManager = CLLocationManager()
        self.locationManager.activityType = CLActivityType.fitness
        self.locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    private func startup(_ fromBackground: Bool) {
        if (fromBackground) {
            self.didStartFromBackground = true
            
            // launch a background task to be sure we dont get killed until we get our first location update!
            if (self.startedInBackgroundBackgroundTaskID == UIBackgroundTaskInvalid) {
                DDLogInfo("Beginning Route Manager Started in background Background task!")
                self.startedInBackgroundBackgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    DDLogInfo("Route Manager Started in background Background task!")
                })
            }
        }
        self.locationManager.delegate = self
        self.locationManager.requestAlwaysAuthorization()
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
    
    private func tripQualifiesForResumptions(_ trip: Trip, activityType: ActivityType, fromLocation: CLLocation)->Bool {
        if (trip.activityType != activityType) {
            if (trip.activityType.isMotorizedMode && activityType.isMotorizedMode) {
                // if both trips are motorized, allow resumption since our mode detection within motorized mode is not great
            } else {
                return false
            }
        }
        
        var timeoutInterval: TimeInterval = 0
        switch trip.activityType {
        case .cycling where trip.length.miles >= 12:
            timeoutInterval = 1080
        default:
            timeoutInterval = 300
        }
        
        return abs(trip.endDate.timeIntervalSince(fromLocation.timestamp)) < timeoutInterval
    }
    
    private func startTripFromLocation(_ fromLocation: CLLocation, predictedActivityType activityType:ActivityType) {
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
            let firstLocation = prototrip.firstNonGeofencedLocation() {
            // if there is a prototrip, use the first location of that to determine whether or not to resume the trip
            firstLocationOfNewTrip = firstLocation.clLocation()
        }
        
        // Resume the most recent trip if it was recent enough
        if let mostRecentTrip = Trip.mostRecentTrip(), self.tripQualifiesForResumptions(mostRecentTrip, activityType: activityType, fromLocation: firstLocationOfNewTrip)  {
            DDLogInfo("Resuming ride")
            #if DEBUG
                if UserDefaults.standard.bool(forKey: "DebugVerbosityMode") {
                    let notif = UILocalNotification()
                    notif.alertBody = "🐞 Resumed Ride Report!"
                    notif.category = "DEBUG_CATEGORY"
                    UIApplication.shared.presentLocalNotificationNow(notif)
                }
            #endif
            self.currentTrip = mostRecentTrip
            self.currentTrip?.reopen(withPrototrip: self.currentPrototrip)
            self.currentTrip?.cancelTripStateNotification()
        } else {
            self.currentTrip = Trip(prototrip: self.currentPrototrip)
            self.currentTrip?.batteryAtStart = NSNumber(value: Int16(UIDevice.current.batteryLevel * 100) as Int16)
        }
        if let prototrip = self.currentPrototrip {
            prototrip.managedObjectContext?.delete(prototrip)
            
            self.currentPrototrip = nil
        }
        
        // initialize lastMovingLocation to fromLocation, where the movement started
        self.lastMovingLocation = fromLocation
        self.numberOfNonMovingContiguousGPSLocations = 0
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
            self.locationManager.distanceFilter = kCLDistanceFilterNone
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }
    }
    
    func abortTrip() {
        self.stopTrip(true)
    }
    
    private func stopTrip(_ abort: Bool = false) {
        guard let stoppedTrip = self.currentTrip else {
            return
        }
        
        
        self.stopMotionMonitoringAndSetupGeofences(aroundLocation: self.lastActiveMonitoringLocation)
        self.currentTrip = nil
        self.lastActiveMonitoringLocation = nil
        self.lastMovingLocation = nil
        self.numberOfNonMovingContiguousGPSLocations = 0
        self.lastActiveTrackingActivityTypeQueryDate = nil
        
        if (abort || stoppedTrip.locations.count <= 6) {
            // if it is aborted or it doesn't more than 6 points, toss it.
            #if DEBUG
                if UserDefaults.standard.bool(forKey: "DebugVerbosityMode") {
                    let notif = UILocalNotification()
                    notif.alertBody = "🐞 Canceled Trip"
                    notif.category = "DEBUG_CATEGORY"
                    UIApplication.shared.presentLocalNotificationNow(notif)
                }
            #endif
            stoppedTrip.cancel()
        } else {
            stoppedTrip.batteryAtEnd = NSNumber(value: Int16(UIDevice.current.batteryLevel * 100) as Int16)
            DDLogInfo(String(format: "Battery Life Used: %d", stoppedTrip.batteryLifeUsed()))
            
            if (self.backgroundTaskID == UIBackgroundTaskInvalid) {
                DDLogInfo("Beginning Route Manager Stop Trip Background task!")
                self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    DDLogInfo("Route Manager Background task expired!")
                })
            }
            
            stoppedTrip.close() {
                stoppedTrip.sendTripCompletionNotificationLocally(secondsFromNow:15.0)
                APIClient.shared.syncTrip(stoppedTrip, includeLocations: false).apiResponse() { (response) -> Void in
                    switch response.result {
                    case .success(_):
                        DDLogInfo("Trip summary was successfully sync'd.")
                    case .failure(_):
                        DDLogInfo("Trip summary failed to sync.")
                    }

                    if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
                        DDLogInfo("Ending Route Manager Stop Trip Background task!")
                        
                        UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                        self.backgroundTaskID = UIBackgroundTaskInvalid
                    }
               }
            }
        }
    }
    
    private func isReadyForActiveTrackingActivityQuery()->Bool {
        guard let lastQueryDate = self.lastActiveTrackingActivityTypeQueryDate else {
            // if we've never taken a query for this trip, do it now
            return true
        }
        
        guard let currentTrip = self.currentTrip else {
            return false
        }
        
        return (currentTrip.sensorDataCollections.count <= self.numberOfActiveTrackingActivityTypeQueriesToTakeAtShorterInterval && abs(lastQueryDate.timeIntervalSinceNow) > shortenedTimeIntervalBetweenActiveTrackingActivityTypeQueries) ||
                (currentTrip.sensorDataCollections.count <= self.numberOfActiveTrackingActivityTypeQueriesToTakeAtNormalInterval && abs(lastQueryDate.timeIntervalSinceNow) > normalTimeIntervalBetweenActiveTrackingActivityTypeQueries) ||
                abs(lastQueryDate.timeIntervalSinceNow) > extendedTimeIntervalBetweenActiveTrackingActivityTypeQueries
    }
    
    private func processActiveTrackingLocations(_ locations: [CLLocation]) {
        var foundGPSSpeed = false
        
        for location in locations {
            DDLogVerbose(String(format: "Location found for trip. Speed: %f, Accuracy: %f", location.speed, location.horizontalAccuracy))
            
            var manualSpeed : CLLocationSpeed = 0
            if (location.speed >= 0) {
                foundGPSSpeed = true
                if (location.speed >= self.minimumSpeedToContinueMonitoring) {
                    self.numberOfNonMovingContiguousGPSLocations = 0
                } else {
                    self.numberOfNonMovingContiguousGPSLocations += 1
                }
            } else if (location.speed < 0 && self.lastActiveMonitoringLocation != nil) {
                // Some times locations given will not have a speed (a negative speed).
                // Hence, we also calculate a 'manual' speed from the current location to the last one
                
                manualSpeed = self.lastActiveMonitoringLocation!.calculatedSpeedFromLocation(location)
                DDLogVerbose(String(format: "Manually found speed: %f", manualSpeed))
            }
            
            if (location.speed >= self.minimumSpeedToContinueMonitoring ||
                (manualSpeed >= self.minimumSpeedToContinueMonitoring && manualSpeed < 20.0)) {
                // if we are moving sufficiently fast and havent taken a motion sample recently, do so
                if (self.currentActiveMonitoringSensorDataCollection == nil && self.isReadyForActiveTrackingActivityQuery()) {
                    self.lastActiveTrackingActivityTypeQueryDate = Date()
                    self.currentActiveMonitoringSensorDataCollection = SensorDataCollection(trip: self.currentTrip!)
                    
                    MotionManager.shared.queryCurrentActivityType(forSensorDataCollection: self.currentActiveMonitoringSensorDataCollection!) { (sensorDataCollection) -> Void in
                        self.currentActiveMonitoringSensorDataCollection = nil
                        
                        // Schedule deferal right after query returns to avoid the query preventing the app from backgrounding
                        self.beginDeferringUpdatesIfAppropriate()
                        #if DEBUG
                            if let prediction = sensorDataCollection.topActivityTypePrediction, UserDefaults.standard.bool(forKey: "DebugVerbosityMode") {
                                let notif = UILocalNotification()
                                notif.alertBody = "🐞 prediction: " + prediction.activityType.emoji + " confidence: " + String(prediction.confidence.floatValue)
                                notif.category = "DEBUG_CATEGORY"
                                UIApplication.shared.presentLocalNotificationNow(notif)
                            }
                        #endif
                    }
                }
                
                if (location.horizontalAccuracy <= Location.acceptableLocationAccuracy) {
                    if (abs(location.timestamp.timeIntervalSinceNow) < abs(self.lastMovingLocation!.timestamp.timeIntervalSinceNow)) {
                        // if the event is more recent than the one we already have
                        self.lastMovingLocation = location
                    }
                }
            }
            
            let loc = Location(location: location as CLLocation, trip: self.currentTrip!)
            let updatedInProgressLength = self.currentTrip!.updateInProgressLength()
            
            if let collection = self.currentActiveMonitoringSensorDataCollection, let sensorDataCollectionDate = self.lastActiveTrackingActivityTypeQueryDate, location.timestamp.timeIntervalSince(sensorDataCollectionDate) > -0.1 {
                // we check to make sure the time of the location is after (or within an acceptable amount before) we started the currentActiveMonitoringSensorDataCollection
                loc.sensorDataCollection = collection
            }
            
            if (abs(location.timestamp.timeIntervalSinceNow) < abs(self.lastActiveMonitoringLocation!.timestamp.timeIntervalSinceNow)) {
                // if the event is more recent than the one we already have
                self.lastActiveMonitoringLocation = location
            }
        }
        
        if (foundGPSSpeed == true && abs(self.lastMovingLocation!.timestamp.timeIntervalSince(self.lastActiveMonitoringLocation!.timestamp)) > self.maximumTimeIntervalBetweenGPSBasedMovement){
            if (self.numberOfNonMovingContiguousGPSLocations >= self.minimumNumberOfNonMovingContiguousGPSLocations) {
                DDLogVerbose("Moving too slow for too long")
                self.stopTrip()
            } else {
                DDLogVerbose("Not enough slow locations to stop, waiting…")
            }
        } else if (foundGPSSpeed == false) {
            let timeIntervalSinceLastGPSMovement = abs(self.lastMovingLocation!.timestamp.timeIntervalSince(self.lastActiveMonitoringLocation!.timestamp))
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
            if !self.isDefferringLocationUpdates {
                self.currentTrip?.saveAndMarkDirty()
                NotificationCenter.default.post(name: Notification.Name(rawValue: "RouteManagerDidUpdatePoints"), object: nil)
            }
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
                    if UserDefaults.standard.bool(forKey: "DebugVerbosityMode") {
                        let notif = UILocalNotification()
                        notif.alertBody = "🐞 Automatically unpausing Ride Report!"
                        notif.category = "DEBUG_CATEGORY"
                        UIApplication.shared.presentLocalNotificationNow(notif)
                    }
                #endif
                DDLogInfo("Auto-resuming tracking!")
                self.resumeTracking()
            } else {
                DDLogInfo("Tracking is Paused, not enterign Motion Monitoring state")
                return
            }
        }
        
        self.startLocationTrackingIfNeeded()
        self.numberOfActivityTypeQueriesSinceLastSignificantLocationChange = 0
        
        #if DEBUG
            if UserDefaults.standard.bool(forKey: "DebugVerbosityMode") {
                let notif = UILocalNotification()
                notif.alertBody = "🐞 Entered Motion Monitoring state!"
                notif.category = "DEBUG_CATEGORY"
                UIApplication.shared.presentLocalNotificationNow(notif)
            }
        #endif
        DDLogInfo("Entering Motion Monitoring state")
        
        self.locationManager.distanceFilter = kCLDistanceFilterNone
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.disallowDeferredLocationUpdates()
        
        if (self.currentPrototrip == nil) {
            self.currentPrototrip = Prototrip()
            if let currentGeofenceLocation = Profile.profile().lastGeofencedLocation {
                let _ = Location(byCopyingLocation: currentGeofenceLocation, prototrip: self.currentPrototrip!)
            }
            CoreDataManager.shared.saveContext()
        }
        
        self.disableAllGeofences() // will be re-enabled in stopMotionMonitoringAndSetupGeofences
        self.lastMotionMonitoringLocation = nil
    }
    
    private func stopMotionMonitoringAndSetupGeofences(aroundLocation location: CLLocation?) {
        DDLogInfo("Stopping motion monitoring")
                
        if let loc = location {
            #if DEBUG
                if UserDefaults.standard.bool(forKey: "DebugVerbosityMode") {
                    let notif = UILocalNotification()
                    notif.alertBody = "🐞 Geofenced!"
                    notif.category = "DEBUG_CATEGORY"
                    UIApplication.shared.presentLocalNotificationNow(notif)
                }
            #endif
            self.disableAllGeofences() // first remove any existing geofences
            self.setupGeofencesAroundCenter(loc)
        } else {
            DDLogInfo("Did not setup new geofence!")
        }
        
        if let prototrip = self.currentPrototrip {
            prototrip.managedObjectContext?.delete(prototrip)
            CoreDataManager.shared.saveContext()
            
            self.currentPrototrip = nil
        }
        
        self.lastMotionMonitoringActivityTypeQueryDate = nil
        self.locationManagerIsUpdating = false
        self.locationManager.disallowDeferredLocationUpdates()
        self.locationManager.stopUpdatingLocation()
        self.dateOfStoppingLastLocationManagerUpdates = Date()
    }
    
    private func processMotionMonitoringLocations(_ locations: [CLLocation]) {
        guard locations.count > 0 else {
            return
        }
        
        var locs = locations

        if let loc = locations.first, abs(loc.timestamp.timeIntervalSinceNow) > (self.locationTrackingDeferralTimeout + 10) {
            // https://github.com/KnockSoftware/Ride/issues/222
            DDLogVerbose(String(format: "Skipping stale location! Date: %@", loc.timestamp as CVarArg))
            if locations.count > 1 {
                locs.removeFirst()
            } else {
                return
            }
        }
        
        self.lastMotionMonitoringLocation = locs.first
        
        if (self.isGettingInitialLocationForGeofence == true && self.lastActiveMonitoringLocation?.horizontalAccuracy <= Location.acceptableLocationAccuracy) {
            self.isGettingInitialLocationForGeofence = false
            if (!self.didStartFromBackground) {
                DDLogVerbose("Got intial location for geofence. Stopping!")
                self.stopMotionMonitoringAndSetupGeofences(aroundLocation: self.lastMotionMonitoringLocation)
                return
            }
        }

        if (self.lastMotionMonitoringActivityTypeQueryDate == nil ||
            ((abs(self.lastMotionMonitoringActivityTypeQueryDate!.timeIntervalSinceNow) > timeIntervalBetweenMotionMonitoringActivityTypeQueries) && (self.currentMotionMonitoringSensorDataCollection == nil
                // the below OR clause is a work-around for https://github.com/KnockSoftware/Ride/issues/260 , whose root-cause is unknown
                || (abs(self.lastMotionMonitoringActivityTypeQueryDate!.timeIntervalSinceNow) > timeIntervalBeforeBailingOnStuckMotionMonitoringActivityTypeQuery)))) {
            
            self.lastMotionMonitoringActivityTypeQueryDate = Date()
            
            self.currentMotionMonitoringSensorDataCollection = SensorDataCollection(prototrip: self.currentPrototrip!)
            self.numberOfActivityTypeQueriesSinceLastSignificantLocationChange += 1
        
            MotionManager.shared.queryCurrentActivityType(forSensorDataCollection: self.currentMotionMonitoringSensorDataCollection!) {[weak self] (sensorDataCollection) -> Void in
                guard let strongSelf = self else {
                    return
                }
                
                let averageMovingSpeed = sensorDataCollection.averageMovingSpeed
                let averageSpeed = sensorDataCollection.averageSpeed
                strongSelf.currentMotionMonitoringSensorDataCollection = nil
                
                guard let prediction = sensorDataCollection.topActivityTypePrediction else {
                    // this should not ever happen.
                    DDLogVerbose("No activity type prediction found, continuing to monitor…")
                    return
                }
                
                let activityType = prediction.activityType
                let confidence = prediction.confidence.floatValue
            
                #if DEBUG
                    if UserDefaults.standard.bool(forKey: "DebugVerbosityMode") {
                        let notif = UILocalNotification()
                        notif.alertBody = "🐞 prediction: " + activityType.emoji + " confidence: " + String(confidence) + " speed: " + String(averageSpeed)
                        notif.category = "DEBUG_CATEGORY"
                        UIApplication.shared.presentLocalNotificationNow(notif)
                    }
                #endif
                
                DDLogVerbose(String(format: "Prediction: %i confidence: %f speed: %f", activityType.rawValue, confidence, averageSpeed))
                
                
                switch activityType {
                case .automotive where confidence > 0.8 && averageMovingSpeed >= 4:
                    DDLogVerbose("Starting automotive trip, high confidence")
                    
                    strongSelf.startTripFromLocation(locs.first!, predictedActivityType: .automotive)
                case .automotive where confidence > 0.6 && averageMovingSpeed >= 6:
                    DDLogVerbose("Starting automotive trip, high confidence")
                    
                    strongSelf.startTripFromLocation(locs.first!, predictedActivityType: .automotive)
                case .cycling where confidence > 0.8 && averageMovingSpeed >= 2:
                    DDLogVerbose("Starting cycling trip, high confidence")
                    
                    strongSelf.startTripFromLocation(locs.first!, predictedActivityType: .cycling)
                case .cycling where confidence > 0.4 && averageMovingSpeed >= 2.5 && averageMovingSpeed < 9:
                    DDLogVerbose("Starting cycling trip, low confidence and matched speed-range")
                    
                    strongSelf.startTripFromLocation(locs.first!, predictedActivityType: .cycling)
                case .running where confidence < 0.8 && averageMovingSpeed >= 2 && averageMovingSpeed < 6.5:
                    DDLogVerbose("Starting running trip, high confidence")
                    
                    strongSelf.startTripFromLocation(locs.first!, predictedActivityType: .running)
                case .bus where confidence > 0.8 && averageMovingSpeed >= 3:
                    DDLogVerbose("Starting transit trip, high confidence")
                    
                    strongSelf.startTripFromLocation(locs.first!, predictedActivityType: .bus)
                case .bus where confidence > 0.6 && averageMovingSpeed >= 6:
                    DDLogVerbose("Starting transit trip, low confidence and matching speed-range")
                    
                    strongSelf.startTripFromLocation(locs.first!, predictedActivityType: .bus)
                case .rail where confidence > 0.8 && averageMovingSpeed >= 3:
                    DDLogVerbose("Starting transit trip, high confidence")
                    
                    strongSelf.startTripFromLocation(locs.first!, predictedActivityType: .rail)
                case .rail where confidence > 0.6 && averageMovingSpeed >= 6:
                    DDLogVerbose("Starting transit trip, low confidence and matching speed-range")
                    
                    strongSelf.startTripFromLocation(locs.first!, predictedActivityType: .rail)
                case .walking where confidence > 0.9 && averageMovingSpeed < 0: // negative speed indicates that we couldnt get a location with a speed
                    DDLogVerbose("Walking, high confidence and no speed. stopping monitor…")
                    
                    strongSelf.stopMotionMonitoringAndSetupGeofences(aroundLocation: strongSelf.lastMotionMonitoringLocation)
                case .stationary where confidence > 0.9 && averageSpeed < 0:
                    DDLogVerbose("Stationary, high confidence and no speed. stopping monitor…")
                    
                    strongSelf.stopMotionMonitoringAndSetupGeofences(aroundLocation: strongSelf.lastMotionMonitoringLocation)
                case .walking where confidence > 0.5 && averageSpeed >= 0 && averageSpeed < 2:
                    DDLogVerbose("Walking, low confidence and matching speed-range. stopping monitor…")
                    
                    strongSelf.stopMotionMonitoringAndSetupGeofences(aroundLocation: strongSelf.lastMotionMonitoringLocation)
                case .stationary where confidence > 0.5 && averageSpeed >= 0 && averageSpeed < 0.65:
                    DDLogVerbose("Stationary, low confidence and matching speed-range. stopping monitor…")
                    
                    strongSelf.stopMotionMonitoringAndSetupGeofences(aroundLocation: strongSelf.lastMotionMonitoringLocation)
                case .unknown, .automotive, .cycling, .running, .bus, .rail, .stationary, .walking, .aviation:
                    if (strongSelf.numberOfActivityTypeQueriesSinceLastSignificantLocationChange >= strongSelf.maximumNumberOfActivityTypeQueriesSinceLastSignificantLocationChange) {
                        DDLogVerbose("Unknown activity type or low confidence, we've hit maximum tries, stopping monitoring!")
                        strongSelf.stopMotionMonitoringAndSetupGeofences(aroundLocation: strongSelf.lastMotionMonitoringLocation)
                    } else {
                        DDLogVerbose("Unknown activity type or low confidence, continuing to monitor…")
                    }
                }
            }
        }
        
        if let protoTrip = self.currentPrototrip {
            for location in locs {
                DDLogVerbose(String(format: "Location found in motion monitoring mode. Speed: %f, Accuracy: %f", location.speed, location.horizontalAccuracy))
                
                let loc = Location(location: location, prototrip: protoTrip)
                if let collection = self.currentMotionMonitoringSensorDataCollection {
                    loc.sensorDataCollection = collection
                }
            }
        }
        
        CoreDataManager.shared.saveContext()
    }
    
    //
    // MARK: - Helper methods
    //
    
    private func setupGeofencesAroundCenter(_ center: CLLocation) {
        DDLogInfo("Setting up geofences!")
        
        Profile.profile().setGeofencedLocation(center)
        CoreDataManager.shared.saveContext()
        
        // first we put a geofence in the middle as a fallback (exit event)
        let region = CLCircularRegion(center:center.coordinate, radius:self.backupGeofenceSleepRegionRadius, identifier: self.backupGeofenceIdentifier)
        self.geofenceSleepRegions.append(region)
        self.locationManager.startMonitoring(for: region)
        
        // the rest of our geofences are for looking at enter events
        // our first geofence will be directly north of our center
        let locationOfFirstGeofenceCenter = CLLocationCoordinate2DMake(center.coordinate.latitude + self.geofenceSleepRegionDistanceToCenter, center.coordinate.longitude)
        
        let theta = 2*Double.pi/Double(self.numberOfGeofenceSleepRegions)
        // after that, we go around in a circle, measuring an angles of index*theta away from the last geofence and then planting a geofence there
        for index in 0..<self.numberOfGeofenceSleepRegions {
            let dx = 2 * self.geofenceSleepRegionDistanceToCenter * sin(Double(index) * theta/2) * cos(Double(index) * theta/2)
            let dy = 2 * self.geofenceSleepRegionDistanceToCenter * sin(Double(index) * theta/2) * sin(Double(index) * theta/2)
            let locationOfNextGeofenceCenter = CLLocationCoordinate2DMake(locationOfFirstGeofenceCenter.latitude - dy, locationOfFirstGeofenceCenter.longitude - dx)

            let region = CLCircularRegion(center:locationOfNextGeofenceCenter, radius:self.geofenceSleepRegionRadius, identifier: String(format: "%@%i",self.geofenceIdentifierPrefix, index))
            self.geofenceSleepRegions.append(region)
            self.locationManager.startMonitoring(for: region)
        }
    }
    
    
    private func disableAllGeofences() {
        for region in self.locationManager.monitoredRegions {
            self.locationManager.stopMonitoring(for: region )
        }
        
        Profile.profile().setGeofencedLocation(nil)
        CoreDataManager.shared.saveContext()

        self.geofenceSleepRegions = []
    }
    
    
    private func beginDeferringUpdatesIfAppropriate() {
        if (CLLocationManager.deferredLocationUpdatesAvailable() && !self.isDefferringLocationUpdates && self.currentPrototrip == nil && self.currentTrip != nil) {
            DDLogVerbose("Re-deferring updates")
            self.isDefferringLocationUpdates = true
            self.locationManager.allowDeferredLocationUpdates(untilTraveled: CLLocationDistanceMax, timeout: self.locationTrackingDeferralTimeout)
        }
    }
    
    //
    // MARK: - Pause/Resuming Route Manager
    //
    
    func isPausedDueToBatteryLife() -> Bool {
#if (arch(i386) || arch(x86_64)) && os(iOS)
    return false
#endif
        return UIDevice.current.batteryLevel < self.minimumBatteryForTracking
    }
    
    func isPaused() -> Bool {
        return self.isPausedDueToBatteryLife() || self.isPausedByUser() || isPausedDueToUnauthorized()
    }
    
    func isPausedByUser() -> Bool {
        return UserDefaults.standard.bool(forKey: "RouteManagerIsPaused")
    }
    
    func isPausedDueToUnauthorized() -> Bool {
        return (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedAlways)
    }
    
    private func cancelScheduledAppResumeReminderNotifications() {
        for notif in UIApplication.shared.scheduledLocalNotifications! {
            let notification = notif 
            if (notification.category == "APP_PAUSED_CATEGORY") {
                UIApplication.shared.cancelLocalNotification(notification)
            }
        }
    }
    
    func pausedUntilDate() -> Date? {
        return UserDefaults.standard.object(forKey: "RouteManagerIsPausedUntilDate") as? Date
    }
    
    func pauseTracking(_ untilDate: Date! = nil) {
        if (isPaused()) {
            return
        }
        
        self.cancelScheduledAppResumeReminderNotifications()
        
        if (untilDate != nil) {
            UserDefaults.standard.set(untilDate, forKey: "RouteManagerIsPausedUntilDate")
        } else {
            let reminderNotification = UILocalNotification()
            reminderNotification.alertBody = "Ride Report is paused! Would you like to resume logging your bike rides?"
            reminderNotification.category = "APP_PAUSED_CATEGORY"
            reminderNotification.fireDate = Date.tomorrow()
            UIApplication.shared.scheduleLocalNotification(reminderNotification)
        }
        UserDefaults.standard.set(true, forKey: "RouteManagerIsPaused")
        UserDefaults.standard.synchronize()
        
        DDLogInfo("Paused Tracking")
        self.stopMotionMonitoringAndSetupGeofences(aroundLocation: self.locationManager.location)
        Profile.profile().setGeofencedLocation(nil)
    }
    
    private func pauseTrackingDueToLowBatteryLife(withLastLocation location: CLLocation?) {
        if (self.locationManagerIsUpdating) {
            // if we are currently updating, send the user a push and stop.
            let notif = UILocalNotification()
            notif.alertBody = "Whoa, your battery is pretty low. Ride Report will stop running until you get a charge!"
            UIApplication.shared.presentLocalNotificationNow(notif)
            
            DDLogInfo("Paused Tracking due to battery life")
            
            self.stopMotionMonitoringAndSetupGeofences(aroundLocation: location)
            Profile.profile().setGeofencedLocation(nil)
        }
    }
    
    func resumeTracking() {
        if (!isPaused()) {
            return
        }
        
        self.cancelScheduledAppResumeReminderNotifications()
        
        UserDefaults.standard.set(false, forKey: "RouteManagerIsPaused")
        UserDefaults.standard.set(nil, forKey: "RouteManagerIsPausedUntilDate")
        UserDefaults.standard.synchronize()
        
        DDLogInfo("Resume Tracking")
        self.startTrackingMachine()
    }
    
    private func startTrackingMachine() {
        DDLogVerbose("Starting Tracking Machine")

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
            if #available(iOS 9.0, *) {
                self.locationManager.allowsBackgroundLocationUpdates = true
            }
        }
    }

    //
    // MARK: - CLLocationManger Delegate Methods
    //
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DDLogVerbose("Did change authorization status")
        
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways) {
            self.startTrackingMachine()
        } else {
            // tell the user they need to give us access to the zion mainframes
            DDLogVerbose("Not authorized for location access!")
        }
        
        RouteManager.authorizationStatus = status
        NotificationCenter.default.post(name: Notification.Name(rawValue: "appDidChangeManagerAuthorizationStatus"), object: self)
    }
    
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        // Should never happen
        DDLogWarn("Did Pause location updates!")
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        // Should never happen
        DDLogWarn("Did Resume location updates!")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        DDLogWarn(String(format: "Got location monitoring error! %@", error as CVarArg))
        
        if (error._code == CLError.Code.regionMonitoringFailure.rawValue) {
            // exceeded max number of geofences
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DDLogWarn(String(format: "Got active tracking location error! %@", error as CVarArg))
        
        if (error._code == CLError.Code.denied.rawValue) {
            // alert the user and pause tracking.
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        self.isDefferringLocationUpdates = false
        
        if let err = error {
            if err._code != CLError.Code.deferredCanceled.rawValue {
                DDLogVerbose(String(format: "Error deferring updates: %@", err as CVarArg))
                return
            } else {
                DDLogVerbose("Deferred mode canceled, continuing…")
            }
        }
        
        if let trip = self.currentTrip {
            trip.saveAndMarkDirty()
            NotificationCenter.default.post(name: Notification.Name(rawValue: "RouteManagerDidUpdatePoints"), object: nil)
        }

        DDLogVerbose("Finished deferring updates.")
     
        if let date = self.lastActiveTrackingActivityTypeQueryDate, abs(date.timeIntervalSinceNow) < 5 {
            // if we've recently finished an activity query, go ahead and redefer as needed
            self.beginDeferringUpdatesIfAppropriate()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
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
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
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
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DDLogVerbose("Received location updates.")
        
#if (arch(i386) || arch(x86_64)) && os(iOS)
        // skip this check
#else
        if (UIDevice.current.batteryLevel < self.minimumBatteryForTracking)  {
            self.pauseTrackingDueToLowBatteryLife(withLastLocation: locations.first)
            return
        }
#endif
        
        if (self.startedInBackgroundBackgroundTaskID != UIBackgroundTaskInvalid) {
            DDLogInfo("Ending Route Manager Started in background Background task!")
            
            UIApplication.shared.endBackgroundTask(self.startedInBackgroundBackgroundTaskID)
            self.startedInBackgroundBackgroundTaskID = UIBackgroundTaskInvalid
        }
        
        if (self.currentTrip != nil) {
            self.processActiveTrackingLocations(locations)
        } else if (self.currentPrototrip != nil) {
            self.processMotionMonitoringLocations(locations)
        } else if (self.dateOfStoppingLastLocationManagerUpdates == nil || abs(self.dateOfStoppingLastLocationManagerUpdates!.timeIntervalSinceNow) > 2){
            // sometimes calling stopUpdatingLocation will continue to delvier a few locations. thus, keep track of dateOfStoppingLastLocationManagerUpdates to avoid
            // consider getting these updates as significiation location changes.
            
            if (self.currentTrip == nil && self.currentPrototrip == nil) {
                DDLogVerbose("Got significant location, entering Motion Monitoring state.")
                self.startMotionMonitoring()
            } else {
                DDLogVerbose("Got significant location but already in Motion Monitoring or active tracking state.")
            }
        }
    }
}
