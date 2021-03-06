//
//  ActivityTypePrediction.swift
//  Ride Report
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

public class PredictedActivity: NSManagedObject {
    public internal(set) var activityType : ActivityType {
        get {
            return ActivityType(rawValue: self.activityTypeInteger) ?? ActivityType.unknown
        }
        set {
            self.activityTypeInteger = newValue.rawValue
        }
    }
    
    public convenience init() {
        let context = RouteRecorderDatabaseManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "PredictedActivity", in: context)!, insertInto: context)
    }

    public convenience init(activityType: ActivityType, confidence: Float, prediction: Prediction?) {
        self.init()
        
        self.activityType = activityType
        self.confidence = confidence
        self.prediction = prediction
    }
    
    public func jsonDictionary() -> [String: Any] {
        return [
            "confidence": self.confidence,
            "activityType": self.activityType.numberValue
        ]
    }
    
    override public var debugDescription: String {
        return String(format: "%@: %.2f", activityType.emoji, confidence)
    }
}
