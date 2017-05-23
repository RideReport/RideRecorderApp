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
    func queryCurrentActivityType(forSensorDataCollection sensorDataCollection:SensorDataCollection, withHandler handler:@escaping (_: SensorDataCollection) -> Void!)
    func setTestPredictionsTemplates(testPredictions: [ActivityTypePrediction])
}

extension ClassificationManager {
    func setTestPredictionsTemplates(testPredictions: [ActivityTypePrediction]) {
        
    }
}

class SensorClassificationManager : ClassificationManager {
    var sensorComponent: SensorManagerComponent!
    
    private var motionQueue: OperationQueue!

    let motionStartTimeoutInterval: TimeInterval = 30
    let motionContinueTimeoutInterval: TimeInterval = 60
    private var backgroundTaskID = UIBackgroundTaskInvalid

    private var isGatheringMotionData: Bool = false
    var authorizationStatus : ClassificationManagerAuthorizationStatus = .notDetermined
    
    init () {
        self.motionQueue = OperationQueue()
    }
    
    func startup() {
        sensorComponent.motionManager.accelerometerUpdateInterval = sensorComponent.randomForestManager.desiredSampleInterval/2.0
        
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
    
    func gatherSensorData(toSensorDataCollection sensorDataCollection:SensorDataCollection) {
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
                sensorDataCollection.addAccelerometerData(accelerometerData)
            }
        }
    }
    
    private func stopMotionUpdates() {
        self.sensorComponent.motionManager.stopAccelerometerUpdates()
        
        if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
            DDLogInfo("Ending background task with Stop Motion Updates!")
            
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        }
    }
    
    func queryCurrentActivityType(forSensorDataCollection sensorDataCollection:SensorDataCollection, withHandler handler:@escaping (_: SensorDataCollection) -> Void!) {
        if (!self.sensorComponent.randomForestManager.canPredict) {
            DDLogInfo("Random forest was not ready!")
            sensorDataCollection.addUnknownTypePrediction()
            handler(sensorDataCollection)
            return
        }
        
        if (self.backgroundTaskID == UIBackgroundTaskInvalid) {
            DDLogInfo("Beginning Query Activity Type background task!")
            self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                DDLogInfo("Query Activity Type Background task expired!")
    	        sensorDataCollection.addUnknownTypePrediction()
	            handler(sensorDataCollection)
                self.backgroundTaskID = UIBackgroundTaskInvalid
            })
        } else {
            DDLogInfo("Could not query activity type, background task already in process!")
            sensorDataCollection.addUnknownTypePrediction()
            handler(sensorDataCollection)
            return
        }

        sensorDataCollection.isBeingCollected = true
        
        let completionBlock = {
            guard sensorDataCollection.isBeingCollected else {
                // avoid possible race condition where completion block could be called after we have already finished
                return
            }
            
            guard let firstReadingDate = (sensorDataCollection.accelerometerAccelerations.firstObject as? SensorData)?.date, let lastReadingDate = (sensorDataCollection.accelerometerAccelerations.lastObject as? SensorData)?.date else {
                return
            }
            
            if lastReadingDate.timeIntervalSince(firstReadingDate as Date) >= self.sensorComponent.randomForestManager.desiredSessionDuration {
                sensorDataCollection.isBeingCollected = false
                self.stopMotionUpdates()
                
                self.sensorComponent.randomForestManager.classify(sensorDataCollection)
                handler(sensorDataCollection)
            }
        }
            
        self.sensorComponent.motionManager.startAccelerometerUpdates(to: self.motionQueue) { (motion, error) in
            guard error == nil else {
                DDLogInfo("Error reading accelerometer data! Ending early…")
                sensorDataCollection.isBeingCollected = false
                self.stopMotionUpdates()
                
                sensorDataCollection.addUnknownTypePrediction()
                handler(sensorDataCollection)

                return
            }
            
            guard let accelerometerAcceleration = motion else {
                return
            }
            
            DispatchQueue.main.async {
                sensorDataCollection.addAccelerometerData(accelerometerAcceleration)
                completionBlock()
            }
        }
    }
}
