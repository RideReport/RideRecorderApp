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

public class TestClassificationManager : ClassificationManager {
    public var routeRecorder: RouteRecorder!
    public static var authorizationStatus : ClassificationManagerAuthorizationStatus = .notDetermined
    
    private var testPredictionsIndex = 0
    private var testPredictionsTemplates: [PredictedActivity]!
    
    public init () {
        
    }
    
    public func startup(handler: @escaping ()->Void = {() in }) {
        TestClassificationManager.authorizationStatus = .authorized
        
        handler()
    }

    public func gatherSensorData(predictionAggregator: PredictionAggregator) {
        //
    }
    
    public func stopGatheringSensorData() {
        //
    }
    
    public func setTestPredictionsTemplates(testPredictions: [PredictedActivity]) {
        self.testPredictionsTemplates = testPredictions
    }
    
    public func predictCurrentActivityType(predictionAggregator: PredictionAggregator, withHandler handler: @escaping (PredictionAggregator) -> Void) {
        let predictionTemplate = self.testPredictionsTemplates[testPredictionsIndex]
        let prediction = Prediction()
        let _ = PredictedActivity(activityType: predictionTemplate.activityType, confidence: predictionTemplate.confidence, prediction: prediction)
        predictionAggregator.predictions.insert(prediction)
        
        predictionAggregator.updateAggregatePredictedActivity()
        
        handler(predictionAggregator)
        
        testPredictionsIndex += 1
        if (testPredictionsIndex >= testPredictionsTemplates.count) {
            testPredictionsIndex = 0
        }
    }
}
