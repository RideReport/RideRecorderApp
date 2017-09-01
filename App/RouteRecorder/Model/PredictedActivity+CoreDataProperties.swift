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
    @NSManaged public var activityTypeInteger: Int16
    @NSManaged public var confidence: Float
    @NSManaged public var prediction: Prediction?
    @NSManaged public var predictionAggregator: PredictionAggregator?
}
