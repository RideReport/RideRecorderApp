//
//  MotionManager.swift
//  Ride Report
//
//  Created by William Henderson on 10/27/14.
//  Copyright (c) 2014 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreLocation
import CoreMotion

enum ClassificationManagerAuthorizationStatus {
    case notDetermined
    case denied
    case authorized
}

protocol ClassificationManager {
    var sensorComponent: SensorManagerComponent! { get set }
    var authorizationStatus : ClassificationManagerAuthorizationStatus { get }
    
    func startup()
    func predictCurrentActivityType(prediction:Prediction, withHandler handler:@escaping (_: Prediction) -> Void)
    func setTestPredictionsTemplates(testPredictions: [PredictedActivity])
    
    func gatherSensorData(toTrip trip:Trip)
    func stopGatheringSensorData()
}

extension ClassificationManager {
    func setTestPredictionsTemplates(testPredictions: [PredictedActivity]) {
        
    }
}

class SensorClassificationManager : ClassificationManager {
    var sensorComponent: SensorManagerComponent!
    
    private var motionQueue: OperationQueue!
    private var referenceBootDate: Date!
    
    let motionStartTimeoutInterval: TimeInterval = 30
    let motionContinueTimeoutInterval: TimeInterval = 60
    private var backgroundTaskID = UIBackgroundTaskInvalid

    private var isGatheringMotionData: Bool = false
    var authorizationStatus : ClassificationManagerAuthorizationStatus = .notDetermined
    
    init () {
        self.motionQueue = OperationQueue()
    }
    
    func startup() {
        sensorComponent.motionManager.accelerometerUpdateInterval = 1/50 // 50hz, the native rate for CMSensorRecorder
        
        let hasBeenGrantedMotionAccess = UserDefaults.standard.bool(forKey: "MotionManagerHasRequestedMotionAccess")
        if (!hasBeenGrantedMotionAccess) {
            // run a query so we can have the permission dialog come up when we want it to
            DispatchQueue.main.async(execute: { () -> Void in
                self.sensorComponent.motionActivityManager.queryActivityStarting(from: Date(timeIntervalSinceNow: -10), to: Date(), to: self.motionQueue) { (actibity, error) -> Void in
                    if let err = error, err._code == Int(CMErrorMotionActivityNotAuthorized.rawValue) {
                        self.authorizationStatus = .denied
                        NotificationCenter.default.post(name: Notification.Name(rawValue: "appDidChangeManagerAuthorizationStatus"), object: self)
                    } else {
                        self.authorizationStatus = .authorized
                        NotificationCenter.default.post(name: Notification.Name(rawValue: "appDidChangeManagerAuthorizationStatus"), object: self)
                        
                        UserDefaults.standard.set(true, forKey: "MotionManagerHasRequestedMotionAccess")
                        UserDefaults.standard.synchronize()
                    }
                }
            })
        } else {
            self.authorizationStatus = .authorized
            NotificationCenter.default.post(name: Notification.Name(rawValue: "appDidChangeManagerAuthorizationStatus"), object: self)            
        }
    }
    
    func stopGatheringSensorData() {
        self.isGatheringMotionData = false
        self.stopMotionUpdates()
        
        if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
            DDLogInfo("Ending GatherSensorData background task!")
            
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        }
    }
    
    func gatherSensorData(toTrip trip:Trip) {
        if (self.backgroundTaskID == UIBackgroundTaskInvalid) {
            DDLogInfo("Beginning GatherSensorData background task!")
            self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                DDLogInfo("GatherSensorData Background task expired!")
                self.backgroundTaskID = UIBackgroundTaskInvalid
            })
        }
        
        self.isGatheringMotionData = true
        
        self.sensorComponent.motionManager.startAccelerometerUpdates(to: self.motionQueue) { (data, error) in
            guard let accelerometerData = data else {
                return
            }
            
            DispatchQueue.main.async {
                trip.accelerometerReadings.insert(self.accelerometerReading(forAccelerometerData: accelerometerData))
            }
        }
    }
    
    private func accelerometerReading(forAccelerometerData accelerometerData:CMAccelerometerData)->AccelerometerReading {
        let accelerometerReading = AccelerometerReading(accelerometerData: accelerometerData)
        if self.referenceBootDate == nil {
            self.referenceBootDate = Date(timeIntervalSinceNow: -1 * accelerometerData.timestamp)
        }
        
        accelerometerReading.date =  Date(timeInterval: accelerometerData.timestamp, since: self.referenceBootDate)
        return accelerometerReading
    }
    
    private func stopMotionUpdates() {
        if (isGatheringMotionData) {
            return
        }
        
        self.sensorComponent.motionManager.stopAccelerometerUpdates()
        
        if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
            DDLogInfo("Ending background task with Stop Motion Updates!")
            
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        }
    }
    
    func predictCurrentActivityType(prediction:Prediction, withHandler handler:@escaping (_: Prediction) -> Void) {
        if (!self.sensorComponent.randomForestManager.canPredict) {
            DDLogInfo("Random forest was not ready!")
            prediction.addUnknownTypePrediction()
            handler(prediction)
            return
        }
        
        if (self.backgroundTaskID == UIBackgroundTaskInvalid) {
            DDLogInfo("Beginning Query Activity Type background task!")
            self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                DDLogInfo("Query Activity Type Background task expired!")
                prediction.addUnknownTypePrediction()
                handler(prediction)
                self.backgroundTaskID = UIBackgroundTaskInvalid
            })
        } else {
            DDLogInfo("Could not query activity type, background task already in process!")
            prediction.addUnknownTypePrediction()
            handler(prediction)
            return
        }

        prediction.isInProgress = true
        
        let completionBlock = {
            guard prediction.isInProgress else {
                // avoid possible race condition where completion block could be called after we have already finished
                return
            }
            
            guard let firstReadingDate = prediction.fetchFirstReading()?.date, let lastReadingDate = prediction.fetchLastReading()?.date else {
                return
            }
            
            if lastReadingDate.timeIntervalSince(firstReadingDate as Date) >= self.sensorComponent.randomForestManager.desiredSessionDuration {
                prediction.isInProgress = false
                self.stopMotionUpdates()
                CoreDataManager.shared.saveContext()
                
                self.sensorComponent.randomForestManager.classify(prediction)
                handler(prediction)
            }
        }
            
        self.sensorComponent.motionManager.startAccelerometerUpdates(to: self.motionQueue) { (motion, error) in
            guard error == nil else {
                DDLogInfo("Error reading accelerometer data! Ending early…")
                prediction.isInProgress = false
                self.stopMotionUpdates()
                
                prediction.addUnknownTypePrediction()
                handler(prediction)

                return
            }
            
            guard let accelerometerData = motion else {
                return
            }
            
            DispatchQueue.main.async {
                let reading = self.accelerometerReading(forAccelerometerData: accelerometerData)
                if let trip = prediction.trip {
                    trip.accelerometerReadings.insert(reading)
                }
                prediction.accelerometerReadings.insert(reading)
                CoreDataManager.shared.saveContext()
                
                completionBlock()
            }
        }
    }
}
