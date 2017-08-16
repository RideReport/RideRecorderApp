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

class TestClassificationManager : ClassificationManager {
    var sensorComponent: SensorManagerComponent!
    var authorizationStatus : ClassificationManagerAuthorizationStatus = .notDetermined
    
    private var testPredictionsIndex = 0
    private var testPredictionsTemplates: [PredictedActivity]!
    
    func startup() {
        authorizationStatus = .authorized
    }
    
    func gatherSensorData(predictionAggregator: PredictionAggregator) {
        //
    }
    
    func stopGatheringSensorData() {
        //
    }
    
    func setTestPredictionsTemplates(testPredictions: [PredictedActivity]) {
        self.testPredictionsTemplates = testPredictions
    }
    
    func predictCurrentActivityType(predictionAggregator: PredictionAggregator, withHandler handler: @escaping (PredictionAggregator) -> Void) {
        let predictionTemplate = self.testPredictionsTemplates[testPredictionsIndex]
        let prediction = Prediction()
        let _ = PredictedActivity(activityType: predictionTemplate.activityType, confidence: predictionTemplate.confidence, prediction: prediction)
        predictionAggregator.predictions.insert(prediction)
        
        predictionAggregator.updateAggregatePredictedActivity()
        
        DispatchQueue.main.async {
            handler(predictionAggregator)
        }
        
        testPredictionsIndex += 1
        if (testPredictionsIndex >= testPredictionsTemplates.count) {
            testPredictionsIndex = 0
        }
    }
}
