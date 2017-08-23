//
//  RouteManager.swift
//  Ride Report
//
//  Created by William Henderson on 10/27/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreLocation

private func DDLogStateChange(_ logMessage: String) {
    DDLogInfo("## " + logMessage)
}

class RouteManager : NSObject, CLLocationManagerDelegate {
    var sensorComponent: SensorManagerComponent!
    
    var stopTripAndDeliverNotificationBackgroundTaskID : UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    var locationUpdateBackgroundTaskID : UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
 
    // State
    static var authorizationStatus : CLAuthorizationStatus = CLAuthorizationStatus.notDetermined
    
    private var didStartFromBackground : Bool = false
    private var isDefferringLocationUpdates : Bool = false
    private var isLocationManagerUsingGPS : Bool = false
    
    private var startTimeOfPossibleWalkingSession : Date? = nil
    private var dateOfStoppingLocationManagerGPS : Date?
    private var numberOfNonMovingContiguousGPSLocations = 0
    
    private let minimumNumberOfNonMovingContiguousGPSLocations = 3
    
    internal private(set) var currentTrip : Trip?
    private var locationsPendingTripStart: [Location] = []
    private var aggregatorsPendingTripStart: [PredictionAggregator] = []
    private var mostRecentGPSLocation: CLLocation?
    private var mostRecentLocationWithSufficientSpeed: CLLocation?
    private var currentPredictionAggregator: PredictionAggregator?
    
    // Constants
    let minimumSpeedToContinueMonitoring : CLLocationSpeed = 2.25 // ~5mph
    
    let minimumSpeedForPostTripWalkingAround : CLLocationSpeed = 0.2
    let minimumTimeIntervalBeforeDeclaringWalkingSession : TimeInterval = 10
    let timeIntervalForConsideringStoppedTrip : TimeInterval = 60
    
    let timeIntervalBeforeStoppedTripDueToUsuableSpeedReadings : TimeInterval = 60
    let timeIntervalForStoppingTripWithoutSubsequentWalking : TimeInterval = 200
    let timeIntervalForLocationTrackingDeferral : TimeInterval = 120
    
    let minimumBatteryForTracking : Float = 0.2
    
    //
    // MARK: - Initializers
    //
    
    public func startup(_ fromBackground: Bool) {
        if (fromBackground) {
            self.didStartFromBackground = true
            
            // launch a background task to be sure we dont get killed until we get our first location update!
            if (self.locationUpdateBackgroundTaskID == UIBackgroundTaskInvalid) {
                DDLogInfo(String(format: "Launched in background, beginning Route Manager Location Update Background task! Time remaining: %@", UIApplication.shared.backgroundTimeRemaining.debugDescription()))
                self.locationUpdateBackgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    self.locationUpdateBackgroundTaskID = UIBackgroundTaskInvalid
                    DDLogInfo("Route Manager Location Update Background task expired!")
                })
            }
        }
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        self.sensorComponent.locationManager.delegate = self
        self.sensorComponent.locationManager.requestAlwaysAuthorization()
        self.sensorComponent.locationManager.activityType = CLActivityType.fitness
        self.sensorComponent.locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    //
    // MARK: - State changes
    //
    
    
    private func startTrackingMachine() {
        DDLogStateChange("Starting Tracking Machine")
        
        self.sensorComponent.locationManager.startMonitoringSignificantLocationChanges()
        self.sensorComponent.locationManager.startMonitoringVisits()
        self.sensorComponent.locationManager.startUpdatingLocation()
        if #available(iOS 9.0, *) {
            self.sensorComponent.locationManager.allowsBackgroundLocationUpdates = true
        }
        
        self.enterBackgroundState()
    }
    
    private func enterBackgroundState() {
        DDLogStateChange("Entering background state")
        
        #if DEBUG
            if UserDefaults.standard.bool(forKey: "DebugVerbosityMode") {
                let notif = UILocalNotification()
                notif.alertBody = "🐞 Entered background state!"
                notif.category = "DEBUG_CATEGORY"
                UIApplication.shared.presentLocalNotificationNow(notif)
            }
        #endif
        
        self.isLocationManagerUsingGPS = false
        self.mostRecentLocationWithSufficientSpeed = nil
        self.mostRecentGPSLocation = nil
        
        self.sensorComponent.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.sensorComponent.locationManager.distanceFilter = 300
        self.sensorComponent.locationManager.disallowDeferredLocationUpdates()
        self.dateOfStoppingLocationManagerGPS = Date()
        
        if (self.locationUpdateBackgroundTaskID != UIBackgroundTaskInvalid) {
            DDLogInfo("Ending Route Manager Location Update Background task!")
            
            UIApplication.shared.endBackgroundTask(self.locationUpdateBackgroundTaskID)
            self.locationUpdateBackgroundTaskID = UIBackgroundTaskInvalid
        }
    }
    
    private func startLocationTrackingUsingGPS() {
        guard !self.isLocationManagerUsingGPS else {
            return
        }
        
        self.isLocationManagerUsingGPS = true
        self.sensorComponent.locationManager.distanceFilter = kCLDistanceFilterNone
        self.sensorComponent.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        if (self.locationUpdateBackgroundTaskID == UIBackgroundTaskInvalid) {
            DDLogInfo(String(format: "Beginning Route Manager Location Update Background task! Time remaining: %@", UIApplication.shared.backgroundTimeRemaining.debugDescription()))
            self.locationUpdateBackgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                self.locationUpdateBackgroundTaskID = UIBackgroundTaskInvalid
                DDLogInfo("Route Manager Location Update Background task expired!")
            })
        }
    }
    
    func abortTrip() {
        self.stopTripAndEnterBackgroundState(abort: true)
    }
    
    func stopTripAndEnterBackgroundState(abort: Bool = false, stoppedManually: Bool = false) {
        defer {
            self.enterBackgroundState()
        }
        
        guard let stoppedTrip = self.currentTrip else {
            return
        }
        
        self.currentTrip = nil
        
        DDLogStateChange("Stopping trip")
        
        self.startTimeOfPossibleWalkingSession = nil
        self.numberOfNonMovingContiguousGPSLocations = 0
        
        if (abort || stoppedTrip.locationCount() <= 6) {
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
            if (self.stopTripAndDeliverNotificationBackgroundTaskID == UIBackgroundTaskInvalid) {
                DDLogInfo("Beginning Route Manager Stop Trip Background task!")
                self.stopTripAndDeliverNotificationBackgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    self.stopTripAndDeliverNotificationBackgroundTaskID = UIBackgroundTaskInvalid
                    DDLogInfo("Route Manager Background task expired!")
                })
            }
            
            if (stoppedManually) {
                stoppedTrip.wasStoppedManually = true
            }
            
            stoppedTrip.close() {
                stoppedTrip.sendTripCompletionNotificationLocally(secondsFromNow:15.0)
                APIClient.shared.syncTrip(stoppedTrip, includeFullLocations: false).apiResponse() { (response) -> Void in
                    switch response.result {
                    case .success(_):
                        DDLogInfo("Trip summary was successfully sync'd.")
                    case .failure(_):
                        DDLogInfo("Trip summary failed to sync.")
                    }
                    
                    if (self.stopTripAndDeliverNotificationBackgroundTaskID != UIBackgroundTaskInvalid) {
                        DDLogInfo("Ending Route Manager Stop Trip Background task!")
                        
                        UIApplication.shared.endBackgroundTask(self.stopTripAndDeliverNotificationBackgroundTaskID)
                        self.stopTripAndDeliverNotificationBackgroundTaskID = UIBackgroundTaskInvalid
                    }
                }
            }
        }
    }
    
    // MARK: Location Processing
    
    private func processGPSLocations(_ locations:[CLLocation], forTrip trip: Trip) {
        guard let firstLocation = locations.first else {
            return
        }
        
        // initialize state locations
        if (self.mostRecentLocationWithSufficientSpeed == nil) {
            self.mostRecentLocationWithSufficientSpeed = firstLocation
        }
        if (self.mostRecentGPSLocation == nil) {
            self.mostRecentGPSLocation = firstLocation
        }
        
        var gotGPSSpeed = false
        
        for location in locations {
            DDLogVerbose(String(format: "Location found for bike trip. Speed: %f, Accuracy: %f", location.speed, location.horizontalAccuracy))
            
            _ = Location(location: location, trip: trip)
            
            var manualSpeed : CLLocationSpeed = 0
            if (location.speed >= 0) {
                gotGPSSpeed = true
                if (location.speed >= self.minimumSpeedToContinueMonitoring) {
                    self.numberOfNonMovingContiguousGPSLocations = 0
                } else {
                    self.numberOfNonMovingContiguousGPSLocations += 1
                }
            } else if let mostRecentGPSLocation = self.mostRecentGPSLocation, location.speed < 0 {
                // Some times locations given will not have a speed (a negative speed).
                // Hence, we also calculate a 'manual' speed from the current location to the last one
                
                manualSpeed = mostRecentGPSLocation.calculatedSpeedFromLocation(location)
                DDLogVerbose(String(format: "Manually found speed: %f", manualSpeed))
            }
            
            if let mostRecentGPSLocation = self.mostRecentGPSLocation, location.timestamp.timeIntervalSinceNow > mostRecentGPSLocation.timestamp.timeIntervalSinceNow {
                // if the event is more recent than the one we already have
                self.mostRecentGPSLocation = location
            }
            
            if (location.speed >= self.minimumSpeedToContinueMonitoring ||
                (manualSpeed >= self.minimumSpeedToContinueMonitoring && manualSpeed < 20.0)) {
                // we are moving sufficiently fast, continue the trip
                self.startTimeOfPossibleWalkingSession = nil
                
                if (location.horizontalAccuracy <= Location.acceptableLocationAccuracy) {
                    if (location.timestamp.timeIntervalSinceNow > self.mostRecentLocationWithSufficientSpeed!.timestamp.timeIntervalSinceNow) {
                        // if the event is more recent than the one we already have
                        self.mostRecentLocationWithSufficientSpeed = location
                    }
                }
            } else if (location.speed < self.minimumSpeedToContinueMonitoring) {
                if (location.speed >= self.minimumSpeedForPostTripWalkingAround) {
                    if (self.startTimeOfPossibleWalkingSession == nil || self.startTimeOfPossibleWalkingSession!.compare(location.timestamp) == .orderedDescending) {
                        self.startTimeOfPossibleWalkingSession = location.timestamp
                    }
                } else {
                    if let startDate = self.startTimeOfPossibleWalkingSession, location.timestamp.timeIntervalSince(startDate) < self.minimumTimeIntervalBeforeDeclaringWalkingSession {
                        self.startTimeOfPossibleWalkingSession = nil
                    }
                }
            }
        }
        
        _ = trip.saveLocationsAndUpdateInProgressLength()
        
        if let mostRecentLocationWithSufficientSpeed = self.mostRecentLocationWithSufficientSpeed, let mostRecentGPSLocation = self.mostRecentGPSLocation {
            if (gotGPSSpeed == true && abs(mostRecentLocationWithSufficientSpeed.timestamp.timeIntervalSince(mostRecentGPSLocation.timestamp)) > self.timeIntervalForConsideringStoppedTrip){
                if (self.numberOfNonMovingContiguousGPSLocations >= self.minimumNumberOfNonMovingContiguousGPSLocations) {
                    if let startDate = self.startTimeOfPossibleWalkingSession, mostRecentGPSLocation.timestamp.timeIntervalSince(startDate) >= self.minimumTimeIntervalBeforeDeclaringWalkingSession {
                        DDLogVerbose("Started Walking after stopping")
                        self.stopTripAndEnterBackgroundState()
                    } else if (abs(mostRecentLocationWithSufficientSpeed.timestamp.timeIntervalSince(mostRecentGPSLocation.timestamp)) > self.timeIntervalForStoppingTripWithoutSubsequentWalking) {
                        DDLogVerbose("Moving too slow for too long")
                        self.stopTripAndEnterBackgroundState()
                    }
                } else {
                    DDLogVerbose("Not enough slow locations to stop, waiting…")
                }
            } else if (gotGPSSpeed == false) {
                let timeIntervalSinceLastGPSMovement = abs(mostRecentLocationWithSufficientSpeed.timestamp.timeIntervalSince(mostRecentGPSLocation.timestamp))
                var maximumTimeIntervalBetweenGPSMovements = self.timeIntervalBeforeStoppedTripDueToUsuableSpeedReadings
                if (self.isDefferringLocationUpdates) {
                    // if we are deferring, give extra time. this is because we will sometime get
                    // bad locations (ie from startMonitoringSignificantLocationChanges) during our deferral period.
                    maximumTimeIntervalBetweenGPSMovements += self.timeIntervalForLocationTrackingDeferral
                }
                if (timeIntervalSinceLastGPSMovement > maximumTimeIntervalBetweenGPSMovements) {
                    DDLogVerbose("Went too long with unusable speeds.")
                    self.stopTripAndEnterBackgroundState()
                } else {
                    DDLogVerbose("Nothing but unusable speeds. Awaiting next update")
                }
            }
        }
    }
    
    private func processLocations(_ locations:[CLLocation]) {
        if let trip = self.currentTrip, self.isLocationManagerUsingGPS {
            processGPSLocations(locations, forTrip: trip)
        } else if (self.dateOfStoppingLocationManagerGPS != nil && abs(self.dateOfStoppingLocationManagerGPS!.timeIntervalSinceNow) < 2) {
            // sometimes turning off GPS will continue to delvier a few locations. thus, keep track of dateOfStoppingLocationManagerGPS to avoid
            // considering these updates as significiation location changes.
            return
        } else {
            // we are not actively using GPS. we don't know what mode we are using and whether or not we should start a new currentTrip.
            var locs: [Location] = []
            for location in locations {
                let loc = Location(location: location)
                locs.append(loc)
            }
            self.runPredictionAndStartTripIfNeeded(withLocations: locs)
        }
    }
    
    private func runPredictionAndStartTripIfNeeded(withLocations locations:[Location]) {
        var firstLocation = locations.first
        
        if self.currentPredictionAggregator == nil {
            let newAggregator = PredictionAggregator()
            self.aggregatorsPendingTripStart.append(newAggregator)
            self.currentPredictionAggregator = newAggregator
            
            sensorComponent.classificationManager.predictCurrentActivityType(predictionAggregator: newAggregator) {[weak self] (prediction) -> Void in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.currentPredictionAggregator = nil
                
                guard let prediction = prediction.aggregatePredictedActivity, prediction.activityType != .unknown else {
                    DDLogVerbose("No valid prediction found, continuing to monitor…")
                    return
                }
                
                DDLogVerbose(String(format: "Prediction: %@ confidence: %f", prediction.activityType.emoji, prediction.confidence))
                
                if prediction.activityType != .stationary && prediction.confidence >= PredictionAggregator.highConfidence {
                    let priorTrip = strongSelf.currentTrip ?? Trip.mostRecentTrip()
                    
                    if let trip = priorTrip, let loc = firstLocation, strongSelf.tripQualifiesForResumption(trip: trip, fromActivityType: prediction.activityType, fromLocation: loc) {
                        DDLogStateChange("Resuming trip")
                        
                        trip.reopen()
                        strongSelf.currentTrip = trip
                    } else {
                        DDLogStateChange("Opening new trip")
                        if let trip = strongSelf.currentTrip, !trip.isClosed {
                            trip.close()
                        }
                        strongSelf.currentTrip = Trip()
                        if prediction.activityType != .stationary {
                            strongSelf.currentTrip!.activityType = prediction.activityType
                        }
                    }
                    
                    for aggregator in strongSelf.aggregatorsPendingTripStart {
                        strongSelf.currentTrip!.predictionAggregators.insert(aggregator)
                    }
                    
                    strongSelf.aggregatorsPendingTripStart = []
                    
                    for location in strongSelf.locationsPendingTripStart {
                        location.trip = strongSelf.currentTrip!
                    }
                    strongSelf.locationsPendingTripStart = []
                    for location in locations {
                        location.trip = strongSelf.currentTrip!
                    }
                    
                    _ = strongSelf.currentTrip!.saveLocationsAndUpdateInProgressLength(intermittently: false)
                    
                    if (strongSelf.currentTrip!.activityType == .cycling) {
                        strongSelf.startLocationTrackingUsingGPS()
                    }
                } else {
                    if prediction.activityType == .stationary && strongSelf.currentTrip == nil {
                        // don't include stationary samples in a trip when starting a new trip
                        // if a trip is already underway, we do include them (for example if the user stops at a traffic light)
                    } else {
                        strongSelf.locationsPendingTripStart.append(contentsOf: locations)
                    }
                }
            }
        }
    }

    
    //
    // MARK: - Helper methods
    //
    
    private func tripQualifiesForResumption(trip: Trip, fromActivityType activityType: ActivityType, fromLocation location: Location)->Bool {
        if (trip.rating.choice != .notSet || trip.wasStoppedManually) {
            // dont resume rated or manually stopped trips
            return false
        }
        
        if (trip.activityType != activityType) {
            if (trip.activityType.isMotorizedMode && activityType.isMotorizedMode) {
                // if both trips are motorized, allow resumption since our mode detection within motorized mode is not great
            } else if (activityType == .stationary || trip.activityType == .unknown) {
                // unknown and stationary activities could be a part of any mode
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
        
        return abs(trip.endDate.timeIntervalSince(location.date)) < timeoutInterval
    }
    
    private func beginDeferringUpdatesIfAppropriate() {
        if (CLLocationManager.deferredLocationUpdatesAvailable() && !self.isDefferringLocationUpdates) {
            DDLogVerbose("Re-deferring updates")
            self.isDefferringLocationUpdates = true
            self.sensorComponent.locationManager.allowDeferredLocationUpdates(untilTraveled: CLLocationDistanceMax, timeout: self.timeIntervalForLocationTrackingDeferral)
        }
    }
    
    private func cancelScheduledAppResumeReminderNotifications() {
        for notif in UIApplication.shared.scheduledLocalNotifications! {
            let notification = notif
            if (notification.category == "APP_PAUSED_CATEGORY") {
                UIApplication.shared.cancelLocalNotification(notification)
            }
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
        return (self.sensorComponent.locationManager.authorizationStatus() != CLAuthorizationStatus.authorizedAlways)
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
        
        DDLogStateChange("Paused Tracking")
        
        self.stopTripAndEnterBackgroundState()
    }
    
    private func pauseTrackingDueToLowBatteryLife(withLastLocation location: CLLocation?) {
        if (self.isLocationManagerUsingGPS) {
            // if we are currently updating, send the user a push and stop.
            let notif = UILocalNotification()
            notif.alertBody = "Whoa, your battery is pretty low. Ride Report will stop running until you get a charge!"
            UIApplication.shared.presentLocalNotificationNow(notif)
            
            DDLogStateChange("Paused Tracking due to battery life")
            
            self.stopTripAndEnterBackgroundState()
        }
    }
    
    private func checkPausedAndResumeIfNeeded()->Bool {
        if (isPaused()) {
            let pausedUntilDate = self.pausedUntilDate()
            if (pausedUntilDate != nil && pausedUntilDate!.timeIntervalSinceNow <= 0.0) {
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
                
                return true
            } else {
                DDLogInfo("Tracking is Paused, not enterign Motion Monitoring state")
                return false
            }
        }
        
        return true
    }
    
    func resumeTracking() {
        if (!isPaused()) {
            return
        }
        
        self.cancelScheduledAppResumeReminderNotifications()
        
        UserDefaults.standard.set(false, forKey: "RouteManagerIsPaused")
        UserDefaults.standard.set(nil, forKey: "RouteManagerIsPausedUntilDate")
        UserDefaults.standard.synchronize()
        
        DDLogStateChange("Resume Tracking")
        self.startTrackingMachine()
    }
    
    //
    // MARK: - CLLocationManger Delegate Methods
    //
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DDLogVerbose("Did change authorization status")
        
        if (self.sensorComponent.locationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways) {
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
        DDLogWarn("Unexpectedly paused location updates!")
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        // Should never happen
        DDLogWarn("Unexpectedly resumed location updates!")
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

        DDLogVerbose("Finished deferring updates.")
     
        self.beginDeferringUpdatesIfAppropriate()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard checkPausedAndResumeIfNeeded() else {
            return
        }
        
        DDLogVerbose("Received location updates.")
        defer {
            if (self.locationUpdateBackgroundTaskID != UIBackgroundTaskInvalid) {
                UIApplication.shared.endBackgroundTask(self.locationUpdateBackgroundTaskID)
                self.locationUpdateBackgroundTaskID = UIBackgroundTaskInvalid
            }
            
            #if DEBUG
                DDLogInfo(String(format: "Restarting route manager background task, time remaining: %@", UIApplication.shared.backgroundTimeRemaining.debugDescription()))
            #endif
            
            if (self.isLocationManagerUsingGPS) {
                self.locationUpdateBackgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    self.locationUpdateBackgroundTaskID = UIBackgroundTaskInvalid
                    DDLogInfo("Route Manager Location Update Background task expired!")
                })
            } else {
                DDLogInfo("Ended Route Manager Location Update Background task!")
            }
        }
        
        #if (arch(i386) || arch(x86_64)) && os(iOS)
            // skip this check
        #else
            guard UIDevice.current.batteryLevel > self.minimumBatteryForTracking else  {
                self.pauseTrackingDueToLowBatteryLife(withLastLocation: locations.first)
                return
            }
        #endif
        
        self.processLocations(locations)
    }
    
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        guard checkPausedAndResumeIfNeeded() else {
            return
        }
        
        if (visit.departureDate == NSDate.distantFuture) {
            DDLogInfo("User arrived")
            // the user has arrived but not yet left
            if !self.isLocationManagerUsingGPS {
                // ignore arrivals that occur during GPS usage
                
                if let trip = self.currentTrip, !trip.isClosed {
                    DDLogStateChange("Ending trip with arrival")

                    let loc = Location(withVisit: visit, isArriving: true)
                    loc.trip = trip
                    trip.close()
                    self.currentTrip = nil
                }
            }
        } else {
            DDLogInfo("User departed")
            // the user has departed
            let loc = Location(withVisit: visit, isArriving: false)
            
            if let trip = self.currentTrip {
                loc.trip = trip
                CoreDataManager.shared.saveContext()
            } else {
                self.runPredictionAndStartTripIfNeeded(withLocations: [loc])
            }
        }
    }
}
