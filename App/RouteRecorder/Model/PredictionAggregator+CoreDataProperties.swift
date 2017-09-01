//
//  PredictionAggregator+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/14/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData
import MapKit

extension PredictionAggregator {
    @NSManaged public var aggregatePredictedActivity: PredictedActivity?
    @NSManaged public var predictions: Set<Prediction>
    @NSManaged public var accelerometerReadings: Set<AccelerometerReading>
    @NSManaged public var route: Route?
}
