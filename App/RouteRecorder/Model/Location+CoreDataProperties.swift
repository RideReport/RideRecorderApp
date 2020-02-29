//
//  Location+CoreDataProperties.swift
//  Ride
//
//  Created by William Henderson on 8/3/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import CoreData


extension Location {
    @NSManaged public internal(set) var altitude: Double
    @NSManaged public internal(set) var course: Double
    @NSManaged public internal(set) var date: Date
    @NSManaged public internal(set) var horizontalAccuracy: Double
    @NSManaged public internal(set) var latitude: Double
    @NSManaged public internal(set) var longitude: Double
    @NSManaged public internal(set) var sourceInteger: Int16
    @NSManaged public internal(set) var speed: Double
    @NSManaged public internal(set) var verticalAccuracy: Double
    @NSManaged public internal(set) var simplifiedInRoute: Route?
    @NSManaged public internal(set) var route: Route?
    @NSManaged public internal(set) var predictionAggregator: PredictionAggregator?
    @NSManaged public internal(set) var lastArrivalLocationOfRouteRecorderStore: RouteRecorderStore?
}
