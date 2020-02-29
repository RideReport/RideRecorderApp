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
    @NSManaged public internal(set) var aggregatePredictedActivity: PredictedActivity?
    @NSManaged public internal(set) var predictions: Set<Prediction>
    @NSManaged public internal(set) var locations: Set<Location>
    @NSManaged public internal(set) var accelerometerReadings: Set<AccelerometerReading>
    @NSManaged public internal(set) var route: Route?
}
