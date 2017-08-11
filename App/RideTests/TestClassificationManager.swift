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
    
    func gatherSensorData(toTrip trip:Trip) {
        //
    }
    
    func stopGatheringSensorData() {
        //
    }
    
    func setTestPredictionsTemplates(testPredictions: [PredictedActivity]) {
        self.testPredictionsTemplates = testPredictions
    }
    
    func predictCurrentActivityType(prediction:Prediction, withHandler handler:@escaping (_: Prediction) -> Void) {
        let predictionTemplate = self.testPredictionsTemplates[testPredictionsIndex]
        let _ = PredictedActivity(activityType: predictionTemplate.activityType, confidence: predictionTemplate.confidence, prediction: prediction)
        
        DispatchQueue.main.async {
            handler(prediction)
        }
        
        testPredictionsIndex += 1
        if (testPredictionsIndex >= testPredictionsTemplates.count) {
            testPredictionsIndex = 0
        }
    }
}
