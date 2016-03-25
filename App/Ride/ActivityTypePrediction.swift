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
    
    convenience init(activityType: ActivityType, confidence: Float, sensorDataCollection: SensorDataCollection) {
        let context = CoreDataManager.sharedManager.currentManagedObjectContext()
        self.init(entity: NSEntityDescription.entityForName("ActivityTypePrediction", inManagedObjectContext: context)!, insertIntoManagedObjectContext: context)
        
        self.activityType = activityType
        self.confidence = NSNumber(float: confidence)
        self.sensorDataCollection = sensorDataCollection
    }
}