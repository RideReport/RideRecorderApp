//
//  ActivityTypePrediction.swift
//  Ride Report
//
//  Created by William Henderson on 1/7/15.
//  Copyright (c) 2015 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

class ActivityTypePrediction : NSManagedObject {
    @NSManaged var confidence : NSNumber
    @NSManaged var activityType : ActivityType
    @NSManaged var sensorDataCollection : SensorDataCollection?
    
    convenience init(activityType: ActivityType, confidence: Float, sensorDataCollection: SensorDataCollection?) {
        let context = CoreDataManager.shared.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entity(forEntityName: "ActivityTypePrediction", in: context)!, insertInto: context)
        
        self.activityType = activityType
        self.confidence = NSNumber(value: confidence as Float)
        self.sensorDataCollection = sensorDataCollection
    }
    
    func jsonDictionary() -> [String: Any] {
        return [
            "confidence": self.confidence,
            "activityType": self.activityType.numberValue
        ]
    }
    
    override var debugDescription: String {
        return activityType.emoji + ": " + confidence.stringValue
    }
}
