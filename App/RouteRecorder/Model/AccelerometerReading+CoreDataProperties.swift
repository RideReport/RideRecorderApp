//
//  AccelerometerReading+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData

extension AccelerometerReading {
    @NSManaged public internal(set) var date: Date
    @NSManaged public internal(set) var x: Double
    @NSManaged public internal(set) var y: Double
    @NSManaged public internal(set) var z: Double
    @NSManaged public internal(set) var predictionAggregator: PredictionAggregator
}
