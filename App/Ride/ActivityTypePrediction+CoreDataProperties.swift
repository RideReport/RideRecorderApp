//
//  ActivityTypePrediction+CoreDataProperties.swift
//  
//
//  Created by William Henderson on 8/3/17.
//
//

import Foundation
import CoreData


extension ActivityTypePrediction {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ActivityTypePrediction> {
        return NSFetchRequest<ActivityTypePrediction>(entityName: "PredictedActivity")
    }

    @NSManaged public var activityType: NSNumber?
    @NSManaged public var confidence: NSNumber?
    @NSManaged public var prediction: Prediction?

}
