//
//  RouteManager.swift
//  Ride Report
//
//  Created by William Henderson on 10/27/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreLocation
import CocoaLumberjack

private func DDLogStateChange(_ logMessage: String) {
    DDLogInfo("## " + logMessage)
}

public class RouteManager : NSObject, CLLocationManagerDelegate {
    var routeRecorder: RouteRecorder!
    
    var stopRouteAndDeliverNotificationBackgroundTaskID : UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    var locationUpdateBackgroundTaskID : UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    private var didStartFromBackground : Bool = false
    private var isDefferringLocationUpdates : Bool = false
    private var isLocationManagerUsingGPS : Bool = false
    
    private var startTimeOfPossibleWalkingSession : Date? = nil
    private var dateOfStoppingLocationManagerGPS : Date?
    private var numberOfNonMovingContiguousGPSLocations = 0
    
    private let minimumNumberOfNonMovingContiguousGPSLocations = 3
    
    internal private(set) var currentRoute : Route?
    private var pendingAggregators: [PredictionAggregator] = []
    private var mostRecentGPSLocation: CLLocation?
    private var mostRecentLocationWithSufficientSpeed: CLLocation?
    private var currentPredictionAggregator: PredictionAggregator?
    
    // Constants
    let minimumSpeedToContinueMonitoring : CLLocationSpeed = 2 // ~5mph
    
    let minimumSpeedForPostRouteWalkingAround : CLLocationSpeed = 0.2
    let minimumTimeIntervalBeforeDeclaringWalkingSession : TimeInterval = 10
    let timeIntervalForConsideringStoppedRoute : TimeInterval = 60
    
    let timeIntervalBeforeStoppedRouteDueToUsuableSpeedReadings : TimeInterval = 90
    let timeIntervalForStoppingRouteWithoutSubsequentWalking : TimeInterval = 200
    let timeIntervalForLocationTrackingDeferral : TimeInterval = 120
    
    let minimumBatteryForTracking : Float = 0.0
    
    private var pendingRegistrationHandler: (()->Void)? = nil
    
    //
    // MARK: - Initializers
    //
    
    public func startup(_ fromBackground: Bool, handler: @escaping ()->Void = {() in }) {
        self.pendingRegistrationHandler = handler
        
        if (fromBackground) {
            self.didStartFromBackground = true
            
            // launch a background task to be sure we dont get killed until we get our first location update!
            if (self.locationUpdateBackgroundTaskID == UIBackgroundTaskInvalid) {
                DDLogInfo(String(format: "Launched in background, beginning Route Manager Location Update Background task! Time remaining: %@", UIApplication.shared.backgroundTimeRemaining.debugDescription()))
                self.locationUpdateBackgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    DDLogInfo("Route Manager Location Update Background task expired!")

                    UIApplication.shared.endBackgroundTask(self.locationUpdateBackgroundTaskID)
                    self.locationUpdateBackgroundTaskID = UIBackgroundTaskInvalid
                })
            }
        }
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        self.routeRecorder.locationManager.delegate = self
        if RouteManager.authorizationStatus() == .notDetermined {
            self.routeRecorder.locationManager.requestAlwaysAuthorization()
        } else {
            self.startTrackingMachine()
            
            if let handler = self.pendingRegistrationHandler {
                DispatchQueue.main.async {
                    self.pendingRegistrationHandler = nil
                    handler()
                }
            }
        }
        self.routeRecorder.locationManager.activityType = CLActivityType.fitness
        self.routeRecorder.locationManager.pausesLocationUpdatesAutomatically = false
        
        DispatchQueue.main.async {
            self.closeOpenRoutes()
        }
    }
    
    private func closeOpenRoutes() {
        for route in Route.openRoutes() {
            if (route.locations.count <= 3) {
                // if it doesn't more than 3 points, toss it.
                DDLogInfo("Canceling route with fewer than 3 locations")
                route.cancel()
            } else if !route.isClosed {
                route.close()
            }
        }
    }
    
    //
    // MARK: - State changes
    //
    
    
    private func startTrackingMachine() {
        DDLogStateChange("Starting Tracking Machine")
        
        self.routeRecorder.locationManager.startMonitoringSignificantLocationChanges()
        self.routeRecorder.locationManager.startMonitoringVisits()
        self.routeRecorder.locationManager.startUpdatingLocation()
        if #available(iOS 9.0, *) {
            self.routeRecorder.locationManager.allowsBackgroundLocationUpdates = true
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
        
        // Testing of accuracy and filter performance:
        // https://stackoverflow.com/questions/3411629/decoding-the-cllocationaccuracy-consts
        // http://evgenii.com/blog/power-consumption-of-location-services-in-ios/
        self.routeRecorder.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.routeRecorder.locationManager.distanceFilter = 300
        
        self.routeRecorder.locationManager.disallowDeferredLocationUpdates()
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
        self.routeRecorder.locationManager.distanceFilter = kCLDistanceFilterNone
        self.routeRecorder.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        if (self.locationUpdateBackgroundTaskID == UIBackgroundTaskInvalid) {
            DDLogInfo(String(format: "Beginning Route Manager Location Update Background task! Time remaining: %@", UIApplication.shared.backgroundTimeRemaining.debugDescription()))
            self.locationUpdateBackgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                DDLogInfo("Route Manager Location Update Background task expired!")

                UIApplication.shared.endBackgroundTask(self.locationUpdateBackgroundTaskID)
                self.locationUpdateBackgroundTaskID = UIBackgroundTaskInvalid
            })
        }
    }
    
    public func abortRoute() {
        self.stopGPSRouteAndEnterBackgroundState(abort: true)
    }
    
    public func stopRoute() {
        self.stopGPSRouteAndEnterBackgroundState(abort: false, stoppedManually: true)
    }
    
    func stopGPSRouteAndEnterBackgroundState(abort: Bool = false, stoppedManually: Bool = false) {
        defer {
            self.enterBackgroundState()
        }
        
        guard let stoppedRoute = self.currentRoute else {
            return
        }
        
        self.currentRoute = nil
        
        DDLogStateChange("Stopping route")
        
        self.startTimeOfPossibleWalkingSession = nil
        self.numberOfNonMovingContiguousGPSLocations = 0
        
        if (abort || stoppedRoute.locationCount() <= 6) {
            // if it is aborted or it doesn't more than 6 points, toss it.
            #if DEBUG
                if UserDefaults.standard.bool(forKey: "DebugVerbosityMode") {
                    let notif = UILocalNotification()
                    notif.alertBody = "🐞 Canceled Route"
                    notif.category = "DEBUG_CATEGORY"
                    UIApplication.shared.presentLocalNotificationNow(notif)
                }
            #endif
            stoppedRoute.cancel()
        } else {
            if (self.stopRouteAndDeliverNotificationBackgroundTaskID == UIBackgroundTaskInvalid) {
                DDLogInfo("Beginning Route Manager Stop Route Background task!")
                self.stopRouteAndDeliverNotificationBackgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                    DDLogInfo("Route Manager Background task expired!")

                    UIApplication.shared.endBackgroundTask(self.stopRouteAndDeliverNotificationBackgroundTaskID)
                    self.stopRouteAndDeliverNotificationBackgroundTaskID = UIBackgroundTaskInvalid
                })
            }
            
            if (stoppedManually) {
                stoppedRoute.wasStoppedManually = true
            }
            
            if stoppedRoute.averageMovingSpeed > 0 && stoppedRoute.averageMovingSpeed < 2 {
                // identify short walking trips that were mistaken for bike trips
                DDLogInfo("Re-classifiying bike trip as walking trip due to low speed.")
                stoppedRoute.activityType = .walking
            }
            
            stoppedRoute.close()
            APIClient.shared.uploadRoute(stoppedRoute, includeFullLocations: false).apiResponse() { (response) -> Void in
                switch response.result {
                case .success(_):
                    DDLogInfo("Route summary was successfully sync'd.")
                case .failure(_):
                    DDLogInfo("Route summary failed to sync.")
                }
                
                if (self.stopRouteAndDeliverNotificationBackgroundTaskID != UIBackgroundTaskInvalid) {
                    DDLogInfo("Ending Route Manager Stop Route Background task!")
                    
                    UIApplication.shared.endBackgroundTask(self.stopRouteAndDeliverNotificationBackgroundTaskID)
                    self.stopRouteAndDeliverNotificationBackgroundTaskID = UIBackgroundTaskInvalid
                }
            }
            
        }
    }
    
    // MARK: Location Processing
    
    private func processGPSLocations(_ locations:[CLLocation], forRoute route: Route) {
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
            DDLogVerbose(String(format: "Location found for bike route. Speed: %f, Accuracy: %f", location.speed, location.horizontalAccuracy))
            
            _ = Location(recordedLocation: location, isActiveGPS: true, route: route)
            
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
                // we are moving sufficiently fast, continue the route
                self.startTimeOfPossibleWalkingSession = nil
                
                if (location.horizontalAccuracy <= Location.acceptableLocationAccuracy) {
                    if (location.timestamp.timeIntervalSinceNow > self.mostRecentLocationWithSufficientSpeed!.timestamp.timeIntervalSinceNow) {
                        // if the event is more recent than the one we already have
                        self.mostRecentLocationWithSufficientSpeed = location
                    }
                }
            } else if (location.speed < self.minimumSpeedToContinueMonitoring) {
                if (location.speed >= self.minimumSpeedForPostRouteWalkingAround) {
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
        
        _ = route.saveLocationsAndUpdateLength()
        self.beginDeferringUpdatesIfAppropriate()
        
        if let mostRecentLocationWithSufficientSpeed = self.mostRecentLocationWithSufficientSpeed, let mostRecentGPSLocation = self.mostRecentGPSLocation {
            if (gotGPSSpeed == true && abs(mostRecentLocationWithSufficientSpeed.timestamp.timeIntervalSince(mostRecentGPSLocation.timestamp)) > self.timeIntervalForConsideringStoppedRoute){
                if (self.numberOfNonMovingContiguousGPSLocations >= self.minimumNumberOfNonMovingContiguousGPSLocations) {
                    if let startDate = self.startTimeOfPossibleWalkingSession, mostRecentGPSLocation.timestamp.timeIntervalSince(startDate) >= self.minimumTimeIntervalBeforeDeclaringWalkingSession {
                        DDLogVerbose("Started Walking after stopping")
                        self.stopGPSRouteAndEnterBackgroundState()
                    } else if (abs(mostRecentLocationWithSufficientSpeed.timestamp.timeIntervalSince(mostRecentGPSLocation.timestamp)) > self.timeIntervalForStoppingRouteWithoutSubsequentWalking) {
                        DDLogVerbose("Moving too slow for too long")
                        self.stopGPSRouteAndEnterBackgroundState()
                    }
                } else {
                    DDLogVerbose("Not enough slow locations to stop, waiting…")
                }
            } else if (gotGPSSpeed == false) {
                let timeIntervalSinceLastGPSMovement = abs(mostRecentLocationWithSufficientSpeed.timestamp.timeIntervalSince(mostRecentGPSLocation.timestamp))
                var maximumTimeIntervalBetweenGPSMovements = self.timeIntervalBeforeStoppedRouteDueToUsuableSpeedReadings
                if (self.isDefferringLocationUpdates) {
                    // if we are deferring, give extra time. this is because we will sometime get
                    // bad locations (ie from startMonitoringSignificantLocationChanges) during our deferral period.
                    maximumTimeIntervalBetweenGPSMovements += self.timeIntervalForLocationTrackingDeferral
                }
                if (timeIntervalSinceLastGPSMovement > maximumTimeIntervalBetweenGPSMovements) {
                    if (route.locationCount() > 10) {
                        DDLogVerbose("Went too long with unusable speeds.")
                        self.stopGPSRouteAndEnterBackgroundState()
                    } else {
                        // work around issue where a new trip may receive a state location, causing the trip to end prematurely
                        DDLogVerbose("Received stale location with unusable speeds. Awaiting new update.")
                    }
                } else {
                    DDLogVerbose("Nothing but unusable speeds. Awaiting next update")
                }
            }
        }
    }
    
    private func processLocations(_ locations:[CLLocation]) {
        if let route = self.currentRoute, self.isLocationManagerUsingGPS {
            processGPSLocations(locations, forRoute: route)
        } else if (self.dateOfStoppingLocationManagerGPS != nil && abs(self.dateOfStoppingLocationManagerGPS!.timeIntervalSinceNow) < 2) {
            // sometimes turning off GPS will continue to delvier a few locations. thus, keep track of dateOfStoppingLocationManagerGPS to avoid
            // considering these updates as significiation location changes.
            return
        } else {
            // we are not actively using GPS. we don't know what mode we are using and whether or not we should start a new currentRoute.
            var locs: [Location] = []
            for location in locations {
                let loc = Location(recordedLocation: location, isActiveGPS: false)
                locs.append(loc)
            }
            self.runPredictionAndStartRouteIfNeeded(withLocations: locs)
        }
    }
    
    private func runPredictionAndStartRouteIfNeeded(withLocations locations:[Location]) {
        let firstLocation = locations.first
        
        #if DEBUG
        for location in locations {
            DDLogVerbose(String(format: "Location found. Speed: %f, Accuracy: %f", location.speed, location.horizontalAccuracy))
        }
        #endif
        
        if let aggregator =  self.currentPredictionAggregator {
            for loc in locations {
                loc.predictionAggregator = aggregator
            }
        } else {
            let newAggregator = PredictionAggregator(locations: locations)
            self.currentPredictionAggregator = newAggregator
            
            routeRecorder.classificationManager.predictCurrentActivityType(predictionAggregator: newAggregator) {[weak self] (prediction) -> Void in
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
                    let priorRoute = strongSelf.currentRoute ?? Route.mostRecentRoute()
                    
                    if let route = priorRoute, let loc = firstLocation, strongSelf.routeQualifiesForResumption(route: route, fromActivityType: prediction.activityType, fromLocation: loc) {
                        DDLogStateChange("Resuming route")
                        
                        route.reopen()
                        strongSelf.currentRoute = route
                    } else {
                        if let route = strongSelf.currentRoute, !route.isClosed {
                            route.close()
                        }
                        DDLogStateChange("Opening new route")
                        
                        strongSelf.currentRoute = Route()
                        strongSelf.currentRoute!.open()
      
                        if prediction.activityType != .stationary {
                            strongSelf.currentRoute!.activityType = prediction.activityType
                        }
                    }
                    
                    strongSelf.currentRoute!.addPredictionAggregator(newAggregator)
                    
                    var shouldAppendToCurrentRoute = true
                    let mostRecentRoute = Route.mostRecentRoute()
                    if let mostRecentRoute = mostRecentRoute {
                        // if the mostRecentRoute's mode is not like (~=) the currentRoute's, we should appending any
                        // ~= aggregators to mostRecentRoute until we find one that ~= currentTrip
                        shouldAppendToCurrentRoute = (mostRecentRoute.activityType ~= strongSelf.currentRoute!.activityType)
                    }
                    
                    for aggregator in strongSelf.pendingAggregators {
                        if shouldAppendToCurrentRoute {
                            strongSelf.currentRoute!.addPredictionAggregator(aggregator)
                        } else {
                            if let aggregatePredictedActivity = aggregator.aggregatePredictedActivity,
                                aggregatePredictedActivity.activityType ~= mostRecentRoute!.activityType {
                                // if the mode ~= the last route, append there
                                mostRecentRoute!.addPredictionAggregator(aggregator)
                            } else if let aggregatePredictedActivity = aggregator.aggregatePredictedActivity,
                                aggregatePredictedActivity.activityType ~= strongSelf.currentRoute!.activityType {
                                // as soon as the mode switches to ~= the current route, start appending there instead
                                shouldAppendToCurrentRoute = true
                                strongSelf.currentRoute!.addPredictionAggregator(aggregator)
                            } else {
                                mostRecentRoute!.addPredictionAggregator(aggregator)
                            }
                        }
                    }
                    
                    strongSelf.pendingAggregators = []
                    
                    if let mostRecentRoute = mostRecentRoute {
                        _ = mostRecentRoute.saveLocationsAndUpdateLength(intermittently: false)
                    }
                    
                    _ = strongSelf.currentRoute!.saveLocationsAndUpdateLength(intermittently: false)
                    
                    if (strongSelf.currentRoute!.activityType == .cycling) {
                        strongSelf.startLocationTrackingUsingGPS()
                    }
                } else {
                    if prediction.activityType == .stationary && strongSelf.currentRoute == nil {
                        // don't include stationary samples in a route when starting a new route
                        // if a route is already underway, we do include them (for example if the user stops at a traffic light)
                    } else {
                        // otherwise, append to the next trip
                        strongSelf.pendingAggregators.append(newAggregator)
                    }
                }
            }
        }
    }

    
    //
    // MARK: - Helper methods
    //
    
    private func routeQualifiesForResumption(route: Route, fromActivityType activityType: ActivityType, fromLocation location: Location)->Bool {
        if (route.wasStoppedManually) {
            // dont resume manually stopped routes
            return false
        }
        
        if (route.activityType != activityType) {
            if (route.activityType.isMotorizedMode && activityType.isMotorizedMode) {
                // if both routes are motorized, allow resumption since our mode detection within motorized mode is not great
            } else if (activityType == .stationary || route.activityType == .unknown) {
                // unknown and stationary activities could be a part of any mode
            } else {
                return false
            }
        }
        
        var timeoutInterval: TimeInterval = 0
        switch route.activityType {
        case .cycling where route.length >= 20 * 1000: // longer time out above 20k
            timeoutInterval = 1080
        case .cycling:
            timeoutInterval = 300
        case .walking: // walking can be slow to trigger location changes
            timeoutInterval = 900
        default: // non-cycling trips have low accuracy locations that may be far apart
            timeoutInterval = 600
        }
        
        return abs(route.endDate.timeIntervalSince(location.date)) < timeoutInterval
    }
    
    private func beginDeferringUpdatesIfAppropriate() {
        if (CLLocationManager.deferredLocationUpdatesAvailable() && !self.isDefferringLocationUpdates) {
            DDLogVerbose("Re-deferring updates")
            self.isDefferringLocationUpdates = true
            self.routeRecorder.locationManager.allowDeferredLocationUpdates(untilTraveled: CLLocationDistanceMax, timeout: self.timeIntervalForLocationTrackingDeferral)
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
    
    public func isPausedDueToBatteryLife() -> Bool {
#if (arch(i386) || arch(x86_64)) && os(iOS)
    return false
#endif
        return UIDevice.current.batteryLevel < self.minimumBatteryForTracking
    }
    
    public func isPaused() -> Bool {
        return self.isPausedDueToBatteryLife() || self.isPausedByUser() || isPausedDueToUnauthorized()
    }
    
    public func isPausedByUser() -> Bool {
        return UserDefaults.standard.bool(forKey: "RouteManagerIsPaused")
    }
    
    public func isPausedDueToUnauthorized() -> Bool {
        return (RouteManager.authorizationStatus() != .authorizedAlways)
    }
    
    
    public func pausedUntilDate() -> Date? {
        return UserDefaults.standard.object(forKey: "RouteManagerIsPausedUntilDate") as? Date
    }
    
    public func pauseTracking(_ untilDate: Date! = nil) {
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
        
        self.stopGPSRouteAndEnterBackgroundState()
        RouteRecorderStore.store().lastArrivalLocation = nil
        RouteRecorderDatabaseManager.shared.saveContext()
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RouteManagerDidPauseOrResume"), object: nil)
    }
    
    private func pauseTrackingDueToLowBatteryLife(withLastLocation location: CLLocation?) {
        if (self.isLocationManagerUsingGPS) {
            // if we are currently updating, send the user a push and stop.
            let notif = UILocalNotification()
            notif.alertBody = "Whoa, your battery is pretty low. Ride Report will stop running until you get a charge!"
            UIApplication.shared.presentLocalNotificationNow(notif)
                        
            DDLogStateChange("Paused Tracking due to battery life")
            
            self.stopGPSRouteAndEnterBackgroundState()
        }
        
        RouteRecorderStore.store().lastArrivalLocation = nil
        RouteRecorderDatabaseManager.shared.saveContext()
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RouteManagerDidPauseOrResume"), object: nil)
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
    
    public func resumeTracking() {
        if (!isPaused()) {
            return
        }
        
        self.cancelScheduledAppResumeReminderNotifications()
        
        UserDefaults.standard.set(false, forKey: "RouteManagerIsPaused")
        UserDefaults.standard.set(nil, forKey: "RouteManagerIsPausedUntilDate")
        UserDefaults.standard.synchronize()
        
        DDLogStateChange("Resume Tracking")
        self.startTrackingMachine()
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RouteManagerDidPauseOrResume"), object: nil)
    }
    
    //
    // MARK: - CLLocationManger Delegate Methods
    //
    
    public static func authorizationStatus()-> CLAuthorizationStatus {
        return RouteRecorder.shared.locationManager.authorizationStatus()
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DDLogVerbose("Did change authorization status")
        
        if (status == CLAuthorizationStatus.authorizedAlways) {
            self.startTrackingMachine()
        } else {
            // tell the user they need to give us access to the zion mainframes
            DDLogVerbose("Not authorized for location access!")
        }
        
        if let handler = self.pendingRegistrationHandler {
            self.pendingRegistrationHandler = nil
            handler()
        }
    }
    
    public func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        // Should never happen
        DDLogWarn("Unexpectedly paused location updates!")
    }
    
    public func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        // Should never happen
        DDLogWarn("Unexpectedly resumed location updates!")
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DDLogWarn(String(format: "Got active tracking location error! %@", error as CVarArg))
        
        if (error._code == CLError.Code.denied.rawValue) {
            // alert the user and pause tracking.
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
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
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
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
                    DDLogInfo("Route Manager Location Update Background task expired!")
                    
                    UIApplication.shared.endBackgroundTask(self.locationUpdateBackgroundTaskID)
                    self.locationUpdateBackgroundTaskID = UIBackgroundTaskInvalid
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
    
    public func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        guard checkPausedAndResumeIfNeeded() else {
            return
        }
        
        if (visit.departureDate == NSDate.distantFuture) {
            DDLogInfo("User arrived")
            // the user has arrived but not yet left
            if !self.isLocationManagerUsingGPS {
                // ignore arrivals that occur during GPS usage
                
                if let route = self.currentRoute ?? Route.mostRecentRoute(), !route.isClosed {
                    DDLogStateChange("Ending route with arrival")

                    let loc = Location(visit: visit, isArriving: true)
                    loc.route = route
                    route.close()
                    
                    self.currentRoute = nil
                }
                // if we've build up any aggregators without starting a trip, clear them out
                self.pendingAggregators = []
            }
        } else {
            DDLogInfo("User departed")
            // the user has departed
            let loc = Location(visit: visit, isArriving: false)
            
            if let route = self.currentRoute {
                loc.route = route
                RouteRecorderDatabaseManager.shared.saveContext()
            } else if let priorRoute = Route.mostRecentRoute(), let priorLoc = priorRoute.mostRecentLocation(), loc.date < priorLoc.date {
                // if the departure occured prior to the end of the last route, prepend it in that route
                loc.route = priorRoute
                if priorRoute.isClosed {
                    priorRoute.reopen()
                    priorRoute.close()
                }
                RouteRecorderDatabaseManager.shared.saveContext()
            } else {
                self.runPredictionAndStartRouteIfNeeded(withLocations: [loc])
            }
        }
    }
}
