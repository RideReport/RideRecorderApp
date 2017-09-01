//
//  RandomForest.swift
//  Ride
//
//  Created by William Henderson on 3/7/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

import Foundation

public class RandomForestManager {
    private var modelIdentifier: String?
    
    var _ptr: OpaquePointer!
    var classLables: [Int32]!
    var classCount = 0
    public var desiredSampleInterval: TimeInterval {
        get {
            return Double(randomForestGetDesiredSamplingInterval(_ptr))
        }
    }
    
    public var desiredSessionDuration: TimeInterval {
        get {
            return Double(randomForestGetDesiredSessionDuration(_ptr))
        }
    }
    
    public var canPredict: Bool {
        return randomForestManagerCanPredict(_ptr)
    }
    
    public init () {
        guard let configFilePath = Bundle(for: type(of: self)).path(forResource: "ios/config.json", ofType: nil) else {
            return
        }
        
        let cConfigFilepath = configFilePath.cString(using: String.Encoding.utf8)
        
        _ptr = createRandomForestManagerFromFile(UnsafeMutablePointer(mutating: cConfigFilepath!))
    }
    
    deinit {
        deleteRandomForestManager(_ptr)
    }
    
    public func startup() {
        guard let modelUIDCString = randomForestGetModelUniqueIdentifier(_ptr) else {
            return
        }

        modelIdentifier = String(cString: modelUIDCString)
        guard let modelID = modelIdentifier else {
            return
        }
        
        guard modelID.characters.count > 0  else {
            return
        }
        
        guard let modelPath = Bundle(for: type(of: self)).path(forResource: String(format: "ios/%@.cv", modelID), ofType: nil) else {
            return
        }
        
        let cModelpath = modelPath.cString(using: String.Encoding.utf8)
        randomForestLoadModel(_ptr, UnsafeMutablePointer(mutating: cModelpath!))
        
        self.classCount = Int(randomForestGetClassCount(_ptr))
        self.classLables = [Int32](repeating: 0, count: self.classCount)
        randomForestGetClassLabels(_ptr, UnsafeMutablePointer(mutating: self.classLables), Int32(self.classCount))
    }

    private func accelerometerReadings(forAccelerometerReadings accelerometerReadings: [AccelerometerReading])->[AccelerometerReadingStruct] {
        var readings: [AccelerometerReadingStruct] = []
        
        for reading in accelerometerReadings {
            let reading = AccelerometerReadingStruct(x: Float(reading.x), y: Float(reading.y), z: Float(reading.z), t: reading.date.timeIntervalSinceReferenceDate)
            readings.append(reading)
        }
        
        return readings
    }
    
    public func classify(_ prediction: Prediction)
    {
        let accelVector = self.accelerometerReadings(forAccelerometerReadings: prediction.fetchAccelerometerReadings(timeInterval: self.desiredSessionDuration))
        let confidences = [Float](repeating: 0.0, count: self.classCount)
        
        randomForestClassifyAccelerometerSignal(_ptr, UnsafeMutablePointer(mutating: accelVector), Int32(accelVector.count), UnsafeMutablePointer(mutating: confidences), Int32(self.classCount))
        
        var classConfidences: [Int: Float] = [:]
    
        for (i, score) in confidences.enumerated() {
            classConfidences[Int(classLables[i])] = score
        }

        prediction.activityPredictionModelIdentifier = modelIdentifier
        prediction.setPredictedActivities(forClassConfidences: classConfidences)
        RouteRecorderDatabaseManager.shared.saveContext()
    }
}
