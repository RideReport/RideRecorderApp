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
import CocoaLumberjack

public enum ClassificationManagerAuthorizationStatus {
    case notDetermined
    case denied
    case authorized
}

public protocol ClassificationManager {
    var routeRecorder: RouteRecorder! { get set }
        
    func startup(handler: @escaping ()->Void)
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
    
    public static var authorizationStatus : ClassificationManagerAuthorizationStatus = .notDetermined
    
    private var backgroundTaskID = UIBackgroundTaskInvalid
    var cancelTimedoutPredictionBlock: DispatchWorkItem?


    private var isGatheringMotionData: Bool = false
    
    public init () {
        self.motionQueue = OperationQueue()
    }
    
    public func startup(handler: @escaping ()->Void = {() in }) {
        routeRecorder.motionManager.accelerometerUpdateInterval = 1/50 // 50hz, the native rate for CMSensorRecorder
        
        handler()
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
                UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                self.backgroundTaskID = UIBackgroundTaskInvalid
            })
        }
        
        self.isGatheringMotionData = true
        
        self.routeRecorder.motionManager.startAccelerometerUpdates(to: self.motionQueue) { (data, error) in
            guard let accelerometerData = data else {
                return
            }
            
            DispatchQueue.main.async {
                let reading = self.accelerometerReading(forAccelerometerData: accelerometerData,  predictionAggregator: predictionAggregator)
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
                UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                self.backgroundTaskID = UIBackgroundTaskInvalid
            })
            
            // schedule an early bailer if we're not done yet
            let maximumTimeNeeded = Double(PredictionAggregator.maximumSampleBeforeFailure - 1) * PredictionAggregator.sampleOffsetTimeInterval + Double(PredictionAggregator.maximumSampleBeforeFailure) * self.routeRecorder.randomForestManager.desiredSessionDuration
            let timeoutPredictionInterval = maximumTimeNeeded + 2 // plus a generous buffer
            
            let timeoutPredictionBlock = DispatchWorkItem {
                self.cancelTimedoutPredictionBlock = nil
                predictionAggregator.currentPrediction = nil
                
                DDLogInfo("Prediction attempt expired, canceling!")
                predictionAggregator.addUnknownTypePrediction()
                handler(predictionAggregator)
                self.stopMotionUpdates()
            }
            cancelTimedoutPredictionBlock = timeoutPredictionBlock
            DispatchQueue.main.asyncAfter(deadline: .now() + timeoutPredictionInterval, execute: timeoutPredictionBlock)
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
        
        beginMotionUpdates(predictionAggregator: predictionAggregator, withHandler: handler)
    }
    
    //
    // MARK: Helper Functions
    //
    
    private func accelerometerReading(forAccelerometerData accelerometerData:CMAccelerometerData, predictionAggregator: PredictionAggregator)->AccelerometerReading {
        let accelerometerReading = AccelerometerReading(accelerometerData: accelerometerData)
        if predictionAggregator.referenceBootDate == nil {
            predictionAggregator.referenceBootDate = Date(timeIntervalSinceNow: -1 * accelerometerData.timestamp)
        }
        
        accelerometerReading.date =  Date(timeInterval: accelerometerData.timestamp, since: predictionAggregator.referenceBootDate)
        return accelerometerReading
    }
    
    private func stopMotionUpdates() {
        if (isGatheringMotionData) {
            return
        }
        
        self.routeRecorder.motionManager.stopAccelerometerUpdates()
        
        if let timedoutPredictionBlock = self.cancelTimedoutPredictionBlock {
            timedoutPredictionBlock.cancel()
            self.cancelTimedoutPredictionBlock = nil
        }
        
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
                
                return true // caller will call stopMotionUpdates after it has a chance to call the handler
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
                
                predictionAggregator.addUnknownTypePrediction()
                handler(predictionAggregator)
                self.stopMotionUpdates()
                
                return
            }
            
            guard let accelerometerData = motion else {
                return
            }
            
            DispatchQueue.main.async {
                let reading = self.accelerometerReading(forAccelerometerData: accelerometerData, predictionAggregator: predictionAggregator)
                reading.predictionAggregator = predictionAggregator
                
                RouteRecorderDatabaseManager.shared.saveContext()
                
                if self.runPredictionsAndFinishIfPossible(predictionAggregator: predictionAggregator) {
                    handler(predictionAggregator)
                    self.stopMotionUpdates()
                }
            }
        }
    }
}
