//
//  Prediction+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension Prediction {
    @NSManaged public var startDate: Date
    @NSManaged public var activityPredictionModelIdentifier: String?
    @NSManaged public var predictedActivities: Set<PredictedActivity>
    @NSManaged public var predictionAggregator: PredictionAggregator?
}
