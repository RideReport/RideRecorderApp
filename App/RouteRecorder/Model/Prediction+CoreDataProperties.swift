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
    @NSManaged public internal(set) var startDate: Date
    @NSManaged public internal(set) var activityPredictionModelIdentifier: String?
    @NSManaged public internal(set) var predictedActivities: Set<PredictedActivity>
    @NSManaged public internal(set) var predictionAggregator: PredictionAggregator?
}
