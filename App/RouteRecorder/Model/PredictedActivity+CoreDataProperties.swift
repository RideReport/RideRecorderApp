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
    @NSManaged public internal(set) var activityTypeInteger: Int16
    @NSManaged public internal(set) var confidence: Float
    @NSManaged public internal(set) var prediction: Prediction?
    @NSManaged public internal(set) var predictionAggregator: PredictionAggregator?
}
