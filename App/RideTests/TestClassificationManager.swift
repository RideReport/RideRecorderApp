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
    private var testPredictionsTemplates: [ActivityTypePrediction]!
    
    func startup() {
        authorizationStatus = .authorized
    }
    
    func setTestPredictionsTemplates(testPredictions: [ActivityTypePrediction]) {
        self.testPredictionsTemplates = testPredictions
    }
    
    func queryCurrentActivityType(forSensorDataCollection sensorDataCollection:SensorDataCollection, withHandler handler:@escaping (_: SensorDataCollection) -> Void!) {
        
        let predictionTemplate = self.testPredictionsTemplates[testPredictionsIndex]
        let _ = ActivityTypePrediction(activityType: predictionTemplate.activityType, confidence: predictionTemplate.confidence.floatValue, sensorDataCollection: sensorDataCollection)
        
        DispatchQueue.main.async {
            handler(sensorDataCollection)
        }
        
        testPredictionsIndex += 1
        if (testPredictionsIndex >= testPredictionsTemplates.count) {
            testPredictionsIndex = 0
        }
    }
}
