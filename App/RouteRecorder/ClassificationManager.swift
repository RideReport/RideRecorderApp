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

public enum ClassificationManagerAuthorizationStatus {
    case notDetermined
    case denied
    case authorized
}

public protocol ClassificationManager {
    var routeRecorder: RouteRecorder! { get set }
    var authorizationStatus : ClassificationManagerAuthorizationStatus { get }
    
    func startup()
    func predictCurrentActivityType(predictionAggregator:PredictionAggregator, withHandler handler:@escaping (_: PredictionAggregator) -> Void)
    func setTestPredictionsTemplates(testPredictions: [PredictedActivity])
    
    func gatherSensorData(predictionAggregator: PredictionAggregator)
    func stopGatheringSensorData()
}

extension ClassificationManager {
    public func setTestPredictionsTemplates(testPredictions: [PredictedActivity]) {
        
    }
}

public class SensorClassificationManager : ClassificationManager {
    public var routeRecorder: RouteRecorder!
    
    private var motionQueue: OperationQueue!
    private var referenceBootDate: Date!
    
    let motionStartTimeoutInterval: TimeInterval = 30
    let motionContinueTimeoutInterval: TimeInterval = 60
    private var backgroundTaskID = UIBackgroundTaskInvalid

    private var isGatheringMotionData: Bool = false
    public var authorizationStatus : ClassificationManagerAuthorizationStatus = .notDetermined
    
    public init () {
        self.motionQueue = OperationQueue()
    }
    
    public func startup() {
        routeRecorder.motionManager.accelerometerUpdateInterval = 1/50 // 50hz, the native rate for CMSensorRecorder
        
        let hasBeenGrantedMotionAccess = UserDefaults.standard.bool(forKey: "MotionManagerHasRequestedMotionAccess")
        if (!hasBeenGrantedMotionAccess) {
            // run a query so we can have the permission dialog come up when we want it to
            DispatchQueue.main.async(execute: { () -> Void in
                self.routeRecorder.motionActivityManager.queryActivityStarting(from: Date(timeIntervalSinceNow: -10), to: Date(), to: self.motionQueue) { (actibity, error) -> Void in
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
    
    public func stopGatheringSensorData() {
        self.isGatheringMotionData = false
        self.stopMotionUpdates()
        
        if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
            DDLogInfo("Ending GatherSensorData background task!")
            
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        }
    }
    
    public func gatherSensorData(predictionAggregator: PredictionAggregator) {
        if (self.backgroundTaskID == UIBackgroundTaskInvalid) {
            DDLogInfo("Beginning GatherSensorData background task!")
            self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                DDLogInfo("GatherSensorData Background task expired!")
                self.backgroundTaskID = UIBackgroundTaskInvalid
            })
        }
        
        self.isGatheringMotionData = true
        
        self.routeRecorder.motionManager.startAccelerometerUpdates(to: self.motionQueue) { (data, error) in
            guard let accelerometerData = data else {
                return
            }
            
            DispatchQueue.main.async {
                let reading = self.accelerometerReading(forAccelerometerData: accelerometerData)
                reading.predictionAggregator = predictionAggregator
            }
        }
    }

    public func predictCurrentActivityType(predictionAggregator: PredictionAggregator, withHandler handler:@escaping (_: PredictionAggregator) -> Void) {
        if (!self.routeRecorder.randomForestManager.canPredict) {
            DDLogInfo("Random forest was not ready!")
            predictionAggregator.addUnknownTypePrediction()
            handler(predictionAggregator)
            return
        }
        
        if (self.backgroundTaskID == UIBackgroundTaskInvalid) {
            DDLogInfo("Beginning Query Activity Type background task!")
            self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { () -> Void in
                DDLogInfo("Query Activity Type Background task expired!")
                predictionAggregator.addUnknownTypePrediction()
                handler(predictionAggregator)
                self.backgroundTaskID = UIBackgroundTaskInvalid
            })
        } else {
            DDLogInfo("Could not query activity type, background task already in process!")
            predictionAggregator.addUnknownTypePrediction()
            handler(predictionAggregator)
            return
        }

        let prediction = Prediction()
        prediction.predictionAggregator = predictionAggregator
        
        predictionAggregator.currentPrediction = prediction
        RouteRecorderDatabaseManager.shared.saveContext()
        
        var recordedSensorDataIsAvailable = false
        if #available(iOS 9.0, *) {
            if CMSensorRecorder.isAccelerometerRecordingAvailable() {
                // go back N minutes and do predictions
                // recordedSensorDataIsAvailable = true
            }
        }
        
        if !recordedSensorDataIsAvailable {
            beginMotionUpdates(predictionAggregator: predictionAggregator, withHandler: handler)
        }
    }
    
    //
    // MARK: Helper Functions
    //
    
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
        
        self.routeRecorder.motionManager.stopAccelerometerUpdates()
        
        if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
            DDLogInfo("Ending background task with Stop Motion Updates!")
            
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        }
    }
    
    
    
    private func runPredictionsAndFinishIfPossible(predictionAggregator: PredictionAggregator)->Bool {
        guard let prediction = predictionAggregator.currentPrediction else {
            return false
        }
        
        guard let firstReadingDate = predictionAggregator.fetchFirstReading(afterDate: prediction.startDate)?.date, let lastReadingDate = predictionAggregator.fetchLastReading()?.date else {
            return false
        }
        
        if lastReadingDate.timeIntervalSince(firstReadingDate as Date) >= self.routeRecorder.randomForestManager.desiredSessionDuration {
            self.routeRecorder.randomForestManager.classify(prediction)
            predictionAggregator.updateAggregatePredictedActivity()
            
            if predictionAggregator.aggregatePredictionIsComplete() {
                predictionAggregator.currentPrediction = nil
                self.stopMotionUpdates()
                
                return true
            } else {
                // start a new prediction and keep going
                let newPrediction = Prediction()
                newPrediction.startDate = prediction.startDate.addingTimeInterval(PredictionAggregator.sampleOffsetTimeInterval)
                newPrediction.predictionAggregator = predictionAggregator
                
                predictionAggregator.currentPrediction = newPrediction
                RouteRecorderDatabaseManager.shared.saveContext()
            }
        }
        
        return false
    }
    
    
    private func beginMotionUpdates(predictionAggregator: PredictionAggregator, withHandler handler:@escaping (_: PredictionAggregator) -> Void) {
        self.routeRecorder.motionManager.startAccelerometerUpdates(to: self.motionQueue) { (motion, error) in
            guard error == nil else {
                DDLogInfo("Error reading accelerometer data! Ending early…")
                predictionAggregator.currentPrediction = nil
                self.stopMotionUpdates()
                
                predictionAggregator.addUnknownTypePrediction()
                handler(predictionAggregator)
                
                return
            }
            
            guard let accelerometerData = motion else {
                return
            }
            
            DispatchQueue.main.async {
                let reading = self.accelerometerReading(forAccelerometerData: accelerometerData)
                reading.predictionAggregator = predictionAggregator
                
                RouteRecorderDatabaseManager.shared.saveContext()
                
                if self.runPredictionsAndFinishIfPossible(predictionAggregator: predictionAggregator) {
                    handler(predictionAggregator)
                }
            }
        }
    }
}
