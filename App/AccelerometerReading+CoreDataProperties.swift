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
    @NSManaged public var date: Date
    @NSManaged public var x: Double
    @NSManaged public var y: Double
    @NSManaged public var z: Double
    @NSManaged public var includedPredictions: Set<Prediction>?
    @NSManaged public var trip: Trip?

}
