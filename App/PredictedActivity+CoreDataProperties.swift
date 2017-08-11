//
//  PredictedActivity+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension PredictedActivity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PredictedActivity> {
        return NSFetchRequest<PredictedActivity>(entityName: "PredictedActivity")
    }

    @NSManaged public var activityTypeInteger: Int16
    @NSManaged public var confidence: Float
    @NSManaged public var prediction: Prediction?

}
